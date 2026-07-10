# Airflow + dbt + Snowflake — Modern Data Stack

End-to-end **ELT** for **NYC Citi Bike + weather** data on **Airflow 3.3 (Astro Runtime) + dbt (via Astronomer Cosmos) + Snowflake**,
fully containerized. The only thing you provide is your Snowflake account + an
OpenWeather API key in a single `.env` file.

```
Extract + Load (Airflow)                     Transform (dbt via Cosmos)
┌─────────────────────────────┐              ┌──────────────────────────┐
│ nyc_weather        @hourly  │──▶ Asset ─┐  │ dbt_transform            │
│ station_status     */15 min │──▶ Asset ─┼─▶│  stg_nyc_weather (view)  │
│ station_information @daily  │──▶ Asset ─┘  │  mart_nyc_weather_daily  │
└─────────────────────────────┘              └──────────────────────────┘
        HttpOperator → Snowflake RAW               Snowflake analytics
```

The EL DAGs emit Airflow **Assets** when fresh raw data lands; the dbt DAG is
scheduled on those Assets, so transformation runs right after load.

## Layout

| Path                | What it is                                                        |
|---------------------|------------------------------------------------------------------|
| `docker-compose.yml`| Airflow 3.3 stack (LocalExecutor): postgres + apiserver + scheduler + dag-processor + triggerer |
| `docker/`           | Custom image on Astro Runtime 3.3-2: providers + Cosmos; `dbt-snowflake` in isolated venv `/opt/dbt-venv` |
| `dags/`             | 3 extract-load DAGs + `dbt_transform.py` (Cosmos) + shared `assets.py` (Asset names) |
| `dbt/`              | dbt project; the DAG gets creds from the Airflow connection, `profiles.yml` is for ad-hoc CLI only |
| `snowflake/`        | `_SNOWFLAKE.sql` bootstrap + `gen_key.sh` (RSA key pair)         |
| `.env.example`      | **the only file you edit** (copy to `.env`)                       |
| `secrets/`          | your `dbt_user.p8` private key lands here (gitignored)            |

## One-time setup

**Prerequisites:** Docker Desktop (give it ≥ 4 GB RAM), a Snowflake account, an
[OpenWeather API key](https://openweathermap.org/api).

### 1. Generate the Snowflake key pair
```bash
make keys        # writes secrets/dbt_user.p8 and prints the public key
```

### 2. Bootstrap Snowflake (once)
Paste the printed public key into `snowflake/_SNOWFLAKE.sql`
(`RSA_PUBLIC_KEY = '...'`), then run the whole file in Snowsight as
`ACCOUNTADMIN`. It creates the role, service user, warehouse, database, and the
RAW landing tables.

### 3. Fill in credentials
```bash
cp .env.example .env
```
Edit `.env` and set at least:
- `SNOWFLAKE_ACCOUNT` — e.g. `xy12345.eu-central-1`
- `OPENWEATHER_API_KEY`

(The rest already match `_SNOWFLAKE.sql`: `DBT_USER` / `DBT_ROLE` / `DBT_WH` / `NYC_CITI_BIKE`.)

## Run

```bash
make build       # build the custom Airflow image
make up          # start everything
```
Open **http://localhost:8080** — dev mode is **login-free** (SimpleAuthManager,
everyone is admin) — then unpause the DAGs. All connections (`nyc_weather`,
`nyc_citi_bike`, `dbt_snowflake_conn_id`) are injected from `.env` via
`AIRFLOW_CONN_*` env vars in `docker-compose.yml` — no UI clicking.

### Snowflake connection (`dbt_snowflake_conn_id`)

Key-pair (RSA) auth with the **private key inline as text** (`private_key_content`),
**unencrypted**, password empty. Everything comes from `.env`; the only key-specific
var is `SNOWFLAKE_PRIVATE_KEY_CONTENT` — the full PEM on one line with newlines as
`\n`. Generate it safely from your key file (no manual escaping):

```bash
python3 -c "import json;print('SNOWFLAKE_PRIVATE_KEY_CONTENT='+json.dumps(open('secrets/dbt_user.p8').read())[1:-1])" >> .env
```

The key **must** be the private half of the `RSA_PUBLIC_KEY` registered on
`DBT_USER` in `snowflake/_SNOWFLAKE.sql`, and must be **unencrypted** (no passphrase).
The `dbt_transform` DAG uses this connection directly — Cosmos maps
`private_key_content` → the dbt profile, so the inline PEM is all it needs. Only
ad-hoc CLI dbt (`make dbt`) reads the key as a **file**
(`SNOWFLAKE_PRIVATE_KEY_PATH` → `secrets/dbt_user.p8`); keep the file and the
inline content in sync (same key) if you use both.

Handy targets:
```bash
make logs                 # tail logs
make dbt ARGS="build"     # run dbt ad hoc against Snowflake
make down                 # stop
make clean                # stop + wipe the Airflow metadata DB
```

## How credentials flow (no secrets in git)

- **All four DAGs source credentials from Airflow connections** (`nyc_weather`,
  `nyc_citi_bike`, `dbt_snowflake_conn_id`), built from `.env` via `AIRFLOW_CONN_*`
  env vars in `docker-compose.yml`. The Snowflake key travels inline as
  `SNOWFLAKE_PRIVATE_KEY_CONTENT` (unencrypted PEM).
- **dbt (via Cosmos)** uses that same `dbt_snowflake_conn_id` connection —
  `SnowflakePrivateKeyPemProfileMapping` turns it into the dbt profile at runtime,
  so the Airflow connection is the single source of truth (no profile file needed).
- **Ad-hoc CLI dbt** (`make dbt`) is the only path that uses `dbt/profiles.yml` +
  the **key file** (`private_key_path` → `./secrets/dbt_user.p8`).
- The **private key** never leaves `./secrets` (mounted read-only at
  `/usr/local/airflow/secrets`). `.env`, `secrets/*`, and `*.p8` are gitignored.

## Notes / gotchas

- **dbt lives in its own venv** (`/opt/dbt-venv`) and Cosmos invokes it via
  subprocess — this avoids dbt-core ↔ Airflow dependency clashes.
- The `dbt_transform` DAG parses via `dbt ls` at DAG-parse time, so `.env` must
  be filled in before `make up` (otherwise that one DAG shows an import error;
  the EL DAGs still load). For a fully hermetic parse you can pre-generate a dbt
  manifest and switch Cosmos to `LoadMode.DBT_MANIFEST`.
- Key-pair (not password) auth is intentional: Snowflake blocks single-factor
  password sign-ins for service users.
- Base image is **Astro Runtime 3.3-2** (`AIRFLOW_HOME=/usr/local/airflow`, user
  `astro`). Because the Astro entrypoint doesn't auto-migrate the DB, the
  `airflow-init` service runs `airflow db migrate` explicitly. To upgrade, bump
  the tag in `docker/Dockerfile` + the image tag in `docker-compose.yml`.
