# Auth Gateway And Multi-User Access

## Status

proposed

## Context

- Today the Flutter app (`apps/smart_power`) connects directly to Home Assistant on the Pi using a single long-lived token, at one point even bundled into the app.
- `docs/design/architecture/security-and-recovery.md` scopes the first release as single-operator and states multi-user is not in scope ("no shared credentials if more users are added later").
- The operator now wants multiple people to use the app, each signing up and logging in, without handing every device the Pi's real Home Assistant credentials.
- A new companion service, `services/plug-gateway/` (FastAPI + SQLite), has been built to broker access. This proposal records the behavior change so it can be reviewed before being folded into design truth.

## Problem

- Distributing one shared Home Assistant token to every app install means the Pi's real credential lives on every device, cannot be revoked per person, and grants more than the app needs.
- There is no concept of user accounts, approval, or per-user revocation in the current design.
- Adding accounts is net-new behavior that crosses the documented v1 single-operator boundary, so it must be resolved here rather than asserted in implementation docs.

## Proposed Change

- Introduce an auth gateway that sits between the app and Home Assistant:
  - Users sign up and log in to the gateway; it issues each user a short-lived per-user JWT plus a refresh token.
  - The app calls the gateway using the same `/api/...` shape it already uses; the gateway forwards to Home Assistant injecting one HA long-lived token held only server-side. The Pi token is never sent to clients.
  - Writes are restricted to `switch.turn_on` / `turn_off` / `toggle` (least privilege).
- Account model: the first account becomes an active admin; later signups are `pending` until an admin approves them, or `active` immediately when they present a valid invite code. Admins can list, approve, and disable users; disabling revokes that user's sessions.
- Exposure stays LAN-first and VPN-first per the security design: the gateway is reachable over the LAN and Tailscale only (`http://100.83.45.15:8099`), never via public port-forwarding. The HA token and JWT secret are environment-provided and never committed.
- App impact: the connect screen becomes sign up / log in; the bundled/manual HA token path for normal users is removed. The existing live-data, control loop, and demo behaviors are unchanged — only the base URL and bearer token source change.
- Deviation acknowledged: this intentionally extends the documented single-operator v1 boundary to a small approved set of users. On acceptance, fold the multi-user access model and the gateway into `docs/design/architecture/` and add an execution doc under `docs/implementation/`.

## Acceptance Criteria

- First signup yields an active admin; subsequent signups are pending until approved (or invited).
- Login returns per-user tokens; pending/disabled accounts are refused with a clear reason.
- All `/api/*` access requires a valid token; the gateway forwards to HA with the server-side token and the client JWT is never sent upstream.
- Only whitelisted `switch` services are proxied; other domains/services are rejected.
- The Home Assistant token and JWT secret are supplied via environment and absent from the repo; the service is not publicly exposed.
