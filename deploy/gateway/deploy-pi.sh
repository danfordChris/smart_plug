#!/usr/bin/env bash
#
# Deploy the current gateway code to the PRODUCTION Pi and restart the
# container, so https://gateway.danfordchris.dev stays in sync on every change.
#
# Production topology (discovered):
#   Cloudflare Tunnel (cloudflared container) ──▶ plug-gateway container :8099
#   on the Pi, reaching Home Assistant at localhost:8123. Compose project
#   "gateway", file deploy/gateway/docker-compose.snippet.yml, secrets in the
#   Pi's root-owned deploy/gateway/gateway.env.
#
# The Pi's repo copy is root-owned and we have no passwordless sudo, so we do
# NOT write into it. Instead we rsync the service into a user-owned staging
# dir, `docker build` it (the `smart` user is in the docker group), tag it
# plug-gateway:latest, and recreate the container via the existing compose file
# WITHOUT rebuilding (so the root-owned context / gateway.env are reused as-is).
#
# Usage:  deploy/gateway/deploy-pi.sh
# Prereq: SSH key access to smart@<PI_HOST>; gateway already running once.

set -euo pipefail

PI_HOST="${PI_HOST:-smart@100.83.45.15}"
STAGING="${PI_STAGING:-gateway-src}"   # under the smart user's home (user-owned)
COMPOSE_FILE="/home/smart/smart_plug/smart_plug/deploy/gateway/docker-compose.snippet.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVC_DIR="$(cd "$SCRIPT_DIR/../../services/plug-gateway" && pwd)"

echo "▸ Local test gate (deploy aborts on failure)"
if [[ -x "$SVC_DIR/.venv/bin/python" ]]; then
  (cd "$SVC_DIR" && .venv/bin/python -m pytest -q)
else
  echo "  (skipped — no local .venv; run deploy/gateway/sync-gateway.sh first to test)"
fi

echo "▸ Syncing service → $PI_HOST:~/$STAGING"
rsync -az --delete \
  --exclude '__pycache__' --exclude '*.pyc' \
  --exclude '.venv' --exclude '*.db' --exclude '*.out' --exclude '.env' \
  "$SVC_DIR"/ "$PI_HOST:$STAGING/"

echo "▸ Building image + recreating container on the Pi"
ssh "$PI_HOST" "
  set -e
  docker build -t plug-gateway:latest ~/$STAGING
  docker compose -p gateway -f '$COMPOSE_FILE' up -d --no-build plug-gateway
  echo '--- waiting for health ---'
  for i in \$(seq 1 20); do
    curl -fs http://127.0.0.1:8099/health >/dev/null 2>&1 && { echo 'pi health OK'; break; }
    sleep 0.5
    [ \$i -eq 20 ] && { echo 'gateway did not come up'; docker logs --tail 30 plug-gateway; exit 1; }
  done
  echo -n '/schedules (expect 401) → '; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8099/schedules
"

echo "▸ Verifying public domain"
sleep 2
echo -n "  health   → "; curl -s --max-time 10 https://gateway.danfordchris.dev/health; echo
echo -n "  /schedules (expect 401) → "; curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://gateway.danfordchris.dev/schedules

echo "✓ Pi gateway synced with current code."
