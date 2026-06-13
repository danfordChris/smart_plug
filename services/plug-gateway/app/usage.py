"""Usage aggregation: turn logged power telemetry into kWh + cost buckets for a
period (day / week / month / year). Reads existing rows only — raw
`PlugTelemetry` for recent windows and `PlugTelemetryRollup` for older ones — so
no new storage is needed.

kWh is integrated from power samples (trapezoidal, with a gap cap so missing
stretches don't inflate a bucket), which is robust to the irregular cadence of
mined recorder data.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlmodel import Session, select

from .models import PlugTelemetry, PlugTelemetryRollup

PERIODS = ("day", "week", "month", "year")


def integrate_kwh(samples, cap_seconds: float) -> float:
    """Trapezoidal energy (kWh) over [(datetime, power_w), ...] sorted by time.
    Δt between consecutive samples is capped at `cap_seconds` so gaps in logging
    don't over-count."""
    total_wh = 0.0
    prev_t = None
    prev_p = None
    for t, p in samples:
        if p is None:
            prev_t, prev_p = t, p
            continue
        if prev_t is not None and prev_p is not None:
            dt = (t - prev_t).total_seconds()
            if 0 < dt <= cap_seconds:
                total_wh += (prev_p + p) / 2.0 * (dt / 3600.0)
        prev_t, prev_p = t, p
    return total_wh / 1000.0


def _period_bounds(period: str, now_local: datetime):
    """Return (start_local, bucket_edges, labels). bucket_edges has len(buckets)+1
    local datetimes; buckets[i] spans [edges[i], edges[i+1])."""
    if period == "day":
        start = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        edges = [start + timedelta(hours=h) for h in range(25)]
        labels = [f"{h:02d}" for h in range(24)]
    elif period == "week":
        start = (now_local - timedelta(days=6)).replace(hour=0, minute=0, second=0, microsecond=0)
        edges = [start + timedelta(days=d) for d in range(8)]
        labels = [(start + timedelta(days=d)).strftime("%a") for d in range(7)]
    elif period == "month":
        # 5 weekly buckets covering the last 35 days (ending today).
        start = (now_local - timedelta(days=34)).replace(hour=0, minute=0, second=0, microsecond=0)
        edges = [start + timedelta(days=7 * w) for w in range(6)]
        labels = [f"W{w + 1}" for w in range(5)]
    else:  # year → 12 monthly buckets
        first = now_local.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        months = []
        m = first
        for _ in range(12):
            months.append(m)
            # step back one month
            if m.month == 1:
                m = m.replace(year=m.year - 1, month=12)
            else:
                m = m.replace(month=m.month - 1)
        months = list(reversed(months))  # oldest → newest
        edges = months + [_add_month(months[-1])]
        labels = [d.strftime("%b") for d in months]
    return edges, labels


def _add_month(d: datetime) -> datetime:
    if d.month == 12:
        return d.replace(year=d.year + 1, month=1)
    return d.replace(month=d.month + 1)


def _naive_utc_edges(edges_local):
    """Convert tz-aware local edges to naive UTC (telemetry is stored naive UTC)."""
    return [e.astimezone(ZoneInfo("UTC")).replace(tzinfo=None) for e in edges_local]


def usage_series(engine, entity_ids, period: str, now_utc: datetime, tz_name: str,
                 tariff: float, monitor_seconds: int = 30):
    """Build the bucketed usage series + per-entity totals for a set of plugs."""
    if period not in PERIODS:
        period = "week"
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo("UTC")
    now_local = now_utc.replace(tzinfo=ZoneInfo("UTC")).astimezone(tz)

    edges_local, labels = _period_bounds(period, now_local)
    edges = _naive_utc_edges(edges_local)
    n = len(labels)
    cap = max(monitor_seconds * 4, 120)  # generous gap cap for sparse mined data

    win_start, win_end = edges[0], edges[-1]
    bucket_kwh = [0.0] * n
    by_entity: dict[str, float] = {}

    for entity_id in entity_ids:
        with Session(engine) as s:
            rows = s.exec(
                select(PlugTelemetry)
                .where(
                    PlugTelemetry.entity_id == entity_id,
                    PlugTelemetry.recorded_at >= win_start,
                    PlugTelemetry.recorded_at < win_end,
                    PlugTelemetry.power_w.is_not(None),
                )
                .order_by(PlugTelemetry.recorded_at)
            ).all()
            rollups = s.exec(
                select(PlugTelemetryRollup)
                .where(
                    PlugTelemetryRollup.entity_id == entity_id,
                    PlugTelemetryRollup.bucket_start >= win_start,
                    PlugTelemetryRollup.bucket_start < win_end,
                    PlugTelemetryRollup.power_mean.is_not(None),
                )
                .order_by(PlugTelemetryRollup.bucket_start)
            ).all()

        ent_total = 0.0
        # Distribute raw samples into buckets, integrating within each.
        bi = 0
        bucket_samples: list[list] = [[] for _ in range(n)]
        for r in rows:
            while bi < n - 1 and r.recorded_at >= edges[bi + 1]:
                bi += 1
            bucket_samples[bi].append((r.recorded_at, r.power_w))
        for i in range(n):
            kwh = integrate_kwh(bucket_samples[i], cap)
            bucket_kwh[i] += kwh
            ent_total += kwh

        # Rollups (older than raw retention): power_mean × bucket duration.
        roll_minutes = None
        for rr in rollups:
            idx = _bucket_index(edges, rr.bucket_start, n)
            if idx is None:
                continue
            # bucket duration ≈ rollup window; samples × monitor_seconds bounds it.
            dur_h = (rr.samples * monitor_seconds) / 3600.0 if rr.samples else 0.0
            kwh = (rr.power_mean or 0.0) * dur_h / 1000.0
            bucket_kwh[idx] += kwh
            ent_total += kwh
        by_entity[entity_id] = round(ent_total, 4)

    buckets = [
        {"label": labels[i], "kwh": round(bucket_kwh[i], 4),
         "cost": round(bucket_kwh[i] * tariff, 2)}
        for i in range(n)
    ]
    total_kwh = round(sum(bucket_kwh), 4)
    return {
        "period": period,
        "buckets": buckets,
        "total_kwh": total_kwh,
        "total_cost": round(total_kwh * tariff, 2),
        "by_entity": by_entity,
    }


def _bucket_index(edges, t, n):
    for i in range(n):
        if edges[i] <= t < edges[i + 1]:
            return i
    return None
