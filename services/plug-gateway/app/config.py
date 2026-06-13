"""Runtime configuration, loaded from environment / .env.

All secrets (HA token, JWT secret) come from the environment — never committed.
See .env.example for the variable names.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Upstream Home Assistant the gateway proxies to. On the Pi this is the
    # local HA (e.g. http://localhost:8123); the long-lived token lives here,
    # server-side, and is never sent to clients.
    ha_base_url: str = "http://localhost:8123"
    ha_token: str = ""

    # JWT signing for the per-user access tokens the gateway issues.
    jwt_secret: str = "dev-insecure-change-me"
    access_ttl_minutes: int = 30
    refresh_ttl_days: int = 30

    # SQLite location (mount on a persistent host volume in production).
    db_path: str = "./plug_gateway.db"

    # Timezone the gateway interprets schedule times in (IANA name).
    timezone: str = "Africa/Dar_es_Salaam"

    # How often the device monitor evaluates idle auto-off / offline alerts.
    monitor_seconds: int = 30

    # Firebase Cloud Messaging (push). Point this at a service-account JSON on
    # the host to enable closed-app push; leave empty to disable (the in-app
    # alerts feed still works). project_id is read from the JSON if unset.
    fcm_credentials_file: str = ""
    fcm_project_id: str = ""

    # Appliance-diagnosis ML.
    # Where trained joblib model artifacts live (mounted /data volume on the Pi,
    # so they survive container recreation).
    ml_models_dir: str = "/data/models"
    # Telemetry logging: keep raw rows this many days, roll older up to N-minute
    # buckets, and cap rollups at this horizon. Keeps SQLite small on a Pi.
    telemetry_retention_days: int = 7
    rollup_minutes: int = 5
    rollup_retention_days: int = 180
    # Electricity tariff for cost diagnosis — mirror the app's AppConstants.
    tariff_per_kwh: float = 500.0
    currency_symbol: str = "TSh"
    # How often the monitor runs diagnosis and raises alerts on new faults.
    diagnosis_minutes: int = 15


@lru_cache
def get_settings() -> Settings:
    return Settings()
