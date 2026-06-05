# Use Smart Power from anywhere

The `smart_power` app talks to your Raspberry Pi at `100.83.45.15` — a
Tailscale-only address. That means **as long as Tailscale is running on the
phone**, the app works from anywhere on Earth: home Wi-Fi, mobile data,
travel, friend's network. No router port-forwarding, no public exposure,
no monthly subscription.

## One-time phone setup (≈2 minutes per phone)

### 1. Install Tailscale

| Phone | Link |
|---|---|
| iPhone / iPad | [App Store — Tailscale](https://apps.apple.com/app/tailscale/id1470499037) |
| Android | [Play Store — Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) |

### 2. Sign in with the household Google account

Open the Tailscale app → tap **Sign in** → choose **Sign in with Google** →
authenticate with the same account used on the Raspberry Pi
(`jurvisdanford329@gmail.com`).

You should now see your "tailnet" with the Pi listed as `smart` and your
phone listed as `<your-device-name>`.

### 3. Turn on the VPN

In the Tailscale app, toggle **Connected** / **VPN On**. iOS shows a small
"VPN" indicator in the status bar; Android shows a key icon. Battery impact
is negligible — Tailscale only carries traffic when the app actively talks
to Pi.

### 4. (Optional) Always-on

- **iOS** → Tailscale → **Settings → Connect on demand** → On
- **Android** → Tailscale → **Settings → Always-on VPN** → On

This means Tailscale wakes up automatically whenever Smart Power needs the
Pi, even after a reboot.

### 5. Open Smart Power

Launch `smart_power` → tap **Sign in with email & password** → log in with
your Plug Assistance credentials on the HA login page that opens. Done.

---

## Verifying it works

In a terminal on the phone? No. But from the Tailscale app you can:

1. Tap the Pi (`smart`) in the device list → tap **Ping** → should respond
   in milliseconds when on the same Wi-Fi, ~50–150 ms on mobile data.
2. In Safari/Chrome on the phone: `http://100.83.45.15:8123` should load
   Plug Assistance.

If both work, Smart Power will work too.

---

## Adding more phones (family members)

Every additional phone follows the same five steps above. The Google sign-in
adds the phone to your tailnet automatically; no admin action needed. Each
phone signs into Plug Assistance separately via OAuth — every login is
recorded under **Settings → People → Users** in HA, with its own
refresh-token entry that you can revoke from HA's UI if a phone is lost.

---

## What if I don't want to install Tailscale on a phone?

Three alternatives, none of them as clean:

1. **Nabu Casa Plug Assistance Cloud** — $6.50/month. Gives HA a permanent
   public HTTPS URL. Change the app URL from `http://100.83.45.15:8123` to
   the Nabu Casa URL and you're done.
2. **Cloudflare Tunnel** — free. Set up a tunnel on the Pi that exposes HA
   on a `*.your-domain` hostname via HTTPS. Requires owning a domain.
3. **Port-forward HA on your router** — *not recommended.* Putting Home
   Assistant directly on the public internet without a Cloudflare/Nabu front
   exposes you to brute-force and CVE drive-bys.

Tailscale stays the recommendation: free, secure-by-default, zero attack
surface.
