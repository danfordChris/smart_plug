# Home Assistant automations — deployment

Automations for the `smart_plug` deployment: outage alerts, high-load alert,
idle/standby notice, fridge anomaly, and the radio schedule. Channel is the
**HA Mobile App push** (operator decision, 2026-05-21).

File: [`automations.yaml`](./automations.yaml)

---

## Prerequisites

1. **Home Assistant Companion app** installed on your phone and signed in to
   `http://100.83.45.15:8123` (via Tailscale). This registers the
   `notify.mobile_app_<device>` service the automations use.
2. The two plugs renamed to `switch.radio` and `switch.fridge` (done in P4.1).

---

## Step 1 — Confirm your entity IDs

The automations assume these entities exist. **Verify first**, because
SonoffLAN sometimes names power sensors differently.

In Home Assistant → **Developer Tools → States**, confirm these exist:

```
switch.radio            switch.fridge
sensor.radio_power      sensor.fridge_power
```

If your power sensors have different IDs (e.g. `sensor.radio_power_2` or a
device-id form), edit `automations.yaml` and replace accordingly.

---

## Step 2 — Find your notify service name

In **Developer Tools → Actions**, search `notify.mobile_app`. You'll see
something like `notify.mobile_app_chris_iphone`.

Replace **every** `notify.mobile_app_phone` in `automations.yaml` with your
real service name:

```bash
# On the Pi, after copying the file (see Step 3):
sed -i 's/notify\.mobile_app_phone/notify.mobile_app_YOURDEVICE/g' \
  /home/smart/ha-config/automations.yaml
```

---

## Step 3 — Deploy to the Pi

From this repo on your laptop (over Tailscale):

```bash
scp deploy/ha/automations.yaml smart@100.83.45.15:/home/smart/ha-config/automations.yaml
```

> If `/home/smart/ha-config/automations.yaml` already exists with automations
> you want to keep, append instead of overwrite — open both and merge.

Make sure `configuration.yaml` includes the automations file (HA's default
config already has `automation: !include automations.yaml`). Verify:

```bash
ssh smart@100.83.45.15 'grep -n "automation:" /home/smart/ha-config/configuration.yaml'
```

If the line is missing, add to `configuration.yaml`:

```yaml
automation: !include automations.yaml
```

---

## Step 4 — Validate and reload

In Home Assistant:

1. **Developer Tools → YAML → Check Configuration** → must say "Configuration
   valid".
2. **Developer Tools → YAML → Reload Automations** (no restart needed).
3. Go to **Settings → Automations & Scenes** — you should see 8 new
   automations prefixed "Smart Plug —".

---

## Step 5 — Test each automation

| Automation | How to test |
|---|---|
| Outage alert | Unplug the radio from Wi-Fi / power. Wait 2 min → push arrives. |
| Recovery notice | Plug it back in → "back online" push. |
| High-load (1200 W) | Plug a >1200 W load (kettle) into a plug, switch on. |
| Radio idle | Hard to force live; trigger manually: Settings → Automations → "radio idle" → ⋮ → Run. |
| Fridge anomaly | Same — use Run to confirm the push fires. |
| Radio off 23:00 | Settings → Automations → "radio off at 23:00" → ⋮ → Run → radio switches off. |
| Radio on 07:00 | ⋮ → Run → radio switches on. |

The idle notification includes a **"Turn off radio"** action button — tapping
it triggers `smart_plug_radio_idle_action`, which switches the radio off.

---

---

## Bonus: pair the app without typing a token

This folder ships `pair-qr.html` — a single static page that generates a
pairing QR code entirely client-side.

1. Generate a long-lived token (Profile → Security → Create Token).
2. Open `deploy/ha/pair-qr.html` on your computer (double-click).
3. Paste your HA URL + the token. Click **Generate QR**.
4. In the Smart Power app → Setup → **Scan pairing QR** → point at the screen.

The QR encodes `{"url":"...","token":"..."}` JSON; the token never leaves
your browser (no upload).

---

## Safety notes

- **Fridge is never auto-switched off.** The idle automation targets the radio
  only; the fridge anomaly automation is notify-only.
- Idle behaviour is **notify-only** per operator decision — no plug is ever
  switched off automatically except the scheduled 23:00 radio rule.
- Thresholds (1200 W, 3 h idle, 2 h fridge) are documented inline in
  `automations.yaml`; adjust there and reload.
