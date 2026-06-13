"""Admin: list/approve/disable users, mint invite codes, retrain ML models."""
import secrets
from datetime import timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlmodel import Session, select

from ..db import get_session
from ..deps import require_admin
from ..ml import dataset, registry, train
from ..models import Invite, RefreshToken, User, now_utc
from ..schemas import InviteOut, UserOut

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/users", response_model=List[UserOut])
def list_users(
    _admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    users = session.exec(select(User).order_by(User.created_at)).all()
    return [
        UserOut(
            id=u.id,
            email=u.email,
            role=u.role,
            status=u.status,
            created_at=u.created_at,
        )
        for u in users
    ]


@router.post("/users/{user_id}/approve", response_model=UserOut)
def approve_user(
    user_id: int,
    _admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    user.status = "active"
    session.add(user)
    session.commit()
    session.refresh(user)
    return UserOut(
        id=user.id,
        email=user.email,
        role=user.role,
        status=user.status,
        created_at=user.created_at,
    )


@router.post("/users/{user_id}/disable", response_model=UserOut)
def disable_user(
    user_id: int,
    admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
):
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    if user.id == admin.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot disable yourself")
    user.status = "disabled"
    session.add(user)
    # Revoke all of the user's refresh tokens so existing sessions die.
    tokens = session.exec(
        select(RefreshToken).where(RefreshToken.user_id == user_id)
    ).all()
    for t in tokens:
        t.revoked = True
        session.add(t)
    session.commit()
    session.refresh(user)
    return UserOut(
        id=user.id,
        email=user.email,
        role=user.role,
        status=user.status,
        created_at=user.created_at,
    )


@router.post("/invites", response_model=InviteOut, status_code=status.HTTP_201_CREATED)
def create_invite(
    admin: User = Depends(require_admin),
    session: Session = Depends(get_session),
    ttl_days: Optional[int] = 14,
):
    code = secrets.token_urlsafe(9)
    expires_at = now_utc() + timedelta(days=ttl_days) if ttl_days else None
    invite = Invite(code=code, created_by=admin.id, expires_at=expires_at)
    session.add(invite)
    session.commit()
    return InviteOut(code=code, expires_at=expires_at)


# ─── ML model management ───────────────────────────────────────────────────
@router.post("/ml/retrain")
def ml_retrain(request: Request, _admin: User = Depends(require_admin)):
    """Retrain the diagnosis bundle from synthetic signatures + the user's own
    telemetry (weak-labelled by appliance type), then hot-reload it. Sync def →
    runs in a threadpool, so the event loop isn't blocked."""
    settings = request.app.state.settings
    engine = request.app.state.engine
    real_samples, real_normals = dataset.build_real_training_data(engine)
    summary = train.train(
        settings.ml_models_dir,
        real_samples=real_samples,
        real_normals=real_normals,
    )
    request.app.state.ml_bundle = registry.load_bundle(settings.ml_models_dir)
    return {"status": "trained", "loaded": request.app.state.ml_bundle is not None, **summary}


@router.post("/ml/reload")
def ml_reload(request: Request, _admin: User = Depends(require_admin)):
    settings = request.app.state.settings
    request.app.state.ml_bundle = registry.load_bundle(settings.ml_models_dir)
    return {"loaded": request.app.state.ml_bundle is not None}
