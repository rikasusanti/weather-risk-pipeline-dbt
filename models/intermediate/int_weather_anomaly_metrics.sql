{{ config(materialized='table') }}

WITH hist AS (
    SELECT * FROM {{ ref('stg_weather_history') }}
),
clim AS (
    SELECT * FROM {{ ref('stg_weather_climatology') }}
)

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
FROM hist h
LEFT JOIN clim c
    ON h.city_name = c.city_name 
   AND h.country_code = c.country_code
   AND h.day_of_year = c.day_of_year