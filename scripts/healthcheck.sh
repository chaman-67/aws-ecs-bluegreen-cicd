#!/usr/bin/env bash
# Smoke-test a deployed service. Retries with backoff before failing.
set -euo pipefail

URL="${1:-}"
[[ -z "$URL" ]] && { echo "Usage: $0 <url>"; exit 1; }

MAX_ATTEMPTS="${MAX_ATTEMPTS:-12}"
SLEEP_S="${SLEEP_S:-5}"

for i in $(seq 1 "$MAX_ATTEMPTS"); do
  printf "[healthcheck] attempt %d/%d  →  %s … " "$i" "$MAX_ATTEMPTS" "$URL"
  if curl -fsS --max-time 5 "$URL" >/tmp/hc.json; then
    echo "OK"
    cat /tmp/hc.json | jq . 2>/dev/null || cat /tmp/hc.json
    exit 0
  fi
  echo "fail (retrying in ${SLEEP_S}s)"
  sleep "$SLEEP_S"
done

echo "[healthcheck] ✗ service did not become healthy after $MAX_ATTEMPTS attempts"
exit 1
