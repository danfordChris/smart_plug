"""Device push-token registration for FCM. The app posts its token here after
login; the gateway sends a user's alert pushes to every token they hold."""
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlmodel import Session, select

from ..db import get_session
from ..deps import get_current_user
from ..models import PushToken, User, now_utc

router = APIRouter(prefix="/push", tags=["push"])


class RegisterIn(BaseModel):
    token: str
    platform: str = ""


class UnregisterIn(BaseModel):
    token: str


@router.post("/register", status_code=status.HTTP_204_NO_CONTENT)
def register(
    body: RegisterIn,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    token = body.token.strip()
    if not token:
        return None
    existing = session.exec(
        select(PushToken).where(PushToken.token == token)
    ).first()
    if existing is None:
        existing = PushToken(user_id=user.id, token=token, platform=body.platform)
    else:
        # Re-home the token to this user (e.g. a shared device) and refresh.
        existing.user_id = user.id
        existing.platform = body.platform or existing.platform
        existing.updated_at = now_utc()
    session.add(existing)
    session.commit()
    return None


@router.post("/unregister", status_code=status.HTTP_204_NO_CONTENT)
def unregister(
    body: UnregisterIn,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    row = session.exec(
        select(PushToken).where(
            PushToken.token == body.token.strip(),
            PushToken.user_id == user.id,
        )
    ).first()
    if row is not None:
        session.delete(row)
        session.commit()
    return None
