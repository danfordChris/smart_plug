"""Password hashing, JWT issuance/verification, refresh-token helpers.

Pure functions only — no FastAPI imports (see deps.py for request-bound deps).
Password hashing uses pbkdf2_sha256 (pure-Python, no native build needed).
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

from .config import Settings

_pwd = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

ALGO = "HS256"


def hash_password(password: str) -> str:
    return _pwd.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return _pwd.verify(password, hashed)


def create_access_token(settings: Settings, user_id: int, role: str) -> tuple[str, int]:
    """Returns (jwt, expires_in_seconds)."""
    now = datetime.now(timezone.utc)
    ttl = timedelta(minutes=settings.access_ttl_minutes)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + ttl).timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=ALGO)
    return token, int(ttl.total_seconds())


def decode_access_token(settings: Settings, token: str) -> dict:
    """Raises jwt.PyJWTError on invalid/expired tokens."""
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGO])
    if payload.get("type") != "access":
        raise jwt.InvalidTokenError("not an access token")
    return payload


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
