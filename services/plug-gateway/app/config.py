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


@lru_cache
def get_settings() -> Settings:
    return Settings()
