"""Per-user CRUD for server-side plug schedules.

Schedules are executed by the gateway's background loop (see app/scheduler.py),
so an on/off action fires at the configured local time even when no phone is
connected. Every route requires a valid access token; users only see and modify
their own schedules.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from ..deps import get_current_user
from ..db import get_session
from ..models import Schedule, User
from ..schemas import ScheduleIn, ScheduleOut, ScheduleUpdate

router = APIRouter(prefix="/schedules", tags=["schedules"])


def _to_out(s: Schedule) -> ScheduleOut:
    return ScheduleOut(
        id=s.id,
        entity_id=s.entity_id,
        action=s.action,
        time_hhmm=s.time_hhmm,
        days=s.days,
        enabled=s.enabled,
        label=s.label,
        created_at=s.created_at,
    )


@router.get("", response_model=list[ScheduleOut])
def list_schedules(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(Schedule)
        .where(Schedule.created_by == user.id)
        .order_by(Schedule.time_hhmm)
    ).all()
    return [_to_out(s) for s in rows]


@router.post("", response_model=ScheduleOut, status_code=status.HTTP_201_CREATED)
def create_schedule(
    body: ScheduleIn,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    s = Schedule(
        entity_id=body.entity_id,
        action=body.action,
        time_hhmm=body.time_hhmm,
        days=body.days,
        enabled=body.enabled,
        label=body.label,
        created_by=user.id,
    )
    session.add(s)
    session.commit()
    session.refresh(s)
    return _to_out(s)


def _owned(schedule_id: int, user: User, session: Session) -> Schedule:
    s = session.get(Schedule, schedule_id)
    if s is None or s.created_by != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found"
        )
    return s


@router.patch("/{schedule_id}", response_model=ScheduleOut)
def update_schedule(
    schedule_id: int,
    body: ScheduleUpdate,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    s = _owned(schedule_id, user, session)
    data = body.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(s, field, value)
    session.add(s)
    session.commit()
    session.refresh(s)
    return _to_out(s)


@router.delete("/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_schedule(
    schedule_id: int,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    s = _owned(schedule_id, user, session)
    session.delete(s)
    session.commit()
    return None
