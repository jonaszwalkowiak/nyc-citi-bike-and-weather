-- Current bike/dock availability per station: the most recent status snapshot
-- for each station, enriched with station name/location/capacity.
with latest_status as (
    select *
    from {{ ref('stg_nyc_citi_bike_station_status') }}
    qualify row_number() over (
        partition by station_id order by loaded_at desc, last_reported_at desc
    ) = 1
),

info as (
    select * from {{ ref('stg_nyc_citi_bike_station_information') }}
)

select
    info.station_id,
    info.station_name,
    info.latitude,
    info.longitude,
    info.capacity,
    st.num_bikes_available,
    st.num_ebikes_available,
    st.num_docks_available,
    st.is_renting,
    st.last_reported_at,
    round(100.0 * st.num_bikes_available / nullif(info.capacity, 0), 1) as pct_bikes_available
from info
left join latest_status as st
    on info.station_id = st.station_id
