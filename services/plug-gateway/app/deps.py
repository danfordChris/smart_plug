"""FastAPI dependencies: auth guards and the upstream HA client."""
from typing import Optional

import httpx
import jwt
from fastapi import Depends, Header, HTTPException, Request, status
from sqlmodel import Session

from .config import Settings
from .db import get_session
from .models import User
from .security import decode_access_token


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


def get_ha_client(request: Request) -> httpx.AsyncClient:
    """Shared async client pointed at HA with the server-side token baked in.

    Overridden in tests to inject an httpx.MockTransport client.
    """
    client = getattr(request.app.state, "ha_client", None)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Upstream client not ready",
        )
    return client


def get_current_user(
    request: Request,
    authorization: Optional[str] = Header(default=None),
    session: Session = Depends(get_session),
) -> User:
    settings: Settings = request.app.state.settings
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_access_token(settings, token)
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = session.get(User, int(payload["sub"]))
    if user is None or user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User is not active",
        )
    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )
    return user
