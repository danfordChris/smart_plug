# Put the gateway on a public subdomain (Cloudflare Tunnel)

Goal: reach the gateway at `https://gateway.<your-domain>` from anywhere — no VPN, no open
ports. The phone app then uses that URL instead of a local IP.

Prerequisites:
- A domain whose **nameservers point to Cloudflare** (Cloudflare dashboard → *Add a site* →
  set the two NS records at your registrar → wait for **Active**).
- The gateway running on the Pi on `localhost:8099` (see README / docker-compose.snippet.yml).

---

## Recommended: token tunnel (subdomain via the dashboard)

The dashboard manages the subdomain → service mapping **and creates the DNS record for you**.

1. **Cloudflare Zero Trust** dashboard → **Networks → Tunnels → Create a tunnel** → type
   **Cloudflared** → name it `plug-gateway` → **Save**.
2. On the install screen, **copy the token** (the long string after `--token`). Don't run their
   command — we run it via Docker.
3. Add the token to `deploy/gateway/gateway.env` on the Pi:
   ```
   TUNNEL_TOKEN=eyJ...the-long-token...
   ```
4. **Public Hostname** tab → **Add a public hostname**:
   - **Subdomain**: `gateway`   (or `api`, `plugs`, … — your choice)
   - **Domain**: `<your-domain>`
   - **Path**: leave empty
   - **Service**: **Type** `HTTP`, **URL** `localhost:8099`
   - Save. Cloudflare auto‑creates the `gateway.<your-domain>` DNS record (CNAME, proxied).
5. Start it (the `cloudflared` service is already in the compose):
   ```bash
   cd ~/smart_plug
   docker compose -f deploy/gateway/docker-compose.snippet.yml up -d
   docker logs cloudflared --tail 20      # should say "Registered tunnel connection"
   ```
6. Verify from any network (e.g. phone on cellular):
   ```bash
   curl https://gateway.<your-domain>/health   # → {"status":"ok","service":"plug-gateway"}
   ```

To add **more subdomains** later (e.g. `ha.<domain>`), just add another Public Hostname on the
same tunnel.

---

## Alternative: CLI tunnel (config file on the Pi)

If you prefer managing it on the Pi instead of the dashboard:
```bash
# install (Pi is arm64)
curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb

cloudflared tunnel login                              # authorize your domain
cloudflared tunnel create plug-gateway                # creates a creds .json
cloudflared tunnel route dns plug-gateway gateway.<your-domain>   # creates the subdomain DNS
```
`~/.cloudflared/config.yml`:
```yaml
tunnel: plug-gateway
credentials-file: /home/smart/.cloudflared/<TUNNEL-UUID>.json
ingress:
  - hostname: gateway.<your-domain>
    service: http://localhost:8099
  - service: http_status:404
```
Run as a service: `sudo cloudflared service install && sudo systemctl enable --now cloudflared`
(use the CLI method *instead of* the compose `cloudflared` service, not both).

---

## Point the app at the subdomain

The app reads its server URL at build time:
```bash
flutter build appbundle --dart-define=GATEWAY_URL=https://gateway.<your-domain>
flutter build ipa       --dart-define=GATEWAY_URL=https://gateway.<your-domain>
```
Since it's HTTPS now, the dev cleartext exceptions (`NSAllowsArbitraryLoads`,
`usesCleartextTraffic`) can be removed for release builds.

## Security notes
- The tunnel is **outbound‑only** — no inbound ports opened on the router.
- TLS terminates at Cloudflare; keep `8099` bound to localhost/LAN.
- The gateway's login/JWT is the access boundary now that it's publicly reachable.
