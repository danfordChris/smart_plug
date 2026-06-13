"""Server-side schedule executor.

A lightweight asyncio loop (minute granularity) that turns plugs on/off at the
configured local times — running on the gateway so it fires even when no phone
is connected. Pure matching logic (`is_due`) is unit-tested in isolation.
"""
import asyncio
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlmodel import Session, select

from . import push
from .events import record_alert
from .models import Schedule


def day_matches(days: str, weekday: int) -> bool:
    """`days` is a CSV of weekday ints (Mon=0..Sun=6); empty = every day."""
    days = (days or "").strip()
    if not days:
        return True
    try:
        allowed = {int(x) for x in days.split(",") if x.strip() != ""}
    except ValueError:
        return True
    return not allowed or weekday in allowed


def is_due(schedule: Schedule, hhmm: str, weekday: int) -> bool:
    return (
        schedule.enabled
        and schedule.time_hhmm == hhmm
        and schedule.action in ("on", "off")
        and day_matches(schedule.days, weekday)
    )


async def _execute(app, schedule: Schedule) -> None:
    client = getattr(app.state, "ha_client", None)
    if client is None:
        return
    service = "turn_on" if schedule.action == "on" else "turn_off"
    try:
        await client.post(
            f"/api/services/switch/{service}",
            json={"entity_id": schedule.entity_id},
        )
    except Exception:
        # Best-effort; the same minute won't retry, but a transient failure is
        # acceptable for a recurring schedule.
        return
    engine = getattr(app.state, "engine", None)
    if engine is not None:
        name = schedule.label or schedule.entity_id.split(".", 1)[-1]
        message = (
            f"Turned {schedule.action} {name} on schedule "
            f"({schedule.time_hhmm})."
        )
        record_alert(
            engine, schedule.created_by, "schedule_fired", message, schedule.entity_id,
        )
        await push.notify(app, schedule.created_by, "Schedule", message)


async def _fire_due(app, engine, hhmm: str, weekday: int) -> None:
    with Session(engine) as session:
        candidates = session.exec(
            select(Schedule).where(
                Schedule.enabled == True,  # noqa: E712
                Schedule.time_hhmm == hhmm,
            )
        ).all()
    for s in candidates:
        if day_matches(s.days, weekday):
            await _execute(app, s)


async def run_scheduler(app) -> None:
    """Background task: each minute, fire any schedules due at the local time."""
    settings = app.state.settings
    engine = app.state.engine
    try:
        tz = ZoneInfo(settings.timezone)
    except Exception:
        tz = ZoneInfo("UTC")

    last_minute = None
    while True:
        now = datetime.now(tz)
        minute_key = now.strftime("%Y-%m-%d %H:%M")
        if minute_key != last_minute:
            last_minute = minute_key
            await _fire_due(app, engine, now.strftime("%H:%M"), now.weekday())
        await asyncio.sleep(20)
