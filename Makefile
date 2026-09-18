# LLM Proxy — common tasks
#
# Requires: docker, docker compose, bash, curl.
# All targets read .env (created from .env.example).

COMPOSE ?= docker compose
ENV_FILE := .env
# Dev stack = base + local-dev override (no OIDC, no cloudflared).
DEV_COMPOSE := $(COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml

.PHONY: help env up down restart logs ps status smoke local-key usage models redis-cli pull clean dev dev-down dev-logs dev-smoke

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if it does not exist
	@test -f $(ENV_FILE) || (echo "Creating $(ENV_FILE) from .env.example" && cp .env.example $(ENV_FILE))
	@test -f $(ENV_FILE) && echo "$(ENV_FILE) is present. Edit it before 'make up'."

up: ## Start all services (local, external, cloudflared, postgres)
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE). Run 'make env' first." && exit 1)
	$(COMPOSE) up -d

down: ## Stop and remove containers (keeps the postgres volume)
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

logs: ## Tail logs (usage: make logs [svc=litellm-local])
	$(COMPOSE) logs -f --tail=100 $(or $(svc),litellm-local)

ps: ## Show service status
	$(COMPOSE) ps

status: ## Quick health check of both instances
	@./scripts/smoke-test.sh both

smoke: ## Run the smoke test (usage: make smoke [target=local|external|both])
	@./scripts/smoke-test.sh $(or $(target),both)

local-key: ## Create a per-host key (usage: make local-key USER_ID=gpu-node-1)
	@test -n "$(USER_ID)" || (echo "Set USER_ID, e.g. make local-key USER_ID=gpu-node-1" && exit 1)
	@./scripts/create-local-key.sh $(USER_ID)

usage: ## Print per-user spend (usage: make usage [DAYS=7])
	@./scripts/usage-report.sh $(if $(DAYS),--days $(DAYS),)

models: ## List configured models from both configs
	@echo "local    (config.local.yaml):" \
		&& grep -E '^[[:space:]]*-?[[:space:]]*model_name:' config.local.yaml | sed -E 's/.*model_name:[[:space:]]*//; s/[[:space:]]+$$//' | sed 's/^/    /'
	@echo "external (config.external.yaml):" \
		&& grep -E '^[[:space:]]*-?[[:space:]]*model_name:' config.external.yaml | sed -E 's/.*model_name:[[:space:]]*//; s/[[:space:]]+$$//' | sed 's/^/    /'

redis-cli: ## Open a Redis shell (usage: make redis-cli [CMD=info])
	@if [ -n "$(CMD)" ]; then $(COMPOSE) exec -T redis redis-cli $(CMD); else $(COMPOSE) exec redis redis-cli; fi

pull: ## Pull latest images
	$(COMPOSE) pull

clean: ## Stop and remove containers AND the postgres volume (DESTROYS DATA)

# --- Local development (no OIDC, no Cloudflare) -------------------------------
# Dev endpoints: local http://127.0.0.1:4000/v1  |  external http://127.0.0.1:4001/v1

dev: ## Start the dev stack (no OIDC, no cloudflared)
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE). Run 'make env' first." && exit 1)
	$(DEV_COMPOSE) up -d

dev-down: ## Stop the dev stack (keeps the postgres volume)
	$(DEV_COMPOSE) down

dev-logs: ## Tail dev logs (usage: make dev-logs [svc=litellm-external])
	$(DEV_COMPOSE) logs -f --tail=100 $(or $(svc),litellm-local)

dev-smoke: ## Hit both dev instances directly (local :4000, external :4001)
	@echo "==> local    http://127.0.0.1:4000/v1" \
		&& curl -sS -m 30 -o /dev/null -w '    HTTP %{http_code}\n' \
		-H "Authorization: Bearer $(or $(LOCAL_KEY),dev-key)" -H "Content-Type: application/json" \
		-d '{"model":"'"$(or $(MODEL),llama3-70b)"'","messages":[{"role":"user","content":"ping"}],"max_tokens":8}' \
		http://127.0.0.1:4000/v1/chat/completions
	@echo "==> external http://127.0.0.1:4001/v1 (no OIDC in dev)" \
		&& curl -sS -m 30 -o /dev/null -w '    HTTP %{http_code}\n' \
		-H "Authorization: Bearer $(or $(LOCAL_KEY),dev-key)" -H "Content-Type: application/json" \
		-d '{"model":"'"$(or $(MODEL),llama3-70b)"'","messages":[{"role":"user","content":"ping"}],"max_tokens":8}' \
		http://127.0.0.1:4001/v1/chat/completions
	@read -r -p "This deletes the postgres volume (all usage data). Continue? [y/N] " ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then $(COMPOSE) down -v; else echo "Aborted."; fi
