# Codebase Concerns

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| high | Local upstream endpoints are hardcoded LAN IPs | `config.local.yaml`, `config.external.yaml` | Host IP change silently breaks routing | Externalize to env vars / config |
| med | `LOCAL_BIND_IP` defaults to `0.0.0.0`; subnet restriction depends on a host firewall rule | `docker-compose.yml`, `.env.example` | If the firewall rule is forgotten, the unauthenticated instance is exposed | Set `LOCAL_BIND_IP` to the cluster NIC and enforce the firewall rule |
| med | Floating image tag `main-latest` | `docker-compose.yml` | Non-reproducible deploys, surprise breaking changes | Pin a specific version before production |
| low | No observability (metrics/tracing/log sink) | `docker-compose.yml` | Hard to diagnose routing/cost issues | Add Prometheus/Grafana or log forwarding |

Resolved (previously high): PostgreSQL is no longer published to the host and its
password is read from `POSTGRES_PASSWORD`; external users are now authenticated via
Google OIDC (Cloudflare Access) with per-user attribution. A shared Redis instance is
now configured (`REDIS_HOST`/`REDIS_PORT`) so multi-worker rate limits, budgets, and
router state are consistent — this clears the "No Redis configured" UI warning.

### 2) Technical Debt

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| Hardcoded IPs for local models | Quick local-cluster setup | `config.local.yaml`, `config.external.yaml` | Breaks on network change | Env-driven `api_base` |
| Duplicated `model_list` across two configs | Dual-instance design | `config.local.yaml`, `config.external.yaml` | Model drift between instances | Single source of truth / sync check (`make models`) |
| No per-model timeouts/fallbacks | Not yet configured | `config.local.yaml`, `config.external.yaml` | Upstream hangs block clients | Add `request_timeout` + fallback models |

### 3) Security Concerns

| Risk | OWASP category (if applicable) | Evidence | Current mitigation | Gap |
|------|--------------------------------|----------|--------------------|-----|
| Unauthenticated local instance reachable if firewall rule is missed | A07 Auth Failures | `docker-compose.yml`, `.env.example` | `LOCAL_BIND_IP` bind + documented firewall rule | enforcement depends on host firewall |
| Secrets in `.env` (gitignored) | A02 Cryptographic Failures | `.env.example`, `.gitignore` | `.gitignore` excludes `.env` | ensure `.env` never committed |
| Floating image tag `main-latest` | N/A | `docker-compose.yml` | none | pin a version for production |

Resolved (previously open): DB no longer published to host and password is env-driven; external users are OIDC-authenticated (Google via Cloudflare Access) with per-user attribution; shared Redis makes multi-worker enforcement consistent.

### 4) Performance and Scaling Concerns

| Concern | Evidence | Current symptom | Scaling risk | Suggested improvement |
|---------|----------|-----------------|-------------|-----------------------|
| Single replica per instance | `docker-compose.yml` | none yet | SPOF under load | run multiple replicas behind a LB |
| No request timeouts/fallbacks | `config.local.yaml`, `config.external.yaml` | upstream hangs block client | cascading latency | add timeouts + fallback models |

### 5) Fragile/High-Churn Areas

| Area | Why fragile | Churn signal | Safe change strategy |
|------|-------------|-------------|----------------------|
| `config.local.yaml` / `config.external.yaml` model list | manual IP edits + must stay in sync | no git history yet | run `make models` + `make smoke` after edits |

### 6) `[ASK USER]` Questions

Resolved (see AGENTS.md "Resolved Decisions"):
1. OIDC provider → **Google** (via Cloudflare Access).
2. Local mode exposure → **restricted to the cluster subnet** (`LOCAL_BIND_IP` + firewall rule).
3. Local attribution → **per-host virtual keys** (flexible, one key per host/user).
4. Cloudflare Tunnel → **named tunnel** with a fixed hostname.
5. Usage reporting → **LiteLLM dashboard** (shared Postgres).
6. Image tag → **`main-latest`** (pin before production if desired).

Remaining open:
1. [ASK USER] Should the LiteLLM image be pinned to a specific version for production reproducibility?

### 7) Evidence

- `docs/codebase/.codebase-scan.txt`
- `docker-compose.yml`
- `config.local.yaml`, `config.external.yaml`
- `README.md`
