{{ config(materialized='view') }}

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
FROM {{ source('weather_source', 'point_history_day') }}
WHERE city_name IS NOT NULL