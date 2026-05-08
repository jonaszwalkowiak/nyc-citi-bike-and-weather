
  create or replace   view NYC_CITI_BIKE.PUBLIC.stg_nyc_weather
  
  
  
  
  as (
    select
    logical_date,
    loaded_at,
    raw_json
from NYC_CITI_BIKE.PUBLIC.NYC_WEATHER_RAW
  );

