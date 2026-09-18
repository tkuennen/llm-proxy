# Internal LLM Proxy

An AI gateway built on [LiteLLM](https://github.com/BerriAI/litellm) that exposes a single
OpenAI-compatible endpoint and routes requests across cloud providers (OpenAI, Anthropic,
Google) and local hardware (NVIDIA via vLLM, Mac via MLX, Ollama).

It supports **two access modes** and tracks **per-user usage** in a shared PostgreSQL
database (viewable in the LiteLLM dashboard):

| Mode | Who | Auth | Exposure |
|------|-----|------|----------|
| **Local cluster** | trusted hosts on the AI-cluster network | none (per-host virtual key for attribution) | cluster subnet only |
| **External** | users outside the cluster | Google OIDC via Cloudflare Access | Cloudflare Tunnel (named tunnel) only |

## Architecture

```
Local cluster hosts ──(cluster subnet)──> litellm-local  ─┐
                                                          ├─> PostgreSQL (shared usage/keys)
External users ──> Cloudflare Tunnel ──> Cloudflare Access (Google OIDC)
                                          └─> litellm-external ─┤
                                                                 └─> Redis (shared rate limits/budgets/router state)
```

- `litellm-local` — unauthenticated; reachable only from the cluster network. Callers use a
  per-host virtual key so usage is attributed per user.
- `litellm-external` — exposed only through the Cloudflare Tunnel. Cloudflare Access performs
  Google OIDC and injects the authenticated identity; LiteLLM maps it to `user_id` for
  per-user spend tracking.
- `postgres` — shared by both instances, so all usage appears in one dashboard. Not published
  to the host.
- `redis` — shared by both instances for cross-worker rate limits, budgets, router state, and
  cache invalidation (required for correct multi-worker enforcement). Not published to the host.

## Setup

### 1. Prerequisites
- Docker + Docker Compose.
- Local model endpoints (vLLM, MLX, Ollama) bound to accessible IPs (e.g. `0.0.0.0`).
- A Cloudflare account with a **named tunnel** and an **Access application** using Google OIDC.

### 2. Configure
```bash
cp .env.example .env
```
Edit `.env`:
- Cloud API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`).
- `LITELLM_MASTER_KEY` — admin key for the UI and key management.
- `POSTGRES_PASSWORD` — set a strong value.
- `LOCAL_BIND_IP` — the cluster NIC IP (and add a host firewall rule so only the cluster
  subnet reaches port 4000).
- `CLOUDFLARE_TUNNEL_TOKEN` — from Zero Trust → Networks → Tunnels.
- `CLOUDFLARE_TUNNEL_HOSTNAME` — the public hostname you create in Zero Trust.

Edit `config.local.yaml` / `config.external.yaml` to set the `api_base` IPs for your local
vLLM / MLX / Ollama servers.

### 3. Cloudflare (external mode)
1. Zero Trust → Networks → Tunnels → **Create a tunnel** (Cloudflared connector). Copy the
   token into `CLOUDFLARE_TUNNEL_TOKEN`.
2. Add a **public hostname** (e.g. `llm.example.com`) with service
   `http://litellm-external:4000`.
3. Create an **Access application** on that hostname using the **Google** IdP. This injects
   `Cf-Access-Authenticated-User-Email`, which `config.external.yaml` maps to `user_id`.

### 4. Start
```bash
docker-compose up -d
docker-compose logs -f litellm-local
```

### 5. Create local (per-host) keys
1. Open the local dashboard: `http://<cluster-ip>:4000/ui`
2. Log in with `LITELLM_MASTER_KEY`.
3. Generate a virtual key per host/user (set a `user_id`/alias for attribution).

## Usage

Point any OpenAI SDK at the proxy:

```python
from openai import OpenAI

# Local cluster (per-host key)
client = OpenAI(api_key="<LOCAL_VIRTUAL_KEY>", base_url="http://<cluster-ip>:4000/v1")

# External (via the Cloudflare hostname; Access handles auth)
client = OpenAI(api_key="anything", base_url="https://llm.example.com/v1")

response = client.chat.completions.create(
    model="llama3-70b",
    messages=[{"role": "user", "content": "Explain load balancing."}],
)
```

## Per-user usage
- Local: spend is tracked against the virtual key's `user_id`.
- External: spend is tracked against the OIDC identity (the authenticated email).
- View both in the LiteLLM dashboard (Users / Spend pages) or query the shared Postgres.

## Makefile & scripts

Common tasks are wrapped in a `Makefile` (run `make help`):

| Command | What it does |
|---------|-------------|
| `make env` | Create `.env` from `.env.example` |
| `make up` / `make down` | Start / stop all services |
| `make logs svc=litellm-local` | Tail logs for a service |
| `make status` | Smoke-test both instances |
| `make local-key USER_ID=gpu-node-1` | Create a per-host virtual key |
| `make usage DAYS=7` | Print per-user spend from Postgres |
| `make models` | List configured models from both configs |
| `make redis-cli [CMD=info]` | Open a Redis shell / run a command |
| `make clean` | Stop and **delete** the Postgres volume |

Scripts in `scripts/`:
- `smoke-test.sh [local|external|both]` — verify routing end-to-end.
- `create-local-key.sh <user_id> [alias]` — mint a per-host key.
- `usage-report.sh [--days N]` — per-user spend report.

## Local development (no OIDC, no Cloudflare)

A dev override (`docker-compose.dev.yml`) lets you test both instances directly,
without Cloudflare Access or the tunnel:

```bash
make dev          # start the dev stack (cloudflared disabled)
make dev-smoke    # hit local :4000 and external :4001
make dev-down     # stop it
```

Dev endpoints (both reachable on localhost, no OIDC):
- local: `http://127.0.0.1:4000/v1`
- external: `http://127.0.0.1:4001/v1`

The override is **not** auto-loaded — it only applies when you use the `dev*`
targets (or pass `-f docker-compose.dev.yml` yourself).
