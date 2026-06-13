# Deploying the Plug Assistance gateway on the Pi

The gateway runs as a Docker container on the same Debian Pi as Home Assistant.

## Steps

1. **Build context** lives at `services/plug-gateway/`. The compose snippet here
   (`docker-compose.snippet.yml`) references it.

2. **Create the env file** (never committed):
   ```bash
   cp services/plug-gateway/.env.example deploy/gateway/gateway.env
   # edit gateway.env:
   #   HA_BASE_URL=http://localhost:8123
   #   HA_TOKEN=<a Home Assistant long-lived token>
   #   JWT_SECRET=$(openssl rand -hex 32)
   ```
   The `HA_TOKEN` is the credential that previously lived in the app — it now lives
   only here, on the server.

3. **Persistent data**:
   ```bash
   sudo mkdir -p /home/smart/plug-gateway/data
   ```

4. **Run**:
   ```bash
   docker compose -f deploy/gateway/docker-compose.snippet.yml up -d --build
   ```

5. **First account = admin**: the first `POST /auth/signup` becomes the active admin.
   Do this once, immediately, so nobody else can claim it.

## Enabling push notifications (FCM)

The app already registers each device's FCM token with the gateway
(`/push/register`). To let the gateway **send** push (so alerts reach a phone
with the app closed), give it a Firebase **service-account** key:

1. Firebase console → Project settings → Service accounts → *Generate new
   private key*. Save the JSON.
2. Copy it onto the Pi into the gateway's data volume, e.g.
   `scp fcm.json smart@<pi>:/home/smart/plug-gateway/data/fcm-service-account.json`
   (that dir is mounted at `/data` inside the container).
3. In `deploy/gateway/gateway.env` add:
   ```
   FCM_CREDENTIALS_FILE=/data/fcm-service-account.json
   ```
4. `deploy/gateway/deploy-pi.sh` (or `docker compose ... up -d`) to restart.

Until that file is present, push is simply **off** — the in-app alerts feed and
on-device (foreground) notifications keep working. iOS additionally needs an
**APNs key** uploaded in Firebase → Cloud Messaging for push to reach iPhones.

## Appliance diagnosis (ML)

The gateway logs telemetry (`PlugTelemetry`) and serves `GET /diagnosis/{entity_id}`
(status label + NL explanation). Models train + infer on the Pi; artifacts persist in
`/data/models`. Before any training it falls back to heuristics.

**Bootstrap the dataset from the HA recorder (read-only):**
```bash
# Discover power sensors with history first if unsure (read-only):
#   docker run --rm -v /home/smart/ha-config:/harec:ro python:3.12-slim \
#     python -c "import sqlite3;c=sqlite3.connect('file:/harec/home-assistant_v2.db?mode=ro',uri=True);\
#     print(c.execute(\"select m.entity_id,count(*) from states s join states_meta m on s.metadata_id=m.metadata_id where m.entity_id like 'sensor.%power%' group by 1 order by 2 desc\").fetchall())"

docker run --rm \
  -v /home/smart/plug-gateway/data:/data \
  -v /home/smart/ha-config:/harec:ro \
  plug-gateway:latest \
  python scripts/mine_recorder.py --recorder /harec/home-assistant_v2.db \
    --gateway-db /data/plug_gateway.db --days 90 \
    --entity sensor.<plug>_power   # repeat per plug, or rely on configured DeviceConfigs
```

**Train + load:** as an admin, `POST /admin/ml/retrain` (trains on synthetic + the
plugs' own telemetry, hot-loads). Or off the box:
```bash
docker exec plug-gateway python -c "from app.config import get_settings; \
from app.db import make_engine; from app.ml import dataset, train; \
s=get_settings(); e=make_engine(s.db_path); rs,rn=dataset.build_real_training_data(e); \
print(train.train(s.ml_models_dir, real_samples=rs, real_normals=rn))" && docker restart plug-gateway
```
Models live in `/data/models` and survive container recreation. Set `TARIFF_PER_KWH`
in `gateway.env` so cost diagnosis matches the app.

## Keeping production in sync (run on EVERY gateway change)

The public gateway (`https://gateway.danfordchris.dev`, via the Cloudflare Tunnel
`cloudflared` container) is served by the `plug-gateway` container on the Pi
(compose project `gateway`). Whenever anything under `services/plug-gateway/`
changes, redeploy so production matches the repo:

```bash
deploy/gateway/deploy-pi.sh
```

What it does (no sudo needed — the `smart` user is in the `docker` group; the Pi's
repo copy is root-owned, so we never write into it):

1. runs the gateway test suite locally (aborts on failure),
2. `rsync`s `services/plug-gateway/` to a user-owned staging dir on the Pi,
3. `docker build -t plug-gateway:latest` from that staging copy,
4. recreates the container via this compose file with `--no-build` (so the
   root-owned `gateway.env` secrets are reused untouched),
5. health-checks the Pi and the public domain, asserting `/schedules → 401`
   (route live = new code is running).

Override the host with `PI_HOST=smart@<ip> deploy/gateway/deploy-pi.sh`.

> `deploy/gateway/sync-gateway.sh` is the equivalent for a **local dev** gateway
> (uvicorn on this machine's `:8099`); it does not touch production.

## Exposure (LAN / VPN only — required)

Per `docs/design/architecture/security-and-recovery.md`, the deployment is **LAN-only,
VPN-first, no public port-forwarding**. The compose uses host networking (so the gateway
can reach HA at `localhost:8123`), which publishes port **8099 on all interfaces**.
You MUST restrict it with the host firewall, e.g. allow only the LAN and the Tailscale
interface:

```bash
sudo ufw allow in on tailscale0 to any port 8099 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 8099 proto tcp
sudo ufw deny 8099/tcp
```

Do **not** add a router port-forward for 8099. Remote access is via Tailscale only —
the app reaches the gateway at `http://100.83.45.15:8099`.

## Point the app at the gateway

In the Flutter app, the default gateway URL is `http://100.83.45.15:8099`
(`AppConstants.gatewayDefaultUrl`). Users sign up / log in there; the app no longer needs
the HA token.
