"""SQLModel tables: users, refresh tokens, invites."""
from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


def now_utc() -> datetime:
    """Naive UTC timestamp.

    SQLite round-trips datetimes without timezone info, so we standardise on
    naive UTC everywhere to keep comparisons (e.g. token expiry) correct.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True)
    password_hash: str
    role: str = Field(default="user")  # "admin" | "user"
    status: str = Field(default="pending")  # "active" | "pending" | "disabled"
    created_at: datetime = Field(default_factory=now_utc)


class RefreshToken(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True, foreign_key="user.id")
    token_hash: str = Field(index=True)
    expires_at: datetime
    revoked: bool = Field(default=False)
    created_at: datetime = Field(default_factory=now_utc)


class Invite(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    code: str = Field(index=True, unique=True)
    created_by: int
    used_by: Optional[int] = Field(default=None)
    expires_at: Optional[datetime] = Field(default=None)
    created_at: datetime = Field(default_factory=now_utc)
