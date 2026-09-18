#!/usr/bin/env bash
#
# usage-report.sh — print per-user spend from the shared Postgres.
#
# Usage:
#   ./scripts/usage-report.sh            # top users by spend
#   ./scripts/usage-report.sh --days 7   # last 7 days
#
# Runs the query inside the postgres container (no local psql needed).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

DAYS="${2:-0}"
DB_USER="litellm"
DB_NAME="litellm"

if [[ "${1:-}" == "--days" && -n "${DAYS}" ]]; then
  WHERE="WHERE \"startTime\" >= now() - interval '${DAYS} days'"
else
  WHERE=""
fi

SQL="
SELECT
  COALESCE(u.user_id, k.user_id) AS user_id,
  COUNT(*)                       AS requests,
  ROUND(SUM(s.total_cost)::numeric, 6) AS total_cost
FROM \"LiteLLM_SpendLogs\" s
LEFT JOIN \"LiteLLM_VerificationToken\" k ON k.token_hash = s.user_api_key_hash
LEFT JOIN \"LiteLLM_UserTable\" u ON u.user_id = k.user_id
${WHERE}
GROUP BY 1
ORDER BY total_cost DESC
LIMIT 50;
"

docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" -c "${SQL}"
