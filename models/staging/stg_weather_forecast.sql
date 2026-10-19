{{ config(materialized='view') }}

SELECT
    city_name,
    country_code,
    date_valid_std::DATE AS forecast_date,
    doy_std AS day_of_year,
    ROUND((avg_temperature_air_2m_f - 32) * 5/9, 2) AS forecast_avg_temp_c,
    probability_of_precipitation_pct,
    tot_precipitation_in AS forecast_precipitation_in
FROM {{ source('weather_source', 'point_forecast_day') }}
WHERE city_name IS NOT NULL