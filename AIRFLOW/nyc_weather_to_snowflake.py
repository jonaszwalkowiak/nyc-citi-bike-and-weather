from datetime import datetime
from airflow.sdk import dag, task
from airflow.providers.http.operators.http import HttpOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

lat = "40.7128"
lon = "-74.0060"

@dag(
    dag_id="nyc_weather_to_snowflake",
    tags=["nyc_citi_bike_and_weather"],
    default_args={"owner": "JW"},
    schedule="@hourly",
    catchup=False,
    start_date=datetime(2026, 4, 30),
    max_active_runs=1,
)

def dag_creator():

    fetch_weather = HttpOperator(
        task_id="fetch_nyc_weather",
        http_conn_id="nyc_weather",
        endpoint=f"/data/2.5/weather?lat={lat}&lon={lon}&appid={{{{ conn.nyc_weather.password }}}}&units=metric",
        method="GET",
        log_response=True,
    )

    @task
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

dag = dag_creator()
