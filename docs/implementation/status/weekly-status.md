# Weekly Status

## 2026-05-21

- Current milestone: Phase 4 — dashboards, alerts, automations
- Complete:
  - Companion mobile app `smart_power` built and design-verified (5 screens, HugeIcons, JSX parity)
  - HA automations authored in `deploy/ha/automations.yaml` (push channel):
    - outage alert + recovery notice (both plugs)
    - high-load alert at 1200 W
    - radio idle standby notice (notify-only, with "turn off" action button)
    - fridge anomaly (notify-only — power near zero for 2h)
    - scheduled radio off 23:00 / on 07:00
  - Deployment + app-wiring guide in `deploy/ha/README.md`
- Operator decisions (2026-05-21):
  - notification channel: HA Mobile App push only
  - high-load threshold: 1200 W
  - idle: notify-only, never auto-off
  - schedule: radio off 23:00, on 07:00
  - safety: fridge never auto-switched off
- Next operator action: install Companion app, deploy `automations.yaml` to
  `/home/smart/ha-config/`, replace notify service name, reload automations;
  generate a long-lived token and wire it into the `smart_power` app
- Pending: end-to-end app test against live plugs over Tailscale

## 2026-05-20

- Current milestone: **Phases 1–3 COMPLETE** — moving to Phase 4 (dashboards & alerts)
- Complete:
  - Phase 1: Raspberry Pi host baseline (Docker, locale, time sync, SSH hardening, UFW firewall, Tailscale VPN)
  - Phase 2: Home Assistant Container deployed with persistent storage at `/home/smart/ha-config`
  - Phase 3: SonOFF onboarding + SonoffLAN integration in `auto` mode
- Remote access: Tailscale VPN established (Pi tailscale IP: `100.83.45.15`); SSH works from any network
- Devices onboarded: **2× SonOFF S60TPG** (originally scoped as 1; design already permits expansion)
  - `10024a097a` @ `192.168.1.22` — actively loaded (1047 W observed)
  - `10024a0989` @ `192.168.1.24` — idle
- Decision gate result: **STOCK FIRMWARE PASSES**
  - Local control confirmed (`Local3/Local4` packets, no cloud-only dependency)
  - Telemetry updates every ~5 seconds (power, voltage, current, kWh)
  - Voltage ~223 V, RSSI -35 to -47 dBm (excellent Wi-Fi)
- Next operator action: build initial dashboard, configure availability alerts, define first automations
- Pending validation: WAN-disconnect test for full local-first confirmation (optional/recommended)

## 2026-05-19

- Current milestone: Phase 0 project-definition patch
- Complete: workflow bootstrap structure and repo routing are in place
- Blocked: no runtime implementation work should begin until the design layer is accepted
- Next operator action: review the new design docs and confirm they represent the intended production direction
- Current decision gate: stock SonOFF firmware remains the default starting path, pending local-control and telemetry validation
