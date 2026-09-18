# Codebase Structure

> Config-only repository. There is no source tree; the "structure" is the set of
> deployment and configuration files at the repo root.

## Core Sections (Required)

### 1) Top-Level Map

| Path | Purpose | Evidence |
|------|---------|----------|
| `config.local.yaml` | LiteLLM config for the **local** (unauthenticated) instance: model list + `master_key` | `config.local.yaml` |
| `config.external.yaml` | LiteLLM config for the **external** (OIDC) instance: model list + `enable_oauth2_proxy_auth` mappings | `config.external.yaml` |
| `docker-compose.yml` | `litellm-local`, `litellm-external`, `cloudflared`, `postgres`, `redis` services + `litellm-net` network | `docker-compose.yml` |
| `docker-compose.dev.yml` | Local-dev override: disables cloudflared, exposes external on `127.0.0.1:4001` with no OIDC | `docker-compose.dev.yml` |
| `.env.example` | Template for cloud keys, master key, DB password, tunnel token, local bind IP | `.env.example` |
| `.gitignore` | Excludes `.env` and local artifacts from VCS | `.gitignore` |
| `Makefile` | Common tasks (env/up/down/logs/status/smoke/local-key/usage/models/redis-cli/clean + dev*) | `Makefile` |
| `scripts/` | `smoke-test.sh`, `create-local-key.sh`, `usage-report.sh` | `scripts/` |
| `README.md` | Setup, configuration, and usage instructions | `README.md` |
| `AGENTS.md` | Guidance for AI agents; access model + working agreements | `AGENTS.md` |
| `docs/codebase/` | Generated codebase documentation (this set) | `docs/codebase/` |

### 2) Entry Points

- Main runtime entry: the LiteLLM container command `--config /app/config.yaml` on both `litellm-local` and `litellm-external` (`docker-compose.yml`)
- Secondary entry points (worker/cli/jobs): NONE
- How entry is selected: Docker Compose starts each LiteLLM instance after `postgres` is healthy and `redis` is started (`depends_on` + `healthcheck`); `cloudflared` starts after `litellm-external`

### 3) Module Boundaries

| Boundary | What belongs here | What must not be here |
|----------|-------------------|------------------------|
| `config.local.yaml` / `config.external.yaml` | Model routing, provider params, `api_base` endpoints, auth settings | Secrets (keys are referenced via `os.environ/...`) |
| `docker-compose.yml` | Service topology, ports, volumes, env wiring | Business logic |
| `docker-compose.dev.yml` | Dev-only overrides (ports, config swap, profile) | Production auth settings |
| `.env` (gitignored) | Secrets: cloud keys, master key, DB password, tunnel token | Committed to VCS |

### 4) Naming and Organization Rules

- File naming pattern: kebab-case / lowercase (`config.local.yaml`, `docker-compose.dev.yml`, `.env.example`)
- Directory organization pattern: flat root; `scripts/` and `docs/codebase/` subdirectories
- Import aliasing or path conventions: N/A (no source code)

### 5) Evidence

- `docs/codebase/.codebase-scan.txt` (directory tree)
- `docker-compose.yml`
- `config.local.yaml`, `config.external.yaml`
