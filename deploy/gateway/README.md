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
