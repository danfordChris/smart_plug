"""Application factory and entrypoint for the Plug Assistance gateway."""
import asyncio
import contextlib
from contextlib import asynccontextmanager
from typing import Optional

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, get_settings
from .db import init_db, make_engine
from .ml import registry
from .monitor import run_monitor
from .routers import (
    admin,
    alerts,
    auth,
    device_config,
    diagnosis,
    proxy,
    push,
    schedules,
    usage,
)
from .scheduler import run_scheduler


def create_app(settings: Optional[Settings] = None) -> FastAPI:
    settings = settings or get_settings()
    engine = make_engine(settings.db_path)
    # Create tables eagerly so request handlers work with or without the
    # lifespan having run (e.g. simple TestClient usage).
    init_db(engine)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.ha_client = httpx.AsyncClient(
            base_url=settings.ha_base_url,
            headers={"Authorization": f"Bearer {settings.ha_token}"},
            timeout=10.0,
        )
        # Load the trained diagnosis bundle if present (None → heuristic fallback).
        app.state.ml_bundle = registry.load_bundle(settings.ml_models_dir)
        scheduler_task = asyncio.create_task(run_scheduler(app))
        monitor_task = asyncio.create_task(run_monitor(app))
        try:
            yield
        finally:
            for task in (scheduler_task, monitor_task):
                task.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await task
            await app.state.ha_client.aclose()

    app = FastAPI(title="Plug Assistance Gateway", version="0.1.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.engine = engine
    # Default: no client until lifespan runs; the proxy dep raises 503 if used
    # before startup. Tests override get_ha_client.
    app.state.ha_client = None
    # Diagnosis model bundle, loaded in lifespan; None until then → fallback.
    app.state.ml_bundle = None

    # Mobile clients don't need CORS, but allow it for Flutter web / local dev.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(admin.router)
    app.include_router(proxy.router)
    app.include_router(schedules.router)
    app.include_router(device_config.router)
    app.include_router(alerts.router)
    app.include_router(push.router)
    app.include_router(diagnosis.router)
    app.include_router(usage.router)

    @app.get("/health", tags=["meta"])
    def health():
        return {"status": "ok", "service": "plug-gateway"}

    return app


app = create_app()
