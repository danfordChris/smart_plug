# System Requirements Alignment (F1–F6)

## Status

proposed

## Context

- A stakeholder "System Requirements" document (functional requirements F1–F6) describes a **prepaid
  smart-metering platform** with two roles — **Service Provider** (utility) and **Customer** — built
  around a **smart meter + token/control number + prepaid units** (LUKU/STS-style), appliance power
  profiles, loss computation, SMS, maps, and Excel/PDF reporting.
- The current system is a **single-site smart-plug monitoring & control app**: Flutter app + FastAPI
  gateway (JWT auth) → Home Assistant + SonoffLAN + Sonoff S60TPG plugs, on a Pi behind a Cloudflare
  Tunnel. It already covers control, telemetry, scheduling, diagnosis (ML), usage-by-period, alerts
  (push/in-app), and PDF reports.
- This document records the gap and a phased path so it can be reviewed before folding into
  `docs/design` and `docs/implementation`.

## Problem

The spec introduces behavior absent from current design: a metering/token/prepaid domain, a
service-provider tenant, mobile+OTP auth, appliance consumption profiles, loss analytics, SMS, maps,
and Excel export. These are net-new and must be resolved here before execution.

## Proposed Change

Extend the current plug-control system into the spec's prepaid smart-metering platform, in three
phases, without rebuilding what already works:

- Add a **provider/customer** tenancy and a **`Meter`** domain (control number, units, status, geo),
  with **mobile-number + OTP** auth and **token-gated** hardware connection.
- Add a **prepaid units ledger** (token redemption + consumption decrement), **appliance consumption
  profiles** (expected D/M/Y, life span, tolerance), a **loss** metric (actual − expected), and an
  **SMS** channel (manual/automated; low-units < 10).
- Add **provider tooling** (all-meters dashboard + **Google Maps**), **losses reporting**, **Excel +
  PDF** export with a format selector, **document upload/download**, and an **online user manual**.

Reuse: existing auth/JWT, plug control, telemetry logging, scheduling, diagnosis ML, usage-by-period,
PDF generators, alerts/push. Full requirement→phase mapping in the table and "Phased Plan" below.

## Open Decision (blocking Phase B scope)

- **Prepaid token engine: real vs simulated.** Default assumption for the pilot: a **simulated** units
  ledger in the gateway (token generated/redeemed internally), with a clean adapter seam to swap in a
  real STS/vendor token API later. Confirm before Phase B.

---

## Gap Traceability (requirement → status → update)

Legend: ✅ done · 🟡 partial · ❌ missing

| Req | Requirement (abridged) | Status | Update needed |
|-----|------------------------|--------|---------------|
| F1.1 | Provider admin registers smart meter to customer account | ❌ | Provider role + `Meter` entity + customer↔meter linkage |
| F1.2 | Meter number (control number) as payment token | ❌ | Control-number / token model |
| F1.3 | Meter authenticates via meter number | ❌ | Token-based hardware auth |
| F1.4 | Register appliances: expected consumption (D/M/Y), life span, tolerance | ❌ | Extend appliance model + UI |
| F1.5 | Auto-detect new smart plug | 🟡 | SonoffLAN plug-and-play exists; add explicit "new device" surfacing |
| F1.6 | Evaluate data to show power **losses** | 🟡 | Diagnosis exists; add formal loss = expected − actual |
| F1.7 | Remote automation/control | ✅ | — |
| F1.8 | Scheduling + timer control | ✅ | — |
| F1.9 | Show ON/OFF status + control button on issues | ✅ | — |
| F2.1 | Provider login via **mobile number** + password | 🟡 | Email today → add mobile-number identity |
| F2.2 | Provider registers customers | 🟡 | Admin approve today → provider-driven registration |
| F2.3 | Force password change on first login + **OTP** | ❌ | OTP + forced reset |
| F2.4 | Change password anytime + 2-way auth | ❌ | Change-password + 2FA |
| F2.4b | Provider views all meters + connected devices | 🟡 | Admin sees one site → all-meters view |
| F2.5 | Lock token/control number from non-admins | ❌ | Field-level permission on token |
| F2.6 | Provider views per-meter + overall usage | 🟡 | Usage exists; scope to meters |
| F2.7 | **Google Maps** geolocation per meter | ❌ | Lat/long + provider map |
| F2.8 | Provider reports: usage, **losses**, total vs losses; print D/W/M | 🟡 | Have usage+PDF; add losses + print scopes |
| F2.9 | Download reports as **EXCEL or PDF** | 🟡 | PDF only → add Excel |
| F2.10 | Send manual/automated **SMS** | ❌ | SMS provider integration |
| F2.11 | Download payment receipts | ✅ | Receipt PDF generator exists |
| F2.12 | Provider remote ON/OFF of the meter | 🟡 | Plug control exists; scope to meter |
| F2.13 | Show available **units**, alert when < 10 | ❌ | Units balance + low-balance alert |
| F3.1 | Customer login (username+password) | ✅ | — |
| F3.2 | Rename smart plug to appliance | ✅ | — |
| F3.3 | Register appliance profiles (as F1.4) | ❌ | Same as F1.4 |
| F3.4 | Energy/power graph (clustered column) | 🟡 | Bar/sparkline exist; align to clustered column |
| F3.5 | Show ON/OFF status | ✅ | — |
| F3.6 | Alert when usage higher than expected (**ML**) | 🟡 | Diagnosis vs own baseline → vs user-entered expected |
| F3.7 | Remote control from anywhere | ✅ | — |
| F3.8 | Customer reports: usage, losses; print D/W/M | 🟡 | Add losses |
| F3.9 | Download EXCEL or PDF via dropdown | 🟡 | Add Excel + format dropdown |
| F3.9b | Upload/download service documents | ❌ | Document store |
| F3.10 | Scheduling + timer | ✅ | — |
| F4.1 | Online user manual | ❌ | Help screen |
| F5.1 | Auto-connect hardware after token | ❌ | Token-gated connection |
| F5.2 | Show meter connection status (online/offline) | 🟡 | Plug online/offline exists; scope to meter |
| F5.3 | Sync hardware data on interval | ✅ | Monitor/poll loop |
| F6.1 | View/update profile | 🟡 | View only → add edit |
| F6.2-6.4 | Login / logout / authenticate | ✅ | — |
| F6.5 | Authenticate hardware via token | ❌ | Token auth |
| F6.6 | View appliance-data reports | ✅ | — |

---

## Requirements Model (as specified in the document)

Actors and functional groups exactly as written in the System Requirements (F1–F6) — the system the
document describes, before any implementation decisions.

```mermaid
graph LR
  SP(["Service Provider Admin"])
  CU(["Customer"])
  HW(["Smart Meter / Plug (hardware)"])

  F1["F1 Management of Devices<br/>F1.1 Register meter to customer<br/>F1.2 Meter number as payment token<br/>F1.3 Meter authenticates by number<br/>F1.4 Appliance profiles: expected D/M/Y, life span, tolerance<br/>F1.5 Auto-detect new plug<br/>F1.6 Evaluate power losses<br/>F1.7 Remote control<br/>F1.8 Schedule and timer<br/>F1.9 Show status and control button"]
  F2["F2 Service Provider<br/>F2.1 Login by mobile number<br/>F2.2 Register customers<br/>F2.3 First-login password change + OTP<br/>F2.4 Change password + 2-way auth<br/>F2.4b View all meters and devices<br/>F2.5 Lock token from non-admins<br/>F2.6 View per-meter and overall usage<br/>F2.7 Map: locate meters and losses<br/>F2.8 Reports: usage, losses, total vs losses<br/>F2.9 Download EXCEL or PDF<br/>F2.10 Send manual/automated SMS<br/>F2.11 Download payment receipts<br/>F2.12 Remote ON/OFF meter<br/>F2.13 Show units and alert below 10"]
  F3["F3 Customer<br/>F3.1 Login<br/>F3.2 Rename smart plug<br/>F3.3 Register appliance profiles<br/>F3.4 Power/time clustered-column graph<br/>F3.5 Show ON/OFF status<br/>F3.6 Alert when usage above expected (ML)<br/>F3.7 Remote control anywhere<br/>F3.8 Reports: usage, losses, print D/W/M<br/>F3.9 Download EXCEL or PDF (dropdown)<br/>F3.9b Upload/download service documents<br/>F3.10 Schedule and timer"]
  F4["F4 IoT Learning<br/>F4.1 Online user manual"]
  F5["F5 Hardware Connection<br/>F5.1 Auto-connect after token<br/>F5.2 Meter connection status<br/>F5.3 Sync data on interval"]
  F6["F6 General<br/>F6.1 View/update profile<br/>F6.2 Login<br/>F6.3 Logout<br/>F6.4 Authenticate users<br/>F6.5 Authenticate hardware by token<br/>F6.6 View appliance-data reports"]

  SP --> F1
  SP --> F2
  SP --> F5
  SP --> F6
  CU --> F1
  CU --> F3
  CU --> F4
  CU --> F6
  HW --> F1
  HW --> F5
  HW --> F6
```

Full functional decomposition (mind map of every requirement, verbatim grouping):

```mermaid
mindmap
  root((Smart Metering System))
    F1 Management of Devices
      F1.1 Register meter to customer
      F1.2 Meter number as token
      F1.3 Meter authenticates by number
      F1.4 Appliance profiles D/M/Y, life span, tolerance
      F1.5 Auto-detect new plug
      F1.6 Evaluate power losses
      F1.7 Remote control
      F1.8 Schedule and timer
      F1.9 Status and control button
    F2 Service Provider
      F2.1 Login by mobile number
      F2.2 Register customers
      F2.3 First-login change + OTP
      F2.4 Change password + 2-way auth
      F2.4b View all meters and devices
      F2.5 Lock token from non-admins
      F2.6 Per-meter and overall usage
      F2.7 Map locate meters
      F2.8 Reports usage and losses
      F2.9 Download EXCEL or PDF
      F2.10 Send SMS
      F2.11 Download receipts
      F2.12 Remote ON/OFF meter
      F2.13 Units and low alert below 10
    F3 Customer
      F3.1 Login
      F3.2 Rename plug
      F3.3 Register appliance profiles
      F3.4 Power-time clustered column
      F3.5 ON/OFF status
      F3.6 Alert above expected ML
      F3.7 Remote control anywhere
      F3.8 Reports and print D/W/M
      F3.9 Download EXCEL or PDF dropdown
      F3.9b Upload/download documents
      F3.10 Schedule and timer
    F4 IoT Learning
      F4.1 Online user manual
    F5 Hardware Connection
      F5.1 Auto-connect after token
      F5.2 Connection status
      F5.3 Sync on interval
    F6 General
      F6.1 View/update profile
      F6.2 Login
      F6.3 Logout
      F6.4 Authenticate users
      F6.5 Authenticate hardware by token
      F6.6 View appliance reports
```

## Target Architecture

```mermaid
graph TD
  subgraph Clients
    CA["Customer App (Flutter)"]
    SP["Provider Console (Flutter / web)"]
  end
  subgraph Edge
    CF["Cloudflare Tunnel (HTTPS)"]
  end
  subgraph Pi["Raspberry Pi"]
    GW["Gateway (FastAPI)"]
    HA["Home Assistant + SonoffLAN"]
    DB[("SQLite: users, meters, tokens,\nappliances, telemetry, losses, alerts")]
  end
  EXT_SMS["SMS provider (TZ gateway)"]
  EXT_MAP["Google Maps"]
  EXT_FCM["FCM / APNs"]
  PLUG["Sonoff S60TPG plugs"]

  CA --> CF --> GW
  SP --> CF
  GW --> HA --> PLUG
  GW --> DB
  GW --> EXT_SMS
  GW --> EXT_FCM
  SP --> EXT_MAP
  GW -. token auth .-> PLUG
```

**New vs current:** the Provider Console, `Meter`/token/units tables, SMS + Maps integrations, and
token-gated hardware auth are additions. The plug/HA/telemetry path is reused.

## Domain Model (target)

```mermaid
erDiagram
  SERVICE_PROVIDER ||--o{ CUSTOMER : registers
  CUSTOMER ||--o{ METER : owns
  METER ||--o{ APPLIANCE : monitors
  METER ||--o{ TOKEN : "redeems"
  METER ||--|| UNIT_BALANCE : has
  APPLIANCE ||--o{ TELEMETRY : produces
  APPLIANCE ||--o{ LOSS : computes
  METER ||--o{ ALERT : raises
  CUSTOMER ||--o{ REPORT : downloads
  CUSTOMER ||--o{ DOCUMENT : "uploads/downloads"

  METER {
    string control_number PK
    float  unit_balance
    string status
    float  lat
    float  lng
    int    customer_id FK
  }
  APPLIANCE {
    string entity_id PK
    string name
    string type
    float  expected_daily_kwh
    float  expected_monthly_kwh
    float  expected_yearly_kwh
    int    life_span_months
    float  tolerance_pct
  }
  TOKEN {
    string code PK
    float  units
    string status
    datetime redeemed_at
  }
  LOSS {
    datetime period
    float expected_kwh
    float actual_kwh
    float loss_kwh
  }
```

## Key Flows

### 1. Meter registration + first login (F1.1, F2.2, F2.3)

```mermaid
sequenceDiagram
  actor SP as Provider Admin
  participant GW as Gateway
  participant SMS as SMS Provider
  actor C as Customer
  SP->>GW: register customer (mobile no.) + meter (control number)
  GW->>GW: create Customer + Meter, link, temp password
  GW->>SMS: send credentials / OTP
  SMS-->>C: SMS (OTP + temp password)
  C->>GW: first login (mobile + temp pw)
  GW-->>C: require OTP + password change
  C->>GW: OTP + new password
  GW-->>C: session (JWT)
```

### 2. Prepaid token → units → low-balance alert (F1.2, F2.13)

```mermaid
sequenceDiagram
  actor C as Customer
  participant GW as Gateway
  participant M as Meter
  participant SMS as SMS Provider
  C->>GW: buy units (amount) [pilot: simulated]
  GW->>GW: generate TOKEN(code, units), receipt
  C->>GW: redeem TOKEN on meter
  GW->>M: unit_balance += units
  loop monitor interval
    GW->>M: unit_balance -= consumption (kWh→units)
    alt balance < 10
      GW->>SMS: low-units alert
      SMS-->>C: "Units low (<10)"
    end
  end
```

### 3. Loss computation + "higher than expected" alert (F1.6, F3.6, F2.8)

```mermaid
sequenceDiagram
  participant MON as Monitor loop
  participant GW as Gateway
  participant DB as DB
  participant N as Notify (push/SMS)
  MON->>GW: telemetry sample (power, energy)
  GW->>DB: read appliance expected + tolerance
  GW->>GW: actual vs expected; loss = actual - expected
  alt actual > expected*(1+tolerance)
    GW->>N: "usage higher than expected"
  end
  GW->>DB: store LOSS(period, expected, actual, loss)
```

---

## Phased Plan

```mermaid
graph LR
  A["Phase A — Auth & Tenancy"] --> B["Phase B — Prepaid & Alerts"] --> C["Phase C — Reporting & Provider Tools"]
```

- **Phase A — Auth & Tenancy:** mobile-number identity, OTP, forced first-login reset, change-password,
  provider/customer roles, `Meter` entity + customer↔meter linkage, token-gated hardware auth.
  (F1.1, F1.3, F2.1–2.5, F5.1, F6.1, F6.5)
- **Phase B — Prepaid & Alerts:** units balance + token redemption (simulated), consumption decrement,
  low-units (<10) **SMS**, appliance **expected/lifespan/tolerance** profiles, **loss** metric,
  "higher than expected" alerts. (F1.2, F1.4, F1.6, F2.10, F2.13, F3.3, F3.6)
- **Phase C — Reporting & Provider Tools:** **Excel** export + PDF/Excel **format dropdown**, losses
  reports + print D/W/M, provider all-meters dashboard + **Google Maps**, document upload/download,
  online user manual. (F2.6–2.9, F2.12, F3.4, F3.8–3.9b, F4.1)

## Acceptance Criteria

- Every F-requirement maps to a phase with a build/verify step; ✅ items confirmed unchanged.
- Provider can register a meter+customer; customer first login forces OTP + password change.
- A redeemed token increases unit balance; consumption decrements it; < 10 units raises an SMS.
- An appliance with expected/tolerance set raises a "higher than expected" alert and records losses.
- Reports export as both PDF and Excel via a format selector; losses appear per appliance and per meter.
- On acceptance, fold the meter/token/loss domain into `docs/design/` and add execution docs under
  `docs/implementation/phases`.
