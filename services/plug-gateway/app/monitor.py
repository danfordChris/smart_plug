"""Server-side device monitor.

A background loop that, once per interval:
  - fires idle auto-off (turn a plug off after it draws < threshold for N
    minutes) for non-critical loads that opted in, and
  - records offline/online alerts for plugs whose owner enabled alerts.

State (idle-since timestamps, last-known availability) is kept in memory and
resets on restart — acceptable for a best-effort automation. The pure
`auto_off_due` decision is unit-tested in isolation.
"""
import asyncio
from datetime import datetime, timedelta, timezone

from sqlmodel import Session, delete, select

from . import push
from .events import CRITICAL_TYPES, record_alert
from .models import DeviceConfig, PlugTelemetry, PlugTelemetryRollup


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def auto_off_due(
    *,
    is_on: bool,
    critical: bool,
    enabled: bool,
    power_w,
    threshold_w: float,
    idle_elapsed_min: float,
    idle_minutes: int,
) -> bool:
    """Pure decision: should this plug be turned off right now?"""
    if not enabled or critical or not is_on:
        return False
    if power_w is None:
        return False
    if power_w >= threshold_w:
        return False
    return idle_elapsed_min >= idle_minutes


def _to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


async def _states_by_id(client) -> dict:
    try:
        resp = await client.get("/api/states")
        data = resp.json()
    except Exception:
        return {}
    out = {}
    if isinstance(data, list):
        for s in data:
            if isinstance(s, dict) and "entity_id" in s:
                out[s["entity_id"]] = s
    return out


async def _turn_off(client, entity_id: str) -> bool:
    try:
        await client.post("/api/services/switch/turn_off", json={"entity_id": entity_id})
        return True
    except Exception:
        return False


async def _tick(app, idle_since: dict, last_online: dict) -> None:
    engine = app.state.engine
    client = getattr(app.state, "ha_client", None)
    if client is None:
        return

    with Session(engine) as session:
        configs = session.exec(
            select(DeviceConfig).where(
                (DeviceConfig.auto_off_enabled == True)  # noqa: E712
                | (DeviceConfig.alerts_enabled == True)  # noqa: E712
            )
        ).all()
    if not configs:
        return

    states = await _states_by_id(client)
    now = _utcnow()

    _log_telemetry(engine, configs, states, now)

    for cfg in configs:
        sw = states.get(cfg.entity_id)
        sw_state = (sw or {}).get("state")
        is_on = sw_state == "on"
        is_unavailable = sw is None or sw_state in ("unavailable", "unknown")
        key = (cfg.created_by, cfg.entity_id)

        # ── Offline/online alerts (transition-triggered) ──────────────────
        if cfg.alerts_enabled:
            online = not is_unavailable
            prev = last_online.get(key)
            if prev is not None and prev != online:
                if online:
                    msg = f"{_label(cfg)} is back online."
                    record_alert(engine, cfg.created_by, "online", msg, cfg.entity_id)
                    await push.notify(app, cfg.created_by, "Plug back online", msg)
                else:
                    msg = f"{_label(cfg)} went offline."
                    record_alert(engine, cfg.created_by, "offline", msg, cfg.entity_id)
                    await push.notify(app, cfg.created_by, "Plug offline", msg)
            last_online[key] = online

        # ── Idle auto-off ─────────────────────────────────────────────────
        critical = cfg.appliance_type in CRITICAL_TYPES
        if not cfg.auto_off_enabled or critical:
            idle_since.pop(key, None)
            continue

        power = None
        if cfg.power_entity_id:
            power = _to_float((states.get(cfg.power_entity_id) or {}).get("state"))

        if not is_on or power is None or power >= cfg.auto_off_threshold_w:
            idle_since.pop(key, None)
            continue

        # Below threshold while on → accumulate idle time.
        started = idle_since.setdefault(key, now)
        idle_elapsed_min = (now - started).total_seconds() / 60.0
        if auto_off_due(
            is_on=is_on,
            critical=critical,
            enabled=cfg.auto_off_enabled,
            power_w=power,
            threshold_w=cfg.auto_off_threshold_w,
            idle_elapsed_min=idle_elapsed_min,
            idle_minutes=cfg.auto_off_idle_minutes,
        ):
            if await _turn_off(client, cfg.entity_id):
                msg = (
                    f"Turned off {_label(cfg)} after "
                    f"{cfg.auto_off_idle_minutes} min idle."
                )
                record_alert(engine, cfg.created_by, "auto_off", msg, cfg.entity_id)
                await push.notify(app, cfg.created_by, "Auto-off", msg)
            idle_since.pop(key, None)


def _log_telemetry(engine, configs, states: dict, now: datetime) -> None:
    """Insert one telemetry row per monitored plug. Best-effort: a logging
    failure must never break the control/alert path."""
    try:
        rows = []
        for cfg in configs:
            sw = states.get(cfg.entity_id) or {}
            power = None
            if cfg.power_entity_id:
                power = _to_float((states.get(cfg.power_entity_id) or {}).get("state"))
            rows.append(
                PlugTelemetry(
                    user_id=cfg.created_by,
                    entity_id=cfg.entity_id,
                    power_w=power,
                    state=sw.get("state", "") or "",
                    recorded_at=now,
                )
            )
        if rows:
            with Session(engine) as session:
                session.add_all(rows)
                session.commit()
    except Exception:
        pass


def _floor_bucket(dt: datetime, minutes: int) -> datetime:
    minutes = max(1, minutes)
    discard = dt.minute % minutes
    return dt.replace(minute=dt.minute - discard, second=0, microsecond=0)


def maintain_telemetry(engine, settings, now: datetime) -> None:
    """Roll raw telemetry older than the retention window into N-minute buckets,
    delete the consumed raw rows, and prune ancient rollups. Pure-ish; called
    periodically from run_monitor and directly in tests."""
    raw_cutoff = now - timedelta(days=settings.telemetry_retention_days)
    rollup_cutoff = now - timedelta(days=settings.rollup_retention_days)
    minutes = settings.rollup_minutes

    with Session(engine) as session:
        old = session.exec(
            select(PlugTelemetry).where(PlugTelemetry.recorded_at < raw_cutoff)
        ).all()
        # Aggregate into (user, entity, bucket).
        buckets: dict = {}
        for r in old:
            key = (r.user_id, r.entity_id, _floor_bucket(r.recorded_at, minutes))
            b = buckets.setdefault(
                key, {"powers": [], "energy": None, "on": 0, "n": 0}
            )
            if r.power_w is not None:
                b["powers"].append(r.power_w)
            if r.energy_today is not None:
                b["energy"] = r.energy_today
            if r.state == "on":
                b["on"] += 1
            b["n"] += 1

        for (uid, eid, bstart), b in buckets.items():
            powers = b["powers"]
            session.add(
                PlugTelemetryRollup(
                    user_id=uid,
                    entity_id=eid,
                    bucket_start=bstart,
                    power_mean=(sum(powers) / len(powers)) if powers else None,
                    power_min=min(powers) if powers else None,
                    power_max=max(powers) if powers else None,
                    energy_today=b["energy"],
                    on_fraction=(b["on"] / b["n"]) if b["n"] else None,
                    samples=b["n"],
                )
            )
        if old:
            session.exec(
                delete(PlugTelemetry).where(PlugTelemetry.recorded_at < raw_cutoff)
            )
        session.exec(
            delete(PlugTelemetryRollup).where(
                PlugTelemetryRollup.bucket_start < rollup_cutoff
            )
        )
        session.commit()


async def _diagnosis_pass(app, last_diag: dict) -> None:
    """Run diagnosis for alerts-enabled plugs; raise an Alert + push when a plug
    newly reaches a warning/critical state (deduped by last severity in memory)."""
    from .ml import service  # local import keeps sklearn out of the hot path import

    engine = app.state.engine
    settings = app.state.settings
    bundle = getattr(app.state, "ml_bundle", None)
    with Session(engine) as session:
        configs = session.exec(
            select(DeviceConfig).where(DeviceConfig.alerts_enabled == True)  # noqa: E712
        ).all()
    for cfg in configs:
        try:
            result = service.diagnose_entity(
                engine, settings, bundle, cfg.entity_id,
                cfg.appliance_type, cfg.display_name,
            )
        except Exception:
            continue
        sev = result.get("severity", "ok")
        key = (cfg.created_by, cfg.entity_id)
        if sev in ("warning", "critical") and last_diag.get(key) != sev:
            msg = result.get("explanation", "")
            record_alert(engine, cfg.created_by, "diagnosis", msg, cfg.entity_id)
            await push.notify(app, cfg.created_by, "Appliance diagnosis", msg)
        last_diag[key] = sev


def _label(cfg: DeviceConfig) -> str:
    if cfg.display_name:
        return cfg.display_name
    base = cfg.entity_id.split(".", 1)[-1]
    return base or cfg.entity_id


async def run_monitor(app) -> None:
    settings = app.state.settings
    interval = getattr(settings, "monitor_seconds", 30)
    idle_since: dict = {}
    last_online: dict = {}
    last_diag: dict = {}
    last_maintenance = _utcnow()
    last_diagnosis = _utcnow()
    diag_every = timedelta(minutes=getattr(settings, "diagnosis_minutes", 15))
    while True:
        try:
            await _tick(app, idle_since, last_online)
        except Exception:
            pass
        now = _utcnow()
        # Periodic diagnosis → fault alerts.
        if (now - last_diagnosis) >= diag_every:
            last_diagnosis = now
            try:
                await _diagnosis_pass(app, last_diag)
            except Exception:
                pass
        # Roll up / prune telemetry hourly so SQLite stays small on the Pi.
        if (now - last_maintenance) >= timedelta(hours=1):
            last_maintenance = now
            try:
                maintain_telemetry(app.state.engine, settings, now)
            except Exception:
                pass
        await asyncio.sleep(interval)
