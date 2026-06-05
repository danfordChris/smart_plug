"""Request/response models for the API."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


class SignupIn(BaseModel):
    email: str
    # bcrypt-style limits aside, keep a sane upper bound for pbkdf2 too.
    password: str
    invite_code: Optional[str] = None

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if "@" not in v or "." not in v.split("@")[-1] or len(v) < 5:
            raise ValueError("invalid email")
        return v

    @field_validator("password")
    @classmethod
    def _password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("password must be at least 8 characters")
        if len(v) > 128:
            raise ValueError("password too long")
        return v


class LoginIn(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.strip().lower()


class RefreshIn(BaseModel):
    refresh_token: str


class LogoutIn(BaseModel):
    refresh_token: str


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    role: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    email: str
    role: str
    status: str
    created_at: datetime


class SignupOut(BaseModel):
    id: int
    email: str
    role: str
    status: str
    # Friendly hint for the app: active users can log in immediately, pending
    # users must wait for admin approval.
    message: str


class InviteOut(BaseModel):
    code: str
    expires_at: Optional[datetime] = None
