"""Per-user, per-plug configuration: display overrides (name/type) and the idle
auto-off policy. One row per (user, entity); GET returns sensible defaults when
nothing is stored yet, so the app always has something to render."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from ..db import get_session
from ..deps import get_current_user
from ..models import DeviceConfig, User
from ..schemas import DeviceConfigIn, DeviceConfigOut

router = APIRouter(prefix="/device-config", tags=["device-config"])


def _to_out(c: DeviceConfig) -> DeviceConfigOut:
    return DeviceConfigOut(
        entity_id=c.entity_id,
        display_name=c.display_name,
        appliance_type=c.appliance_type,
        auto_off_enabled=c.auto_off_enabled,
        auto_off_idle_minutes=c.auto_off_idle_minutes,
        auto_off_threshold_w=c.auto_off_threshold_w,
        power_entity_id=c.power_entity_id,
        alerts_enabled=c.alerts_enabled,
    )


def _default(entity_id: str) -> DeviceConfigOut:
    return DeviceConfigOut(
        entity_id=entity_id,
        display_name="",
        appliance_type="",
        auto_off_enabled=False,
        auto_off_idle_minutes=30,
        auto_off_threshold_w=5.0,
        power_entity_id="",
        alerts_enabled=True,
    )


@router.get("", response_model=list[DeviceConfigOut])
def list_configs(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(DeviceConfig).where(DeviceConfig.created_by == user.id)
    ).all()
    return [_to_out(c) for c in rows]


@router.get("/{entity_id}", response_model=DeviceConfigOut)
def get_config(
    entity_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    c = session.exec(
        select(DeviceConfig).where(
            DeviceConfig.created_by == user.id,
            DeviceConfig.entity_id == entity_id,
        )
    ).first()
    return _to_out(c) if c else _default(entity_id)


@router.put("/{entity_id}", response_model=DeviceConfigOut)
def upsert_config(
    entity_id: str,
    body: DeviceConfigIn,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not entity_id.startswith("switch."):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="entity_id must be a switch.* entity",
        )
    c = session.exec(
        select(DeviceConfig).where(
            DeviceConfig.created_by == user.id,
            DeviceConfig.entity_id == entity_id,
        )
    ).first()
    if c is None:
        c = DeviceConfig(created_by=user.id, entity_id=entity_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(c, field, value)
    session.add(c)
    session.commit()
    session.refresh(c)
    return _to_out(c)
