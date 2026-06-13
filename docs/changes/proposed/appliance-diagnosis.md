# Appliance Diagnosis (Classic ML)

## Status

proposed

## Context

- The product shows live telemetry and controls plugs, but offers no interpretation of an
  appliance's behaviour. The operator wants the system to "return responses based on the diagnosis
  and behaviours of the appliances" — a per-plug status plus a plain-language explanation.
- No historical telemetry was being stored and there were no labels, so a model could not be trained
  yet. Confirmed decisions: train a **classic scikit-learn model** (not an LLM), **mine the Home
  Assistant recorder DB** (read-only) for real history, **train and infer on the Pi**, and output
  **both** a structured status label and a templated natural-language explanation.

## Problem

- Diagnosing faults, waste, appliance identity, degradation, and cost anomalies is net-new behaviour
  beyond the documented control/telemetry scope, so it is recorded here before folding into design.
- Training "now" required solving a cold-start data problem (no stored telemetry, no labels).

## Proposed Change

- **Telemetry logging:** a `PlugTelemetry` table fed by the existing monitor loop, plus rollup +
  retention to keep SQLite small on the Pi (`PlugTelemetryRollup`, 7-day raw / 180-day rollup).
- **Cold-start data:** a read-only `scripts/mine_recorder.py` backfills history from the HA recorder
  DB; synthetic per-appliance signatures (`app/ml/synthetic.py`) cover types with no samples; weak
  labels come from `DeviceConfig.appliance_type`.
- **Models (classic, on the Pi):** an appliance-ID classifier (RandomForest), per-type anomaly gates
  (IsolationForest), standby detection (KMeans), and a cost/bill-anomaly baseline (in TSh). An
  evidence-based rule-map names specific faults (stuck-on, no-draw-when-on, spikes, not-heating,
  not-cycling). Output is structured `findings[]` → a templated explanation (no LLM).
- **Serving:** `GET /diagnosis/{entity_id}` returns `{status_label, severity, findings, explanation,
  appliance_guess, confidence, model_version}`. Admin `POST /admin/ml/retrain` / `reload` trains on
  the Pi and hot-loads `/data/models`. A heuristic fallback runs before any model exists, and the
  bundle is refused on scikit-learn version skew.
- **Alerts:** the monitor periodically diagnoses alerts-enabled plugs and raises a new `diagnosis`
  Alert (+ push) when a plug newly reaches warning/critical, reusing the existing alerts path.
- **App:** a Diagnosis card on the detail screen and real, diagnosis-derived Insights recommendations.
- **Deviation acknowledged:** extends the control/telemetry scope with on-device ML and a telemetry
  store. On acceptance, fold into `docs/design/` and add an execution doc under `docs/implementation/`.

## Addendum — Usage filter by period

- `GET /usage?period=day|week|month|year` (and `/usage/{entity_id}`) aggregates the **already-stored**
  telemetry (`PlugTelemetry` raw + `PlugTelemetryRollup`) into kWh + cost buckets — **no new storage**.
  Day → 24 hourly, week → 7 daily, month → ~5 weekly, year → 12 monthly; per-user; `by_entity` breakdown.
- The app gains a Day/Week/Month/Year segmented control (shared provider) driving the Insights chart,
  totals, and "Top appliances {period}" breakdown, and the Dashboard hero.
- Historical buckets are power-integrated estimates (accurate-as-telemetry-accrues; ~90-day recorder
  seed); today/this-month remain authoritative from the plug's HA energy counters.

## Acceptance Criteria

- Telemetry accrues for configured plugs; rollup/retention keeps the DB bounded.
- `GET /diagnosis/{entity}` requires auth; returns a status label + explanation + findings, using the
  trained bundle when present and a clearly-marked heuristic/insufficient-data fallback otherwise.
- Stuck-on, no-draw, not-heating, standby and cost-spike each surface the right finding on fixture
  data (covered by gateway tests).
- A new warning/critical diagnosis raises a `diagnosis` alert without spamming (deduped by severity).
- Recorder mining is read-only; training runs on the Pi via the admin endpoint; model artifacts live
  on the persistent `/data` volume.
- Predictive maintenance is staged for later once longitudinal telemetry exists.
