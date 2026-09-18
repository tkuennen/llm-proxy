# Technology Stack

> This repository contains **no application source code**. It is a deployment/configuration
> repository that runs the pre-built [LiteLLM](https://github.com/BerriAI/litellm) proxy
> container and a PostgreSQL database via Docker Compose. All "stack" facts below are
> derived from the container images and config files, not from local source.

## Core Sections (Required)

### 1) Runtime Summary

| Area | Value | Evidence |
|------|-------|----------|
| Primary language | None (config-only repo; runtime is a pre-built Python service) | `docker-compose.yml` |
| Runtime + version | LiteLLM proxy (`ghcr.io/berriai/litellm:main-latest`) | `docker-compose.yml` |
| Package manager | N/A (no local manifests) | scan output: "No recognized manifest files found" |
| Module/build system | Docker Compose orchestration | `docker-compose.yml` |

### 2) Production Frameworks and Dependencies

| Dependency | Version | Role in system | Evidence |
|------------|---------|----------------|----------|
| LiteLLM proxy | `main-latest` (floating tag) | OpenAI-compatible LLM gateway / router | `docker-compose.yml` |
| PostgreSQL | `15` | Token/cost tracking, API keys, rate limits | `docker-compose.yml` |
| Redis | `7` | Cross-worker rate limits, budgets, router state, cache | `docker-compose.yml` |

### 3) Development Toolchain

| Tool | Purpose | Evidence |
|------|---------|----------|
| Docker + Docker Compose | Run and orchestrate the proxy and DB | `docker-compose.yml`, `README.md` |

No linters, formatters, test runners, or build tooling are present in the repository.

### 4) Key Commands

```bash
make env                      # create .env from .env.example (Makefile)
make up                       # start local + external + cloudflared + postgres + redis (Makefile)
make logs svc=litellm-local   # tail a service's logs (Makefile)
make status                   # smoke-test both instances (scripts/smoke-test.sh)
make local-key USER_ID=host1  # create a per-host key (scripts/create-local-key.sh)
make usage DAYS=7             # per-user spend report (scripts/usage-report.sh)
make models                   # list configured models from both configs (Makefile)
make redis-cli [CMD=info]     # open a Redis shell / run a command (Makefile)
make dev / dev-smoke / dev-down  # local dev stack: no OIDC, no cloudflared (Makefile)
```

### 5) Environment and Config

- Config sources: `config.local.yaml` + `config.external.yaml` (model routing), `.env` / `.env.example` (secrets), `docker-compose.yml` + `docker-compose.dev.yml` (orchestration)
- Required env vars (from `.env.example`): `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `LITELLM_MASTER_KEY`, `POSTGRES_PASSWORD`, `LOCAL_BIND_IP`, `CLOUDFLARE_TUNNEL_TOKEN`, `CLOUDFLARE_TUNNEL_HOSTNAME`; `DATABASE_URL` and `REDIS_HOST`/`REDIS_PORT` are set inline in `docker-compose.yml`
- Deployment/runtime constraints: local model endpoints (vLLM, MLX, Ollama) must be reachable at the hardcoded IPs in the config files and bound to `0.0.0.0` (README.md)

### 6) Evidence

- `docker-compose.yml`
- `config.local.yaml`, `config.external.yaml`
- `.env.example`
- `Makefile`
- `README.md`
