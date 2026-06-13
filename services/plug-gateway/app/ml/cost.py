"""Cost/bill anomaly from telemetry: compare today's projected spend against the
appliance's own daily baseline (in the gateway's tariff/currency)."""
from __future__ import annotations

from collections import defaultdict

from sqlmodel import Session, select

from ..models import PlugTelemetry


def daily_kwh(engine, entity_id: str) -> dict:
    """Estimated kWh per calendar day: mean observed power × 24h / 1000.
    Approximate (assumes the day's samples represent it), good enough for a
    relative-anomaly comparison."""
    with Session(engine) as s:
        rows = s.exec(
            select(PlugTelemetry).where(
                PlugTelemetry.entity_id == entity_id,
                PlugTelemetry.power_w.is_not(None),
            )
        ).all()
    by_day = defaultdict(list)
    for r in rows:
        by_day[r.recorded_at.date()].append(r.power_w)
    return {
        day: (sum(p) / len(p)) * 24 / 1000.0
        for day, p in by_day.items()
        if p
    }


def cost_anomaly(engine, entity_id: str, tariff: float, *, min_days: int = 3,
                 ratio_threshold: float = 1.5):
    """Optional finding if the latest day's projected cost is materially above
    the median of prior days."""
    daily = daily_kwh(engine, entity_id)
    if len(daily) < min_days + 1:
        return None
    days = sorted(daily)
    today = days[-1]
    prior = sorted(daily[d] for d in days[:-1])
    median = prior[len(prior) // 2]
    if median <= 0:
        return None
    today_kwh = daily[today]
    ratio = today_kwh / median
    if ratio >= ratio_threshold:
        return {
            "code": "cost_spike",
            "severity": "warning",
            "evidence": {
                "today_cost": today_kwh * tariff,
                "baseline_cost": median * tariff,
                "ratio": ratio,
            },
        }
    return None
