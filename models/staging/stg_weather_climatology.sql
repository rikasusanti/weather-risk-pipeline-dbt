{{ config(materialized='view') }}

SELECT
    city_name,
    country_code,
    doy_std AS day_of_year,
    ROUND((avg_of__daily_avg_temperature_air_2m_f - 32) * 5/9, 2) AS climate_normal_avg_temp_c,
    avg_of__pos_daily_tot_precipitation_in AS climate_normal_precipitation_in
FROM {{ source('weather_source', 'point_climatology_day') }}
WHERE city_name IS NOT NULL