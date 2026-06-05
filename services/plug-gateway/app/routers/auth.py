"""Authentication: signup, login, refresh, logout, me."""
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlmodel import Session, func, select

from ..config import Settings
from ..db import get_session
from ..deps import get_current_user
from ..models import Invite, RefreshToken, User, now_utc
from ..schemas import (
    LoginIn,
    LogoutIn,
    RefreshIn,
    SignupIn,
    SignupOut,
    TokenOut,
    UserOut,
)
from ..security import (
    create_access_token,
    hash_password,
    hash_refresh_token,
    new_refresh_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _settings(request: Request) -> Settings:
    return request.app.state.settings


def _issue_tokens(
    request: Request, session: Session, user: User
) -> TokenOut:
    settings = _settings(request)
    access, expires_in = create_access_token(settings, user.id, user.role)
    raw_refresh = new_refresh_token()
    rt = RefreshToken(
        user_id=user.id,
        token_hash=hash_refresh_token(raw_refresh),
        expires_at=now_utc() + timedelta(days=settings.refresh_ttl_days),
    )
    session.add(rt)
    session.commit()
    return TokenOut(
        access_token=access,
        refresh_token=raw_refresh,
        expires_in=expires_in,
        role=user.role,
    )


@router.post("/signup", response_model=SignupOut, status_code=status.HTTP_201_CREATED)
def signup(body: SignupIn, request: Request, session: Session = Depends(get_session)):
    existing = session.exec(select(User).where(User.email == body.email)).first()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already registered")

    user_count = session.exec(select(func.count()).select_from(User)).one()

    role = "user"
    used_invite: Invite | None = None
    if user_count == 0:
        # First account bootstraps the deployment as an active admin.
        role, account_status = "admin", "active"
    else:
        # Subsequent accounts need an invite code OR admin approval.
        account_status = "pending"
        if body.invite_code:
            used_invite = session.exec(
                select(Invite).where(Invite.code == body.invite_code)
            ).first()
            valid = (
                used_invite is not None
                and used_invite.used_by is None
                and (
                    used_invite.expires_at is None
                    or used_invite.expires_at > now_utc()
                )
            )
            if not valid:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid invite code")
            account_status = "active"

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        role=role,
        status=account_status,
    )
    session.add(user)
    session.commit()
    session.refresh(user)

    if used_invite is not None:
        used_invite.used_by = user.id
        session.add(used_invite)
        session.commit()

    message = (
        "Account created — you can log in now."
        if account_status == "active"
        else "Account created — waiting for an administrator to approve it."
    )
    return SignupOut(
        id=user.id,
        email=user.email,
        role=user.role,
        status=user.status,
        message=message,
    )


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, request: Request, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == body.email)).first()
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password")
    if user.status == "pending":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Account is awaiting administrator approval"
        )
    if user.status != "active":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Account is disabled")
    return _issue_tokens(request, session, user)


@router.post("/refresh", response_model=TokenOut)
def refresh(body: RefreshIn, request: Request, session: Session = Depends(get_session)):
    token_hash = hash_refresh_token(body.refresh_token)
    rt = session.exec(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    ).first()
    if rt is None or rt.revoked or rt.expires_at <= now_utc():
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")
    user = session.get(User, rt.user_id)
    if user is None or user.status != "active":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User is not active")
    # Rotate: revoke the presented token, issue a fresh pair.
    rt.revoked = True
    session.add(rt)
    session.commit()
    return _issue_tokens(request, session, user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: LogoutIn, session: Session = Depends(get_session)):
    token_hash = hash_refresh_token(body.refresh_token)
    rt = session.exec(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    ).first()
    if rt is not None and not rt.revoked:
        rt.revoked = True
        session.add(rt)
        session.commit()
    return None


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return UserOut(
        id=user.id,
        email=user.email,
        role=user.role,
        status=user.status,
        created_at=user.created_at,
    )
