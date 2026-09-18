# Architecture

## Core Sections (Required)

### 1) Architectural Style

- Primary style: **Reverse-proxy / API gateway** (two LiteLLM instances fronting many upstream LLM backends)
- Why this classification: `config.local.yaml` / `config.external.yaml` map logical model names to heterogeneous upstreams (cloud APIs + local vLLM/MLX/Ollama); `docker-compose.yml` runs two proxy instances plus a Cloudflare tunnel and shared Postgres/Redis
- Primary constraints:
  - Two access modes: local (unauthenticated, cluster-subnet only) and external (OIDC, tunnel only) (AGENTS.md)
  - Upstream local endpoints are addressed by hardcoded LAN IPs (`config.local.yaml`)
  - Usage/cost state is persisted in a shared PostgreSQL; cross-worker state in shared Redis (`docker-compose.yml`)

### 2) System Flow

```text
Local:   cluster host -> litellm-local :4000 -> model router -> upstream (cloud / vLLM / MLX / Ollama)
External: user -> Cloudflare Tunnel -> Cloudflare Access (Google OIDC) -> litellm-external -> model router -> upstream
Both:    -> PostgreSQL (shared token/cost + API key records) + Redis (shared rate limits/budgets/router state)
```

1. Local: cluster host calls `:4000/v1` with a per-host virtual key (README.md).
2. External: user hits the Cloudflare hostname; Access performs Google OIDC and injects `Cf-Access-Authenticated-User-Email` (config.external.yaml).
3. LiteLLM resolves identity (virtual key `user_id`, or the OIDC header mapped to `user_id`) and looks up the logical model name (e.g. `llama3-70b`, `qwen3.8`) in the config.
4. The router forwards the request to the mapped upstream `api_base` (cloud provider or local IP).
5. The upstream returns a completion; LiteLLM streams it back to the client.
6. Token usage and cost are recorded against the `user_id` in the shared PostgreSQL; rate-limit/budget counters are coordinated in shared Redis (docker-compose.yml, README.md).

### 3) Layer/Module Responsibilities

| Layer or module | Owns | Must not own | Evidence |
|-----------------|------|--------------|----------|
| LiteLLM proxy (x2) | Routing, auth, token/cost accounting, UI dashboard | Upstream model inference | `docker-compose.yml` |
| `config.local.yaml` / `config.external.yaml` | Model-name → upstream mapping, auth settings | Secrets, runtime state | `config.local.yaml`, `config.external.yaml` |
| PostgreSQL | Persistent usage, keys, rate limits | Request routing | `docker-compose.yml` |
| Redis | Cross-worker rate limits, budgets, router state, cache | Durable records of truth | `docker-compose.yml` |

### 4) Reused Patterns

| Pattern | Where found | Why it exists |
|---------|-------------|---------------|
| Adapter / unified API | `config.local.yaml` / `config.external.yaml` `model_list` | Expose heterogeneous backends behind one OpenAI-compatible interface |
| Config-as-data | `config.local.yaml` / `config.external.yaml` | Add/remove models without code changes |
| Sidecar DB + cache | `docker-compose.yml` `postgres` + `redis` | Durable usage tracking and consistent multi-worker enforcement |
| Dual-instance isolation | `docker-compose.yml` | Separate unauthenticated (local) and OIDC (external) auth postures |

### 5) Known Architectural Risks

- Each LiteLLM instance is a single replica with no load-balancer in front — a point of failure for its mode's traffic.
- Upstream local endpoints are hardcoded IPs; a host moving IP breaks routing silently.
- The two config files share a `model_list` that must be kept in sync manually (drift risk).

Resolved (previously risks): Postgres and Redis are no longer published to the host; the two auth postures are isolated across instances; shared Redis makes multi-worker enforcement consistent.

### 6) Evidence

- `docker-compose.yml`
- `config.local.yaml`, `config.external.yaml`
- `README.md`
