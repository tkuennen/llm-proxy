#!/usr/bin/env bash
#
# create-local-key.sh — generate a per-host virtual key on the LOCAL instance.
#
# Usage:
#   ./scripts/create-local-key.sh <user_id> [key_alias]
#
# Example:
#   ./scripts/create-local-key.sh gpu-node-1 "gpu-node-1"
#
# The returned key is what that host/user sends as the Authorization bearer.
# Spend is tracked against <user_id> in the shared dashboard.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

USER_ID="${1:?usage: create-local-key.sh <user_id> [key_alias]}"
ALIAS="${2:-${USER_ID}}"
LOCAL_HOST="${LOCAL_BIND_IP:-127.0.0.1}"
LOCAL_URL="http://${LOCAL_HOST}:4000"
MASTER_KEY="${LITELLM_MASTER_KEY:?LITELLM_MASTER_KEY not set (see .env)}"

echo "==> Creating key for user_id='${USER_ID}' on ${LOCAL_URL}"
curl -sS -X POST "${LOCAL_URL}/key/generate" \
  -H "Authorization: Bearer ${MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"${USER_ID}\",\"key_alias\":\"${ALIAS}\"}"
echo
