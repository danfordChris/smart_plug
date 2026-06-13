# Server-Side Plug Scheduling And Device Configuration

> Update: the items previously listed under "Out Of Scope (Phase 2)" are now
> implemented — rename/type overrides, idle auto-off, and an in-app alerts feed
> with on-device notifications. See the new sections below. True closed-app push
> (FCM/APNs) remains the only deferred piece.


## Status

proposed

## Context

- The detail screen's "Device configuration" gear was an honest placeholder (`AppSnack.comingSoon`).
- The operator wants users to schedule a plug to turn on/off automatically, plus a home for further per-device configuration (rename/type, idle auto-off, alerts).
- Scheduling must fire even when the user's phone is off or the app is closed, so it cannot run on the device — it must run on the gateway alongside the existing auth/proxy service (`services/plug-gateway/`).

## Problem

- A phone-local timer cannot guarantee a plug switches at the scheduled time (app killed, phone off, no network). The action has to be owned by an always-on server.
- There is no per-user store of scheduled actions, and no executor to fire them.
- Adding recurring automation is net-new behavior beyond the documented control/telemetry scope, so it is recorded here before being folded into design truth.

## Proposed Change

- **Gateway (`services/plug-gateway/`)**
  - New `Schedule` table: `entity_id`, `action` (`on`/`off`), `time_hhmm` (local 24h), `days` (CSV of weekday ints Mon=0..Sun=6; empty = every day), `enabled`, `label`, `created_by`, `created_at`.
  - New `/schedules` CRUD router (auth-protected). Users only see and modify their own schedules; `entity_id` is constrained to `switch.*`.
  - A background asyncio loop (`app/scheduler.py`) started in the app lifespan checks each minute and fires due schedules by calling the existing HA proxy path (`switch.turn_on`/`turn_off`) with the server-side token. Times are interpreted in a configurable timezone (`Africa/Dar_es_Salaam` by default; `tzdata` bundled for the slim image).
  - Least-privilege is preserved: the executor only ever issues the already-whitelisted `switch` services.
- **App (`apps/smart_power/`)**
  - The detail-screen gear opens a new `DeviceConfigScreen` instead of a snackbar.
  - The screen lists a plug's schedules and supports add/edit/delete/enable via `schedule_api.dart` (same base URL + bearer + 401-refresh pattern as `ha_api.dart`).
  - A "More configuration" section surfaces the next-phase items (rename/icon, auto-off when idle, alerts) as explicit "Soon" rows rather than hidden gaps.
- **Deviation acknowledged**: recurring server-side automation extends the original single-site control/telemetry scope. On acceptance, fold scheduling into `docs/design/` and add an execution doc under `docs/implementation/`.

## Acceptance Criteria

- A signed-in user can create an on/off schedule for one of their plugs; it persists and lists under that plug only.
- The gateway fires a due schedule within its minute window even with no app connected, issuing only whitelisted `switch` services.
- Schedules are per-user: one user cannot read, edit, or delete another user's schedules (404).
- Invalid input is rejected (bad time, non-`switch` entity, action other than on/off, weekday outside 0–6).
- Disabling a schedule stops it from firing without deleting it.
- The detail-screen gear opens Device configuration; Phase-2 items are visibly marked as upcoming, not silently missing.

## Out Of Scope (Phase 2)

- Rename / appliance-type editing from the app.
- Idle auto-off (excluding critical loads — fridge, water heater).
- Push notifications / alerts (requires Firebase/APNs setup).
