from datetime import datetime
from airflow.sdk import dag, task
from airflow.providers.http.operators.http import HttpOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

@dag(
    dag_id="nyc_citi_bike_station_status_to_snowflake",
    tags=["nyc_citi_bike_and_weather"],
    default_args={"owner": "JW"},
    schedule="*/15 * * * *",
    catchup=False,
    start_date=datetime(2026, 5, 8),
    max_active_runs=1,
)

def dag_creator():

    fetch_station_status = HttpOperator(
        task_id="fetch_station_status",
        http_conn_id="nyc_citi_bike",
        endpoint="/gbfs/en/station_status.json",
        method="GET",
        log_response=True,
    )

    @task
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

dag = dag_creator()
