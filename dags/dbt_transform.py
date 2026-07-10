"""End-to-end transformation ("T" in ELT): runs the dbt project via Cosmos.

Cosmos renders every dbt model and test as its own Airflow task, so you get the
full model graph, per-model retries and observability inside Airflow.

dbt runs from its isolated venv (/opt/dbt-venv) via subprocess, so there is no
dependency clash with Airflow. The DAG is scheduled on the Assets emitted by the
extract-load DAGs, so it fires right after fresh raw data lands in Snowflake.

Credentials: instead of a hand-written profiles.yml, Cosmos builds the dbt
profile at runtime from the SAME Airflow connection the EL DAGs use
(`dbt_snowflake_conn_id`) via SnowflakePrivateKeyPemProfileMapping — key-pair
auth using the inline PEM stored in the connection's `private_key_content`. That
makes the Airflow connection the single source of truth for Snowflake creds.
"""
from datetime import timedelta

from cosmos import (
    DbtDag,
    ExecutionConfig,
    ProfileConfig,
    ProjectConfig,
    RenderConfig,
)
from cosmos.constants import ExecutionMode, InvocationMode, LoadMode
from cosmos.profiles import SnowflakePrivateKeyPemProfileMapping

from assets import (
    STATION_INFORMATION_ASSET,
    STATION_STATUS_ASSET,
    WEATHER_ASSET,
)

DBT_PROJECT_DIR = "/usr/local/airflow/dbt"
DBT_EXECUTABLE = "/opt/dbt-venv/bin/dbt"

# The dbt profile is generated from the `dbt_snowflake_conn_id` Airflow connection
# (same one the EL DAGs use). `profile_name` must match `profile:` in dbt_project.yml.
profile_config = ProfileConfig(
    profile_name="snowflake_data_sedum",
    target_name="prod",
    profile_mapping=SnowflakePrivateKeyPemProfileMapping(
        conn_id="dbt_snowflake_conn_id",
        profile_args={"threads": 4},
    ),
)

dbt_transform = DbtDag(
    dag_id="dbt_transform",
    project_config=ProjectConfig(
        DBT_PROJECT_DIR,
        # No dbt packages in this project, so skip `dbt deps` during DAG parsing
        # and task execution (one less thing that can fail at parse time).
        install_dbt_deps=False,
    ),
    profile_config=profile_config,
    execution_config=ExecutionConfig(
        dbt_executable_path=DBT_EXECUTABLE,
        execution_mode=ExecutionMode.LOCAL,
        invocation_mode=InvocationMode.SUBPROCESS,
    ),
    render_config=RenderConfig(
        load_method=LoadMode.DBT_LS,
        dbt_executable_path=DBT_EXECUTABLE,
        # dbt lives in an isolated venv, not the Airflow env, so `dbt ls` during
        # DAG parsing must also shell out via subprocess. RenderConfig defaults to
        # DBT_RUNNER (imports dbt in-process), which rejects a custom executable path.
        invocation_mode=InvocationMode.SUBPROCESS,
    ),
    # Fire T right after any fresh raw data lands. Asset identity is shared with
    # the EL DAGs via dags/assets.py (Airflow couples producer/consumer by name).
    schedule=[WEATHER_ASSET, STATION_STATUS_ASSET, STATION_INFORMATION_ASSET],
    catchup=False,
    # Same owner/retry policy as the EL DAGs; Cosmos renders each model/test as
    # its own task, so retries here mean per-model retries.
    default_args={"owner": "JW", "retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["nyc_citi_bike_and_weather", "dbt"],
)
