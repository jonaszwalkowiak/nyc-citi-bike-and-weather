# Custom image: Astro Runtime 3.3-2 (Airflow 3.3.0) + Snowflake/HTTP providers + Cosmos,
# plus dbt-snowflake in an ISOLATED virtualenv to avoid dependency clashes
# between dbt-core and Airflow.
#
# The Astro Runtime base image has ONBUILD triggers that (as root) auto-install
# packages.txt (apt) and requirements.txt (pip), then copy the build context into
# AIRFLOW_HOME. So we only add the dbt venv here.
FROM astrocrpublic.azurecr.io/runtime:3.3-2

# dbt in its own venv (isolated from the Airflow environment)
USER root
RUN python3 -m venv /opt/dbt-venv \
    && /opt/dbt-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/dbt-venv/bin/pip install --no-cache-dir "dbt-snowflake>=1.8,<2.0" \
    && chown -R astro:0 /opt/dbt-venv
USER astro
