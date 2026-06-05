# Plug Assistance Gateway

A small FastAPI service that puts **user accounts** in front of the Raspberry Pi's
Home Assistant. The Flutter app logs in here and receives a per-user token; the gateway
forwards plug requests to Home Assistant using a single HA token it holds **server-side**.

```
Flutter app ──(per-user JWT)──▶ plug-gateway ──(server-side HA token)──▶ Home Assistant (Pi)
```

Why: today the app talks to HA directly and would otherwise need the Pi's real long-lived
token on every device. The gateway keeps that token on the server, adds sign-up/login, and
lets an admin approve or revoke individual users.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/signup` | — | Create account. **First account = active admin**; later accounts are `pending` (or `active` with a valid invite code). |
| POST | `/auth/login` | — | Returns `{access_token, refresh_token, expires_in, role}`. `pending`/`disabled` → 403. |
| POST | `/auth/refresh` | — | Rotate refresh token, issue a new access token. |
| POST | `/auth/logout` | — | Revoke a refresh token. |
| GET | `/auth/me` | access JWT | Current user. |
| GET | `/admin/users` | admin | List users + status. |
| POST | `/admin/users/{id}/approve` | admin | Activate a pending user. |
| POST | `/admin/users/{id}/disable` | admin | Disable + revoke their sessions. |
| POST | `/admin/invites` | admin | Mint an invite code (auto-activates signups). |
| GET | `/api/`, `/api/config`, `/api/states`, `/api/states/{id}` | access JWT | Proxied read of HA. |
| POST | `/api/services/{domain}/{service}` | access JWT | Proxied write — **only `switch.turn_on/turn_off/toggle`** (least privilege). |
| GET | `/health` | — | Liveness. |

The `/api/...` paths mirror Home Assistant's REST API exactly, so the app keeps the same
client — only its base URL (the gateway) and bearer token (the user's JWT) change.

## Configuration

All config comes from the environment (see `.env.example`). Key vars:
`HA_BASE_URL`, `HA_TOKEN` (server-side only), `JWT_SECRET` (use `openssl rand -hex 32`),
`ACCESS_TTL_MINUTES`, `REFRESH_TTL_DAYS`, `DB_PATH`.

## Run locally

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env   # fill in HA_TOKEN, JWT_SECRET, point HA_BASE_URL at the Pi
uvicorn app.main:app --reload --port 8099
```

Quick smoke test:

```bash
curl -s localhost:8099/auth/signup -H 'content-type: application/json' \
  -d '{"email":"owner@home.test","password":"ownerpass123"}'
TOK=$(curl -s localhost:8099/auth/login -H 'content-type: application/json' \
  -d '{"email":"owner@home.test","password":"ownerpass123"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s localhost:8099/api/states -H "authorization: Bearer $TOK" | head
```

## Tests

```bash
source .venv/bin/activate
pytest -q
```

The suite mocks Home Assistant with `httpx.MockTransport` and covers signup gating,
login/refresh/logout, admin approval/disable, JWT enforcement, token injection, and the
service whitelist.

## Local development & testing (with the app)

Run the gateway on your dev machine and point the Flutter app at it.

### 1. Start the gateway (bind to all interfaces so a device/emulator can reach it)

```bash
cd services/plug-gateway
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env     # set HA_BASE_URL=http://100.83.45.15:8123, a real HA_TOKEN, and JWT_SECRET
uvicorn app.main:app --host 0.0.0.0 --port 8099
```

> The gateway reaches the Pi over **Tailscale**, so keep Tailscale **up** on the dev
> machine (`tailscale status`). If the Pi is unreachable, proxied `/api/*` calls return
> `502 Upstream Home Assistant unreachable` — auth still works.

### 2. Test account

The **first** account created becomes an active **admin**. For local testing, create:

| Field | Value |
|-------|-------|
| Email | `owner@home.test` |
| Password | `ownerpass123` |

```bash
curl -s localhost:8099/auth/signup -H 'content-type: application/json' \
  -d '{"email":"owner@home.test","password":"ownerpass123"}'
```

Use the same email/password to log in from the app. (Later signups are `pending` until an
admin approves them, or `active` if they present an invite code from `POST /admin/invites`.)

### 3. Point the app at the gateway (per platform)

The Flutter app's default is `AppConstants.gatewayDefaultUrl`. The right host depends on
where the app runs — set it on the login screen's **"Gateway server"** field, or change the
default in `apps/smart_power/lib/config/constants.dart`:

| App runs on | Gateway URL |
|-------------|-------------|
| **iOS Simulator** (same Mac) | `http://127.0.0.1:8099` |
| **Android Emulator** | `http://10.0.2.2:8099` |
| **Physical device** (same Tailnet) | `http://<dev-machine-tailscale-ip>:8099` |
| **Physical device** (same Wi-Fi) | `http://<dev-machine-lan-ip>:8099` |

> **Cleartext HTTP**: the gateway is plain `http://` in dev. The app already allows this —
> iOS via `NSAllowsArbitraryLoads` in `ios/Runner/Info.plist`, Android via
> `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`. These are **dev-only**;
> serve the gateway over HTTPS for production and remove them. Editing `Info.plist`/manifest
> requires a full `flutter run` (not hot reload).

## Deploy

See `deploy/gateway/` for the Docker Compose snippet and the **firewall / exposure**
requirements (LAN + Tailscale only — never public).
