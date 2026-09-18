#!/usr/bin/env bash
#
# smoke-test.sh — verify both LiteLLM instances are up and routing.
#
# Usage:
#   ./scripts/smoke-test.sh                 # test local (default) + external
#   ./scripts/smoke-test.sh local           # test only the local instance
#   ./scripts/smoke-test.sh external        # test only the external instance
#
# Reads LOCAL_BIND_IP / CLOUDFLARE_TUNNEL_HOSTNAME from .env (if present).
set -euo pipefail

cd "$(dirname "$0")/.."

# Load .env if present (values are quoted; source it safely).
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

LOCAL_HOST="${LOCAL_BIND_IP:-127.0.0.1}"
LOCAL_URL="http://${LOCAL_HOST}:4000"
EXT_HOST="${CLOUDFLARE_TUNNEL_HOSTNAME:-llm.example.com}"
EXT_URL="https://${EXT_HOST}"
MODEL="${SMOKE_MODEL:-llama3-70b}"

# A minimal key so the local (key-attributed) instance accepts the request.
# Override with LOCAL_KEY if you have a real per-host key.
LOCAL_KEY="${LOCAL_KEY:-smoke-test-key}"

check() {
  local name="$1" url="$2" key="$3"
  echo "==> ${name}: ${url}"
  local body
  body=$(curl -sS -m 30 -o /tmp/smoke_body.$$ -w '%{http_code}' \
    -H "Authorization: Bearer ${key}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":8}" \
    "${url}/v1/chat/completions" 2>/tmp/smoke_err.$$ || true)
  local code="${body:-000}"
  if [[ "$code" =~ ^2 ]]; then
    echo "    OK (HTTP ${code})"
    head -c 400 /tmp/smoke_body.$$ 2>/dev/null | sed 's/^/    /'
    echo
  else
    echo "    FAIL (HTTP ${code})"
    sed 's/^/    /' /tmp/smoke_err.$$ 2>/dev/null || true
    head -c 400 /tmp/smoke_body.$$ 2>/dev/null | sed 's/^/    /'
    echo
    rm -f /tmp/smoke_body.$$ /tmp/smoke_err.$$
    return 1
  fi
  rm -f /tmp/smoke_body.$$ /tmp/smoke_err.$$
}

TARGET="${1:-both}"
rc=0
case "${TARGET}" in
  local)    check "local"    "${LOCAL_URL}" "${LOCAL_KEY}" || rc=1 ;;
  external) check "external" "${EXT_URL}"   "anything"      || rc=1 ;;
  both)
    check "local"    "${LOCAL_URL}" "${LOCAL_KEY}" || rc=1
    check "external" "${EXT_URL}"   "anything"      || rc=1
    ;;
  *) echo "unknown target: ${TARGET} (use local|external|both)" >&2; exit 2 ;;
esac
exit "${rc}"
