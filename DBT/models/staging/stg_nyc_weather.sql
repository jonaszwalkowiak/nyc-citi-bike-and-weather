select
    logical_date,
    loaded_at,
    raw_json
from {{ source('nyc_citi_bike_raw', 'NYC_WEATHER_RAW') }}
