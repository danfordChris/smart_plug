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


# ─── Schedules ─────────────────────────────────────────────────────────────
import re

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


def _validate_days(v: str) -> str:
    v = (v or "").strip()
    if not v:
        return ""
    parts = [p.strip() for p in v.split(",") if p.strip() != ""]
    out = []
    for p in parts:
        if not p.isdigit() or not (0 <= int(p) <= 6):
            raise ValueError("days must be weekday ints 0-6 (Mon=0..Sun=6)")
        out.append(int(p))
    # Dedupe + sort for a canonical form.
    return ",".join(str(d) for d in sorted(set(out)))


class ScheduleIn(BaseModel):
    entity_id: str
    action: str
    time_hhmm: str
    days: str = ""
    enabled: bool = True
    label: str = ""

    @field_validator("entity_id")
    @classmethod
    def _entity(cls, v: str) -> str:
        v = v.strip()
        if not v.startswith("switch."):
            raise ValueError("entity_id must be a switch.* entity")
        return v

    @field_validator("action")
    @classmethod
    def _action(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in ("on", "off"):
            raise ValueError("action must be 'on' or 'off'")
        return v

    @field_validator("time_hhmm")
    @classmethod
    def _time(cls, v: str) -> str:
        v = v.strip()
        if not _HHMM.match(v):
            raise ValueError("time_hhmm must be 24h HH:MM")
        return v

    @field_validator("days")
    @classmethod
    def _days(cls, v: str) -> str:
        return _validate_days(v)


class ScheduleUpdate(BaseModel):
    entity_id: Optional[str] = None
    action: Optional[str] = None
    time_hhmm: Optional[str] = None
    days: Optional[str] = None
    enabled: Optional[bool] = None
    label: Optional[str] = None

    @field_validator("action")
    @classmethod
    def _action(cls, v):
        if v is None:
            return v
        v = v.strip().lower()
        if v not in ("on", "off"):
            raise ValueError("action must be 'on' or 'off'")
        return v

    @field_validator("time_hhmm")
    @classmethod
    def _time(cls, v):
        if v is None:
            return v
        v = v.strip()
        if not _HHMM.match(v):
            raise ValueError("time_hhmm must be 24h HH:MM")
        return v

    @field_validator("days")
    @classmethod
    def _days(cls, v):
        if v is None:
            return v
        return _validate_days(v)


class ScheduleOut(BaseModel):
    id: int
    entity_id: str
    action: str
    time_hhmm: str
    days: str
    enabled: bool
    label: str
    created_at: datetime


# ─── Device config (rename/type + auto-off) ────────────────────────────────
_APPLIANCE_TYPES = {
    "", "radio", "fridge", "heater", "airConditioner", "washer",
    "waterHeater", "light", "other",
}


class DeviceConfigIn(BaseModel):
    """Upsert payload — all fields optional so the app can patch one at a time."""

    display_name: Optional[str] = None
    appliance_type: Optional[str] = None
    auto_off_enabled: Optional[bool] = None
    auto_off_idle_minutes: Optional[int] = None
    auto_off_threshold_w: Optional[float] = None
    power_entity_id: Optional[str] = None
    alerts_enabled: Optional[bool] = None

    @field_validator("appliance_type")
    @classmethod
    def _type(cls, v):
        if v is None:
            return v
        v = v.strip()
        if v not in _APPLIANCE_TYPES:
            raise ValueError("unknown appliance_type")
        return v

    @field_validator("auto_off_idle_minutes")
    @classmethod
    def _idle(cls, v):
        if v is None:
            return v
        if v < 1 or v > 1440:
            raise ValueError("auto_off_idle_minutes must be 1..1440")
        return v

    @field_validator("auto_off_threshold_w")
    @classmethod
    def _threshold(cls, v):
        if v is None:
            return v
        if v < 0 or v > 100000:
            raise ValueError("auto_off_threshold_w out of range")
        return v


class DeviceConfigOut(BaseModel):
    entity_id: str
    display_name: str
    appliance_type: str
    auto_off_enabled: bool
    auto_off_idle_minutes: int
    auto_off_threshold_w: float
    power_entity_id: str
    alerts_enabled: bool


class AlertOut(BaseModel):
    id: int
    entity_id: str
    kind: str
    message: str
    read: bool
    created_at: datetime


# ─── Diagnosis ─────────────────────────────────────────────────────────────
class FindingOut(BaseModel):
    code: str
    severity: str
    message: str


class DiagnosisOut(BaseModel):
    entity_id: str
    status_label: str
    severity: str
    explanation: str
    findings: list[FindingOut]
    appliance_guess: str = ""
    confidence: float = 0.0
    model_version: str = ""


# ─── Usage ─────────────────────────────────────────────────────────────────
class UsageBucketOut(BaseModel):
    label: str
    kwh: float
    cost: float


class UsageOut(BaseModel):
    period: str
    buckets: list[UsageBucketOut]
    total_kwh: float
    total_cost: float
    currency: str
    by_entity: dict[str, float] = {}
    entity_id: str = ""
