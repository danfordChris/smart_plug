"""In-app alerts feed: offline/online, auto-off fired, schedule fired.

Alerts are produced server-side by the scheduler/monitor loops (see
app/events.py) and read by the app here. Per-user — a user only sees their own.
"""
from fastapi import APIRouter, Depends, status
from sqlmodel import Session, select

from ..db import get_session
from ..deps import get_current_user
from ..models import Alert, User
from ..schemas import AlertOut

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=list[AlertOut])
def list_alerts(
    limit: int = 50,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    limit = max(1, min(limit, 200))
    rows = session.exec(
        select(Alert)
        .where(Alert.user_id == user.id)
        .order_by(Alert.created_at.desc(), Alert.id.desc())
        .limit(limit)
    ).all()
    return [
        AlertOut(
            id=a.id, entity_id=a.entity_id, kind=a.kind,
            message=a.message, read=a.read, created_at=a.created_at,
        )
        for a in rows
    ]


@router.get("/unread_count")
def unread_count(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(Alert).where(Alert.user_id == user.id, Alert.read == False)  # noqa: E712
    ).all()
    return {"count": len(rows)}


@router.post("/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_read(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(Alert).where(Alert.user_id == user.id, Alert.read == False)  # noqa: E712
    ).all()
    for a in rows:
        a.read = True
        session.add(a)
    session.commit()
    return None


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def clear_alerts(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    rows = session.exec(select(Alert).where(Alert.user_id == user.id)).all()
    for a in rows:
        session.delete(a)
    session.commit()
    return None
