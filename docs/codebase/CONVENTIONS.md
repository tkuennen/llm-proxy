# Coding Conventions

> This repository has no application source code, so most coding conventions do not
> apply. The conventions below describe the configuration files that do exist.

## Core Sections (Required)

### 1) Naming Rules

| Item | Rule | Example | Evidence |
|------|------|---------|----------|
| Files | lowercase / kebab-case | `config.local.yaml`, `docker-compose.dev.yml` | repo root |
| Env vars | UPPER_SNAKE_CASE | `OPENAI_API_KEY`, `LITELLM_MASTER_KEY` | `.env.example` |
| Logical model names | kebab-case (dots allowed for versioned names) | `claude-3-5-sonnet`, `llama3-70b`, `qwen3.8` | `config.local.yaml` |
| Service names | lowercase | `litellm-local`, `litellm-external`, `postgres`, `redis` | `docker-compose.yml` |
| Make targets | lowercase kebab-case | `local-key`, `redis-cli`, `dev-smoke` | `Makefile` |
| Scripts | kebab-case `.sh`, executable | `smoke-test.sh`, `create-local-key.sh` | `scripts/` |

### 2) Formatting and Linting

- Formatter: NONE configured
- Linter: NONE configured
- Most relevant enforced rules: N/A
- Run commands: N/A

### 3) Import and Module Conventions

- Import grouping/order: N/A (no source code)
- Alias vs relative import policy: N/A
- Public exports/barrel policy: N/A

### 4) Error and Logging Conventions

- Error strategy by layer: handled inside the LiteLLM image (not in this repo)
- Logging style: proxy logs are tailed via `make logs svc=...` / `docker compose logs` (`Makefile`, `docker-compose.yml`)
- Sensitive-data redaction rules: secrets are injected via `os.environ/...` references and `.env`, not hardcoded (`config.local.yaml`, `.env.example`)

### 5) Script and Makefile Conventions

- Scripts use `#!/usr/bin/env bash` + `set -euo pipefail`, `cd` to repo root, and load `.env` if present (`scripts/*.sh`)
- Make targets are self-documenting via the `## ` help suffix parsed by `make help` (`Makefile`)
- Dev overrides are isolated in `docker-compose.dev.yml` and never auto-loaded (`docker-compose.dev.yml`)

### 6) Testing Conventions

- Test file naming/location rule: N/A (no unit tests)
- Smoke/verification: `scripts/smoke-test.sh` and `make dev-smoke` exercise live routing
- Coverage expectation: N/A

### 7) Evidence

- `config.local.yaml`, `config.external.yaml`
- `docker-compose.yml`
- `.env.example`
- `Makefile`, `scripts/`
