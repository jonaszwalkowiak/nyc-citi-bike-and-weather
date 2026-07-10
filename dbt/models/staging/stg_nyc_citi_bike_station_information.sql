with source as (
    select * from {{ source('nyc_citi_bike_raw', 'NYC_CITI_BIKE_STATION_INFORMATION_RAW') }}
),

-- station_information is a full snapshot each run; keep only the most recent load
latest_snapshot as (
    select *
    from source
    qualify row_number() over (order by loaded_at desc) = 1
)

select
    to_timestamp_ntz(raw_json:last_updated::number) as feed_last_updated_at,
    loaded_at,
    station.value:station_id::string   as station_id,
    station.value:name::string         as station_name,
    station.value:short_name::string   as short_name,
    station.value:lat::float           as latitude,
    station.value:lon::float           as longitude,
    station.value:capacity::number     as capacity,
    station.value:region_id::string    as region_id
from latest_snapshot,
     lateral flatten(input => raw_json:data.stations) as station
