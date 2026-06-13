"""Energy-usage aggregation by period (day/week/month/year). Reads existing
telemetry only; per-user (a user sees only their own plugs' usage)."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from sqlmodel import Session, select

from ..db import get_session
from ..deps import get_current_user
from ..models import DeviceConfig, User
from ..schemas import UsageBucketOut, UsageOut
from ..usage import PERIODS, usage_series

router = APIRouter(prefix="/usage", tags=["usage"])


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _to_out(result: dict, currency: str, entity_id: str = "") -> UsageOut:
    return UsageOut(
        period=result["period"],
        buckets=[UsageBucketOut(**b) for b in result["buckets"]],
        total_kwh=result["total_kwh"],
        total_cost=result["total_cost"],
        currency=currency,
        by_entity=result.get("by_entity", {}),
        entity_id=entity_id,
    )


def _user_entities(session: Session, user: User) -> list[str]:
    rows = session.exec(
        select(DeviceConfig.entity_id).where(DeviceConfig.created_by == user.id)
    ).all()
    return list(dict.fromkeys(rows))  # de-dup, keep order


@router.get("", response_model=UsageOut)
def aggregate_usage(
    request: Request,
    period: str = "week",
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    settings = request.app.state.settings
    if period not in PERIODS:
        period = "week"
    entities = _user_entities(session, user)
    result = usage_series(
        request.app.state.engine, entities, period, _now_utc(),
        settings.timezone, settings.tariff_per_kwh, settings.monitor_seconds,
    )
    return _to_out(result, settings.currency_symbol)


@router.get("/{entity_id}", response_model=UsageOut)
def entity_usage(
    entity_id: str,
    request: Request,
    period: str = "week",
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    settings = request.app.state.settings
    if period not in PERIODS:
        period = "week"
    result = usage_series(
        request.app.state.engine, [entity_id], period, _now_utc(),
        settings.timezone, settings.tariff_per_kwh, settings.monitor_seconds,
    )
    return _to_out(result, settings.currency_symbol, entity_id=entity_id)
