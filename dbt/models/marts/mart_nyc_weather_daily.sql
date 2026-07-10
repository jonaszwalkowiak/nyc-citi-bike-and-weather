with weather as (
    select * from {{ ref('stg_nyc_weather') }}
)

select
    cast(observed_at as date)     as weather_date,
    count(*)                      as observation_count,
    round(avg(temp_c), 1)         as avg_temp_c,
    min(temp_min_c)               as min_temp_c,
    max(temp_max_c)               as max_temp_c,
    round(avg(humidity_pct), 0)   as avg_humidity_pct,
    round(avg(wind_speed_ms), 1)  as avg_wind_speed_ms,
    round(avg(pressure_hpa), 0)   as avg_pressure_hpa,
    max(loaded_at)                as last_loaded_at
from weather
group by 1
order by 1
