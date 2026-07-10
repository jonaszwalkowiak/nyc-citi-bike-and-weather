with source as (
    select * from {{ source('nyc_citi_bike_raw', 'NYC_WEATHER_RAW') }}
)

select
    logical_date,
    loaded_at,
    to_timestamp_ntz(raw_json:dt::number)       as observed_at,
    raw_json:name::string                       as city_name,
    raw_json:weather[0].main::string            as weather_main,
    raw_json:weather[0].description::string     as weather_description,
    raw_json:main.temp::float                   as temp_c,
    raw_json:main.feels_like::float             as feels_like_c,
    raw_json:main.temp_min::float               as temp_min_c,
    raw_json:main.temp_max::float               as temp_max_c,
    raw_json:main.humidity::number              as humidity_pct,
    raw_json:main.pressure::number              as pressure_hpa,
    raw_json:wind.speed::float                  as wind_speed_ms,
    raw_json:wind.deg::number                   as wind_deg,
    raw_json:clouds.all::number                 as cloudiness_pct,
    raw_json:visibility::number                 as visibility_m
from source
