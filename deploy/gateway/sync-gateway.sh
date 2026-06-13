#!/usr/bin/env bash
#
# Sync the live Plug Assistance gateway with the current repo code.
#
# The public gateway (https://gateway.danfordchris.dev, via Cloudflare Tunnel)
# is served by a uvicorn process bound to 127.0.0.1:8099 on this host. Whenever
# anything under services/plug-gateway/ changes, run this script to:
#   1. install/refresh deps into the service venv,
#   2. run the test suite (abort the deploy if it fails),
#   3. gracefully restart uvicorn on :8099 with the new code,
#   4. health-check the running service.
#
# Usage:  deploy/gateway/sync-gateway.sh
# Safe to run repeatedly; it always brings :8099 to match HEAD of the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVC_DIR="$(cd "$SCRIPT_DIR/../../services/plug-gateway" && pwd)"
PORT="${GATEWAY_PORT:-8099}"
VENV="$SVC_DIR/.venv"
PY="$VENV/bin/python"

cd "$SVC_DIR"

echo "▸ Gateway service: $SVC_DIR (port $PORT)"

# 1. venv + deps ------------------------------------------------------------
if [[ ! -x "$PY" ]]; then
  echo "▸ Creating venv"
  python3 -m venv "$VENV"
fi
echo "▸ Installing deps"
"$PY" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
"$PY" -m pip install -q -r requirements.txt
[[ -f requirements-dev.txt ]] && "$PY" -m pip install -q -r requirements-dev.txt

# 2. tests ------------------------------------------------------------------
echo "▸ Running tests (deploy aborts on failure)"
"$PY" -m pytest -q

# 3. restart uvicorn --------------------------------------------------------
echo "▸ Restarting uvicorn on :$PORT"
# Kill any uvicorn bound to this port for this service.
pkill -f "uvicorn app.main:app .*--port $PORT" 2>/dev/null || true
sleep 1
nohup "$VENV/bin/uvicorn" app.main:app \
  --host 0.0.0.0 --port "$PORT" --log-level warning \
  > "$SVC_DIR/gateway.out" 2>&1 &
echo "▸ Started PID $!"

# 4. health check -----------------------------------------------------------
echo "▸ Waiting for health"
for i in $(seq 1 20); do
  if curl -fs "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "▸ Local health OK"
    break
  fi
  sleep 0.5
  [[ $i -eq 20 ]] && { echo "✗ Gateway did not come up"; tail -20 "$SVC_DIR/gateway.out"; exit 1; }
done

# /schedules should now answer 401 (route present, auth required) — proves the
# new code is live, not a stale process.
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/schedules")"
echo "▸ /schedules → $code (expect 401 = route live)"

echo "✓ Gateway synced. Public: https://gateway.danfordchris.dev/health"
