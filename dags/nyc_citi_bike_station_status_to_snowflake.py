from datetime import datetime, timedelta

from airflow.providers.http.operators.http import HttpOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import dag, task

from assets import STATION_STATUS_ASSET

DEFAULT_ARGS = {
    "owner": "JW",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


@dag(
    dag_id="nyc_citi_bike_station_status_to_snowflake",
    tags=["nyc_citi_bike_and_weather"],
    default_args=DEFAULT_ARGS,
    schedule="*/15 * * * *",
    catchup=False,
    start_date=datetime(2026, 4, 30),
    max_active_runs=1,
)
def nyc_citi_bike_station_status_to_snowflake():

    fetch_station_status = HttpOperator(
        task_id="fetch_station_status",
        http_conn_id="nyc_citi_bike",
        endpoint="/gbfs/en/station_status.json",
        method="GET",
        # Payload is large (every NYC station); keep it out of the task logs.
        log_response=False,
    )

    @task(outlets=[STATION_STATUS_ASSET])
    def load_to_snowflake(raw_json, logical_date=None):
        hook = SnowflakeHook(snowflake_conn_id="dbt_snowflake_conn_id")
        hook.run(
            sql="""
                INSERT INTO NYC_CITI_BIKE.PUBLIC.NYC_CITI_BIKE_STATION_STATUS_RAW (LOGICAL_DATE, LOADED_AT, RAW_JSON)
                SELECT %s, CURRENT_TIMESTAMP(), PARSE_JSON(%s)
            """,
            parameters=[str(logical_date), raw_json],
            autocommit=True,
        )

    load_to_snowflake(raw_json=fetch_station_status.output)


nyc_citi_bike_station_status_dag = nyc_citi_bike_station_status_to_snowflake()
