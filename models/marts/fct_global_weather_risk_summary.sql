{{ config(materialized='table') }}

WITH anomaly AS (
    SELECT * FROM {{ ref('int_weather_anomaly_metrics') }}
)

SELECT
    city_name,
    country_code,
    weather_date,
    avg_temp_c,
    temp_anomaly_c,
    tot_precipitation_in,
    avg_wind_speed_mph,
    CASE 
        WHEN temp_anomaly_c >= 5.0 THEN 'Gelombang Panas Ekstrem (Heatwave)'
        WHEN temp_anomaly_c <= -5.0 THEN 'Anomali Dingin Ekstrem'
        WHEN tot_precipitation_in >= 1.0 THEN 'Peringatan Hujan Lebat / Banjir'
        WHEN avg_wind_speed_mph >= 25.0 THEN 'Peringatan Angin Kencang'
        ELSE 'Kondisi Cuaca Normal'
    END AS kategori_peringatan_risiko,
    CURRENT_TIMESTAMP() AS dbt_updated_at
FROM anomaly