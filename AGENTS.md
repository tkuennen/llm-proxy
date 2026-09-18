# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Purpose

This repository deploys an **LLM gateway** that proxies OpenAI-compatible requests to
multiple LLM servers in our AI cluster. It uses [LiteLLM](https://github.com/BerriAI/litellm)
as the proxy and PostgreSQL for durable usage tracking. Clients use the standard OpenAI SDK
pointed at a single endpoint; the proxy routes to the correct upstream (cloud provider or
local GPU/Mac/Ollama server) based on the requested model name.

This is a **configuration/deployment repository** — there is no application source code.
Changes are made to `config.yaml`, `docker-compose.yml`, `.env*`, and supporting docs.

## Access Model (two modes)

The system must support two distinct access modes:

### 1. Local cluster network — unauthenticated
- Intended for trusted hosts on the internal AI-cluster network.
- No per-request authentication; requests are accepted from the cluster subnet.
- **Constraint:** this mode must only be reachable from the cluster network (do not expose
  it to the public internet). Restrict by network/subnet, not by an open public port.
- Usage in this mode is still attributed to a caller identity (see Usage Tracking below).

### 2. External users — OIDC + Cloudflare Tunnel
- Intended for users outside the cluster network.
- Authentication is via **OIDC** (OpenID Connect). The proxy must validate the OIDC
  identity and map it to a LiteLLM user/key for authorization and usage attribution.
- Public exposure is provided through **Cloudflare Tunnel** (`cloudflared`), not by
  publishing the proxy port directly. The tunnel terminates at the proxy and enforces that
  only authenticated (OIDC) requests are served externally.

> The two modes are mutually exclusive in exposure: local = network-restricted &
> unauthenticated; external = OIDC-authenticated & tunnel-only. Never expose the
> unauthenticated mode publicly.

## Usage Tracking (per user)

- Every request must be attributable to a **user**, regardless of access mode.
  - External users: identity comes from the OIDC subject (`sub` claim).
  - Local users: identity comes from a caller-provided identifier (e.g. a per-host key or
    a declared user tag) since there is no OIDC locally.
- Token counts, cost, and model used are recorded per user in PostgreSQL (LiteLLM's
  built-in spend/usage tracking).
- Provide a way to report per-user usage (LiteLLM UI dashboard and/or an exportable
  report). Do not lose attribution when a request is routed to a local (unauthenticated
  upstream) model.

## Repository Layout

| Path | Purpose |
|------|---------|
| `config.local.yaml` | LiteLLM config for the **local** (unauthenticated) instance |
| `config.external.yaml` | LiteLLM config for the **external** (OIDC) instance |
| `docker-compose.yml` | `litellm-local`, `litellm-external`, `cloudflared`, `postgres`, `redis` services + `litellm-net` network |
| `.env.example` | Template for cloud keys, master key, DB password, tunnel token |
| `.gitignore` | Keeps `.env` and local artifacts out of VCS |
| `Makefile` | Common tasks: `env`, `up`, `down`, `logs`, `status`, `local-key`, `usage`, `clean`, `dev*` |
| `docker-compose.dev.yml` | Local-dev override: disables cloudflared, exposes external on `:4001` with no OIDC |
| `scripts/` | `smoke-test.sh`, `create-local-key.sh`, `usage-report.sh` |
| `README.md` | Setup and usage instructions |
| `docs/codebase/` | Generated codebase documentation (STACK, STRUCTURE, ARCHITECTURE, CONVENTIONS, INTEGRATIONS, TESTING, CONCERNS) |

> `config.local.yaml` and `config.external.yaml` share the same `model_list`. Keep them in
> sync when adding/removing models.

## Conventions

- Secrets (cloud keys, DB password, OIDC client secret) live in `.env` (gitignored), never
  committed. Reference them via `os.environ/...` in `config.yaml` or `env_file` in compose.
- Env vars are `UPPER_SNAKE_CASE`; logical model names and service names are lowercase/kebab-case.
- Keep `config.yaml` free of hardcoded secrets; upstream local IPs should be externalized to
  env vars where practical.
- Do not publish the PostgreSQL port to the host unless required; prefer an internal network.

## Working Agreements for Agents

1. **Prefer config changes over code.** This repo has no source; solve problems by editing
   `config.yaml`, `docker-compose.yml`, and `.env*`.
2. **Preserve the two-mode access model.** Any change to networking, ports, or auth must keep
   local mode network-restricted and external mode OIDC-gated behind the tunnel.
3. **Never weaken attribution.** Ensure per-user usage tracking still works after any routing
   or auth change.
4. **Do not commit secrets.** Verify `.env` is gitignored before adding new credentials.
5. Resolved Decisions

- **OIDC provider:** Google (via Cloudflare Access).
- **Local mode exposure:** restricted to the cluster subnet (bind `LOCAL_BIND_IP` + host
  firewall rule); never public.
- **Local attribution:** per-host virtual keys (flexible — one key per host/user, each with a
  `user_id`/alias).
- **Cloudflare Tunnel:** named tunnel with a fixed hostname.
- **Usage reporting:** LiteLLM dashboard (shared Postgres across both instances).
- **Image tag:** `main-latest` (per request; pin a version before production if desired).

## Implementation Notes

- Two LiteLLM instances share one Postgres so usage is unified in one dashboard.
- External auth uses `enable_oauth2_proxy_auth` + `oauth2_config_mappings`
  (`user_id` ← `Cf-Access-Authenticated-User-Email`) + `trusted_proxy_ranges`
  (the `litellm-net` subnet `172.28.0.0/16`). Cloudflare Access injects the identity header.
- `litellm-external` has **no host ports**; it is reachable only via the tunnel.
- `postgres` is **not** published to the host.

- Which OIDC provider (Entra ID / Azure AD, Google, Okta, Keycloak)?
- How should local (unauthenticated) callers be identified for usage attribution?
- Cloudflare Tunnel: named tunnel with a fixed hostname, or quick tunnel?
- Where should per-user usage be reported (LiteLLM UI, dashboard, or data warehouse export)?
