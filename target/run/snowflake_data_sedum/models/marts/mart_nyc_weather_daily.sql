
  
    

create or replace transient table NYC_CITI_BIKE.PUBLIC.mart_nyc_weather_daily
    
    
    
    as (select
    cast(logical_date as date) as weather_date,
    count(*) as record_count,
    max(loaded_at) as last_loaded_at
from NYC_CITI_BIKE.PUBLIC.stg_nyc_weather
group by 1
    )
;


  