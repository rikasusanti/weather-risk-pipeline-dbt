WEATHER_ANALYTICS_DB.PUBLIC.TASK_WEATHER_SUMMARY-- =====================================================================
-- 1. SETUP LINGKUNGAN & DATABASE TARGET
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- Pastikan database dan skema target sudah ada dan aktif
CREATE DATABASE IF NOT EXISTS WEATHER_ANALYTICS_DB;
USE DATABASE WEATHER_ANALYTICS_DB;
USE SCHEMA PUBLIC;

-- Berikan izin eksekusi task ke role
GRANT EXECUTE TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;
GRANT ALL ON SCHEMA WEATHER_ANALYTICS_DB.PUBLIC TO ROLE ACCOUNTADMIN;

-- =====================================================================
-- 2. PEMBUATAN TASK GRAPH (DAG)
-- =====================================================================

-- 2.1 ROOT TASK (Task Induk Penjadwal)
CREATE OR REPLACE TASK TASK_WEATHER_ROOT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 20 19 * * * Asia/Jakarta'
AS
    SELECT 'Pipeline Execution Started' AS status;

-- 2.2 CHILD TASKS TAHAP 1 (Staging & Pre-processing Paralel)
CREATE OR REPLACE TASK TASK_PROCESS_HISTORY
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_WEATHER_ROOT
AS
    CREATE OR REPLACE VIEW STG_WEATHER_HISTORY AS
    SELECT
        city_name,
        country_code,
        latitude_deg,
        longitude_deg,
        date_valid_std::DATE AS weather_date,
        doy_std AS day_of_year,
        ROUND((avg_temperature_air_2m_f - 32) * 5/9, 2) AS avg_temp_c,
        ROUND((max_temperature_air_2m_f - 32) * 5/9, 2) AS max_temp_c,
        ROUND((min_temperature_air_2m_f - 32) * 5/9, 2) AS min_temp_c,
        tot_precipitation_in,
        __avg_wind_speed_10m_mph AS avg_wind_speed_mph
    FROM WEATHER_SOURCE_RAW.PWS_BI_SAMPLE.POINT_HISTORY_DAY
    WHERE city_name IS NOT NULL;

CREATE OR REPLACE TASK TASK_PROCESS_CLIMATOLOGY
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_WEATHER_ROOT
AS
    CREATE OR REPLACE VIEW STG_WEATHER_CLIMATOLOGY AS
    SELECT
        city_name,
        country_code,
        doy_std AS day_of_year,
        ROUND((avg_of__daily_avg_temperature_air_2m_f - 32) * 5/9, 2) AS climate_normal_avg_temp_c,
        avg_of__pos_daily_tot_precipitation_in AS climate_normal_precipitation_in
    FROM WEATHER_SOURCE_RAW.PWS_BI_SAMPLE.POINT_CLIMATOLOGY_DAY
    WHERE city_name IS NOT NULL;

CREATE OR REPLACE TASK TASK_PROCESS_FORECAST
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_WEATHER_ROOT
AS
    CREATE OR REPLACE VIEW STG_WEATHER_FORECAST AS
    SELECT
        city_name,
        country_code,
        date_valid_std::DATE AS forecast_date,
        doy_std AS day_of_year,
        ROUND((avg_temperature_air_2m_f - 32) * 5/9, 2) AS forecast_avg_temp_c,
        probability_of_precipitation_pct,
        tot_precipitation_in AS forecast_precipitation_in
    FROM WEATHER_SOURCE_RAW.PWS_BI_SAMPLE.POINT_FORECAST_DAY
    WHERE city_name IS NOT NULL;

-- 2.3 CHILD TASK TAHAP 2 (Intermediate Join & Metrik Anomali)
CREATE OR REPLACE TASK TASK_ANOMALY_METRICS
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_PROCESS_HISTORY, TASK_PROCESS_CLIMATOLOGY
AS
    CREATE OR REPLACE TABLE INT_WEATHER_ANOMALY_METRICS AS
    SELECT
        h.city_name,
        h.country_code,
        h.weather_date,
        h.day_of_year,
        h.avg_temp_c,
        c.climate_normal_avg_temp_c,
        ROUND(h.avg_temp_c - c.climate_normal_avg_temp_c, 2) AS temp_anomaly_c,
        h.tot_precipitation_in,
        h.avg_wind_speed_mph
    FROM STG_WEATHER_HISTORY h
    LEFT JOIN STG_WEATHER_CLIMATOLOGY c
        ON h.city_name = c.city_name 
       AND h.country_code = c.country_code 
       AND h.day_of_year = c.day_of_year;

-- 2.4 FINAL TASK (Marts Analytics & Klasifikasi Risiko)
CREATE OR REPLACE TASK TASK_WEATHER_SUMMARY
    WAREHOUSE = COMPUTE_WH
    AFTER TASK_ANOMALY_METRICS, TASK_PROCESS_FORECAST
AS
    CREATE OR REPLACE TABLE FCT_GLOBAL_WEATHER_RISK_SUMMARY AS
    SELECT
        a.city_name,
        a.country_code,
        a.weather_date,
        a.avg_temp_c,
        a.temp_anomaly_c,
        a.tot_precipitation_in,
        a.avg_wind_speed_mph,
        CASE 
            WHEN a.temp_anomaly_c >= 5.0 THEN 'Gelombang Panas Ekstrem (Heatwave)'
            WHEN a.temp_anomaly_c <= -5.0 THEN 'Anomali Dingin Ekstrem'
            WHEN a.tot_precipitation_in >= 1.0 THEN 'Peringatan Hujan Lebat / Banjir'
            WHEN a.avg_wind_speed_mph >= 25.0 THEN 'Peringatan Angin Kencang'
            ELSE 'Kondisi Cuaca Normal'
        END AS kategori_peringatan_risiko,
        CURRENT_TIMESTAMP() AS updated_at
    FROM INT_WEATHER_ANOMALY_METRICS a;

-- =====================================================================
-- 3. AKTIFKAN (RESUME) TASK DARI DAUN (CHILD) KE AKAR (ROOT)
-- =====================================================================
-- Di Snowflake, child task harus di-resume terlebih dahulu sebelum root task
ALTER TASK TASK_WEATHER_SUMMARY RESUME;
ALTER TASK TASK_ANOMALY_METRICS RESUME;
ALTER TASK TASK_PROCESS_FORECAST RESUME;
ALTER TASK TASK_PROCESS_CLIMATOLOGY RESUME;
ALTER TASK TASK_PROCESS_HISTORY RESUME;
ALTER TASK TASK_WEATHER_ROOT RESUME;

-- =====================================================================
-- 4. JALANKAN SEKARANG (TRIGGER SEKALI EKSEKUSI)
-- =====================================================================
-- Perintah ini memicu Root Task agar seluruh alur berjalan detik ini juga
WEATHER_ANALYTICS_DB.PUBLIC.TASK_WEATHER_ROOTEXECUTE TASK TASK_WEATHER_ROOT;