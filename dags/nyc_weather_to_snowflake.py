from datetime import datetime, timedelta

from airflow.providers.http.operators.http import HttpOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import dag, task

from assets import WEATHER_ASSET

LAT = "40.7128"
LON = "-74.0060"

DEFAULT_ARGS = {
    "owner": "JW",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


@dag(
    dag_id="nyc_weather_to_snowflake",
    tags=["nyc_citi_bike_and_weather"],
    default_args=DEFAULT_ARGS,
    schedule="@hourly",
    catchup=False,
    start_date=datetime(2026, 4, 30),
    max_active_runs=1,
)
def nyc_weather_to_snowflake():

    fetch_weather = HttpOperator(
        task_id="fetch_nyc_weather",
        http_conn_id="nyc_weather",
        endpoint="/data/2.5/weather",
        method="GET",
        # Query params via `data` (GET) so the API key stays out of the URL string
        # in the DAG source. The key itself lives in the `nyc_weather` connection.
        data={
            "lat": LAT,
            "lon": LON,
            "units": "metric",
            "appid": "{{ conn.nyc_weather.password }}",
        },
        # No response logging: avoids leaking the key/response into task logs.
        log_response=False,
    )

    @task(outlets=[WEATHER_ASSET])
    def load_to_snowflake(raw_json, logical_date=None):
        hook = SnowflakeHook(snowflake_conn_id="dbt_snowflake_conn_id")
        hook.run(
            sql="""
                INSERT INTO NYC_CITI_BIKE.PUBLIC.NYC_WEATHER_RAW (LOGICAL_DATE, LOADED_AT, RAW_JSON)
                SELECT %s, CURRENT_TIMESTAMP(), PARSE_JSON(%s)
            """,
            parameters=[str(logical_date), raw_json],
            autocommit=True,
        )

    load_to_snowflake(raw_json=fetch_weather.output)


nyc_weather_dag = nyc_weather_to_snowflake()
