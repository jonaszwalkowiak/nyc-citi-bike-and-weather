.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help keys build up down restart logs ps dbt clean

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.env:
	@cp .env.example .env
	@echo ">> Created .env from .env.example — now fill in SNOWFLAKE_ACCOUNT and OPENWEATHER_API_KEY"

keys:  ## Generate the Snowflake RSA key pair into ./secrets
	@./snowflake/gen_key.sh

build: .env  ## Build the custom Airflow image
	$(COMPOSE) build

up: .env  ## Start the whole stack (UI at http://localhost:8080)
	$(COMPOSE) up -d

down:  ## Stop the stack
	$(COMPOSE) down

restart: down up  ## Restart the stack

logs:  ## Tail logs from all services
	$(COMPOSE) logs -f

ps:  ## List running services
	$(COMPOSE) ps

dbt:  ## Run dbt ad hoc, e.g. make dbt ARGS="build"
	$(COMPOSE) run --rm airflow-scheduler \
		/opt/dbt-venv/bin/dbt $(ARGS) --project-dir /usr/local/airflow/dbt --profiles-dir /usr/local/airflow/dbt

clean:  ## Stop the stack and delete volumes (WIPES the Airflow metadata DB)
	$(COMPOSE) down -v
