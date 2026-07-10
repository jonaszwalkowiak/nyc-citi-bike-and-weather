"""Shared Airflow Assets — the single source of truth that couples the pipeline.

The extract-load DAGs declare these as `outlets` (producers); the `dbt_transform`
DAG consumes them as its `schedule` (consumer). Airflow couples producer and
consumer purely by Asset *name*, so defining the names once here keeps both sides
in sync and prevents silent drift from duplicated string literals.
"""
from airflow.sdk import Asset

WEATHER_ASSET = Asset(name="nyc_weather_raw")
STATION_STATUS_ASSET = Asset(name="nyc_citi_bike_station_status_raw")
STATION_INFORMATION_ASSET = Asset(name="nyc_citi_bike_station_information_raw")
