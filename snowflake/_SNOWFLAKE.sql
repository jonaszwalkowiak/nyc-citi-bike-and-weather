--------------------------------------------------------------------------------
-- One-time Snowflake bootstrap. Run ONCE in Snowsight as ACCOUNTADMIN.
-- Step 1: run ./snowflake/gen_key.sh and paste the printed public key below.
--------------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

--------------------------------------------------------------------------------
-- 1. ROLE + SERVICE USER (key-pair auth, no password)
--------------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS DBT_ROLE;

-- Optional: also grant the role to your personal user so you can query the data
-- GRANT ROLE DBT_ROLE TO USER <YOUR_PERSONAL_USER>;

CREATE USER IF NOT EXISTS DBT_USER
    DEFAULT_ROLE = DBT_ROLE
    MUST_CHANGE_PASSWORD = FALSE;

-- <<< paste the public key printed by ./snowflake/gen_key.sh >>>
ALTER USER DBT_USER SET RSA_PUBLIC_KEY
= 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs6DbsI7/ZHukGGmy3RSFY3Mjovozfsa5MPPzO/q6IUhwD3jausyxtgUkcXLt4B4nZQTzHTV/Sl5FR4dvEtEs7vLdBh9fY7GUxT4yW9YLVfl4J6dwp20576kGNJw7/hV1oujnRlO4TOaAP/1erR5nHBGUN37npsp9SYJr10ovIPAM7iqFOcvwgB2+a9pFl3CtHJQdOBaFoEB2dl1JRLZxVQWOahxFuCw1iNrYGNx3qLuC8ISc1C5JWYNuD94vU1A6ySuSdsrgAHUNkQU6uFhp6893Q0PWB8cYajlBXlqYDrYBLx/sNv8GXSbX8v5+Lf0uJDweFgu7q3OtOZA8VNwyeQIDAQAB';

GRANT ROLE DBT_ROLE TO USER DBT_USER;

--------------------------------------------------------------------------------
-- 2. WAREHOUSE
--------------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS DBT_WH
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE DBT_WH TO ROLE DBT_ROLE;

--------------------------------------------------------------------------------
-- 3. DATABASE + SCHEMA (dbt builds analytics objects here)
--------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS NYC_CITI_BIKE;

GRANT ALL PRIVILEGES ON DATABASE NYC_CITI_BIKE TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA NYC_CITI_BIKE.PUBLIC TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES
ON FUTURE TABLES IN SCHEMA NYC_CITI_BIKE.PUBLIC TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES
ON FUTURE VIEWS IN SCHEMA NYC_CITI_BIKE.PUBLIC TO ROLE DBT_ROLE;

--------------------------------------------------------------------------------
-- 4. RAW landing tables (Airflow writes here)
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS NYC_CITI_BIKE.PUBLIC.NYC_WEATHER_RAW (
    LOGICAL_DATE TIMESTAMP_NTZ,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    RAW_JSON VARIANT
);

CREATE TABLE
IF NOT EXISTS NYC_CITI_BIKE.PUBLIC.NYC_CITI_BIKE_STATION_STATUS_RAW (
    LOGICAL_DATE TIMESTAMP,
    LOADED_AT TIMESTAMP,
    RAW_JSON VARIANT
);

CREATE TABLE
IF NOT EXISTS NYC_CITI_BIKE.PUBLIC.NYC_CITI_BIKE_STATION_INFORMATION_RAW (
    LOGICAL_DATE TIMESTAMP,
    LOADED_AT TIMESTAMP,
    RAW_JSON VARIANT
);
