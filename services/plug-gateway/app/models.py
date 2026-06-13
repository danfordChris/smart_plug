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


class DeviceConfig(SQLModel, table=True):
    """Per-user, per-plug configuration: display overrides (name/type) plus the
    idle auto-off policy. One row per (user, entity)."""

    id: Optional[int] = Field(default=None, primary_key=True)
    created_by: int = Field(index=True)
    entity_id: str = Field(index=True)  # switch.*
    display_name: str = Field(default="")  # "" = use the HA friendly name
    appliance_type: str = Field(default="")  # ApplianceType enum name or "" = infer
    auto_off_enabled: bool = Field(default=False)
    auto_off_idle_minutes: int = Field(default=30)
    auto_off_threshold_w: float = Field(default=5.0)
    power_entity_id: str = Field(default="")  # sensor the monitor watches
    alerts_enabled: bool = Field(default=True)
    updated_at: datetime = Field(default_factory=now_utc)


class Alert(SQLModel, table=True):
    """An in-app event for a user: offline/online transitions, auto-off fired,
    or a schedule firing. Surfaced in the app's Alerts feed."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    entity_id: str = Field(default="")
    kind: str  # offline | online | auto_off | schedule_fired
    message: str
    read: bool = Field(default=False)
    created_at: datetime = Field(default_factory=now_utc)


class PlugTelemetry(SQLModel, table=True):
    """Raw periodic telemetry sample for a plug, logged by the monitor loop.
    Forms the training/inference dataset for appliance diagnosis. Pruned/rolled
    up by the retention step to keep SQLite small."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    entity_id: str = Field(index=True)
    power_w: Optional[float] = None
    voltage: Optional[float] = None
    current: Optional[float] = None
    energy_today: Optional[float] = None
    state: str = Field(default="")  # "on" | "off" | "unavailable" | ...
    recorded_at: datetime = Field(default_factory=now_utc, index=True)


class PlugTelemetryRollup(SQLModel, table=True):
    """Downsampled telemetry: one row per (entity, N-minute bucket) with the
    aggregate stats diagnosis needs, so long history stays cheap."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    entity_id: str = Field(index=True)
    bucket_start: datetime = Field(index=True)
    power_mean: Optional[float] = None
    power_min: Optional[float] = None
    power_max: Optional[float] = None
    energy_today: Optional[float] = None
    on_fraction: Optional[float] = None  # share of samples with state == "on"
    samples: int = 0


class PushToken(SQLModel, table=True):
    """An FCM registration token for one of a user's devices. Push messages for
    that user's alerts are sent to every token they hold."""

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    token: str = Field(index=True, unique=True)
    platform: str = Field(default="")  # "android" | "ios"
    updated_at: datetime = Field(default_factory=now_utc)


class Schedule(SQLModel, table=True):
    """A recurring on/off action for a plug, executed server-side by the
    gateway so it fires even when no phone/app is connected."""

    id: Optional[int] = Field(default=None, primary_key=True)
    entity_id: str = Field(index=True)  # e.g. switch.number_01_sonoff_10024a097a_1
    action: str  # "on" | "off"
    time_hhmm: str  # local "HH:MM" (24h), gateway timezone
    days: str = Field(default="")  # CSV of weekday ints (Mon=0..Sun=6); "" = every day
    enabled: bool = Field(default=True)
    label: str = Field(default="")
    created_by: int
    created_at: datetime = Field(default_factory=now_utc)
