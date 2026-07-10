with source as (
    select * from {{ source('nyc_citi_bike_raw', 'NYC_CITI_BIKE_STATION_STATUS_RAW') }}
)

select
    logical_date,
    loaded_at,
    to_timestamp_ntz(raw_json:last_updated::number)       as feed_last_updated_at,
    station.value:station_id::string                      as station_id,
    station.value:num_bikes_available::number             as num_bikes_available,
    station.value:num_ebikes_available::number            as num_ebikes_available,
    station.value:num_docks_available::number             as num_docks_available,
    station.value:is_renting::boolean                     as is_renting,
    station.value:is_returning::boolean                   as is_returning,
    to_timestamp_ntz(station.value:last_reported::number) as last_reported_at
from source,
     lateral flatten(input => raw_json:data.stations) as station
