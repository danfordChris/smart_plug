"""Application factory and entrypoint for the Plug Assistance gateway."""
from contextlib import asynccontextmanager
from typing import Optional

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, get_settings
from .db import init_db, make_engine
from .routers import admin, auth, proxy


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
        try:
            yield
        finally:
            await app.state.ha_client.aclose()

    app = FastAPI(title="Plug Assistance Gateway", version="0.1.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.engine = engine
    # Default: no client until lifespan runs; the proxy dep raises 503 if used
    # before startup. Tests override get_ha_client.
    app.state.ha_client = None

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

    @app.get("/health", tags=["meta"])
    def health():
        return {"status": "ok", "service": "plug-gateway"}

    return app


app = create_app()
