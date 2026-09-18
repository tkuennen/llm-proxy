# External Integrations

## Core Sections (Required)

### 1) Integration Inventory

| System | Type (API/DB/Queue/etc) | Purpose | Auth model | Criticality | Evidence |
|--------|---------------------------|---------|------------|-------------|----------|
| OpenAI | Cloud LLM API | `gpt-4o` completions | `OPENAI_API_KEY` | high | `config.local.yaml`, `.env.example` |
| Anthropic | Cloud LLM API | `claude-3-5-sonnet` completions | `ANTHROPIC_API_KEY` | high | `config.local.yaml`, `.env.example` |
| Google Gemini | Cloud LLM API | `gemini-1.5-pro` completions | `GEMINI_API_KEY` | high | `config.local.yaml`, `.env.example` |
| vLLM (NVIDIA GPU) | Local LLM server | `llama3-70b` completions | `sk-optional` (none) | high | `config.local.yaml` |
| MLX (Mac Silicon) | Local LLM server | `mistral-nemo` completions | `sk-optional` (none) | med | `config.local.yaml` |
| Ollama (Mac/NVIDIA) | Local LLM server | `phi3-local` completions | `sk-optional` (none) | med | `config.local.yaml` |
| Ollama (Qwen) | Local LLM server | `qwen3.8` completions @ `100.81.43.100` | `sk-optional` (none) | med | `config.local.yaml` |
| Cloudflare Tunnel | Reverse tunnel | Public exposure of the external instance | `CLOUDFLARE_TUNNEL_TOKEN` | high | `docker-compose.yml` |
| Cloudflare Access (Google OIDC) | Auth proxy | External user authentication; injects identity header | Google OIDC | high | `config.external.yaml` |
| PostgreSQL 15 | Database | Token/cost tracking, API keys, rate limits (shared by both instances) | `litellm` / `POSTGRES_PASSWORD` | high | `docker-compose.yml` |
| Redis 7 | Cache / coordination | Cross-worker rate limits, budgets, router state, cache invalidation (shared by both instances) | none (internal) | high | `docker-compose.yml` |

### 2) Data Stores

| Store | Role | Access layer | Key risk | Evidence |
|-------|------|--------------|----------|----------|
| PostgreSQL | Durable usage, keys, limits | LiteLLM via `DATABASE_URL` | weak default password (now env-driven) | `docker-compose.yml` |
| Redis | Cross-worker rate limits, budgets, router state, cache | LiteLLM via `REDIS_HOST`/`REDIS_PORT` | none (internal, not published) | `docker-compose.yml` |

### 3) Secrets and Credentials Handling

- Credential sources: `.env` (cloud keys, master key, DB password, tunnel token) + inline `DATABASE_URL`/`REDIS_*` in `docker-compose.yml`
- Hardcoding checks: cloud keys are referenced via `os.environ/...` in the config files (good); DB password is env-driven via `POSTGRES_PASSWORD` (resolved)
- Rotation or lifecycle notes: [TODO] no rotation process documented

### 4) Reliability and Failure Behavior

- Retry/backoff behavior: [TODO] not configured in this repo (handled by LiteLLM defaults)
- Timeout policy: [TODO] not set in the config files
- Circuit-breaker or fallback behavior: [TODO] no fallback model mapping defined in the config files

### 5) Observability for Integrations

- Logging around external calls: proxy logs via `docker compose logs` / `make logs` (`Makefile`)
- Metrics/tracing coverage: [TODO] none configured (no Prometheus/Grafana/OTel)
- Missing visibility gaps: no centralized log sink, no metrics endpoint, no tracing

### 6) Evidence

- `config.local.yaml`, `config.external.yaml`
- `docker-compose.yml`
- `.env.example`
