"""Firebase Cloud Messaging (FCM HTTP v1) push sender.

Enabled only when `fcm_credentials_file` points at a readable service-account
JSON. Without it every call is a no-op, so the rest of the gateway (and the
in-app alerts feed) works unchanged — push simply stays off until the key is
dropped on the host.
"""
import asyncio
import json
import os

import httpx
from sqlmodel import Session, delete, select

from .models import PushToken

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_creds = None  # cached google service-account Credentials
_creds_tried = False


def _load_credentials(settings):
    """Lazily load + cache service-account credentials. Returns None when push
    is not configured or the libraries/file are unavailable."""
    global _creds, _creds_tried
    if _creds is not None:
        return _creds
    if _creds_tried:
        return None
    _creds_tried = True
    path = settings.fcm_credentials_file
    if not path or not os.path.isfile(path):
        return None
    try:
        from google.oauth2 import service_account  # type: ignore

        _creds = service_account.Credentials.from_service_account_file(
            path, scopes=[_SCOPE]
        )
    except Exception:
        _creds = None
    return _creds


def _project_id(settings) -> str:
    if settings.fcm_project_id:
        return settings.fcm_project_id
    path = settings.fcm_credentials_file
    try:
        with open(path) as f:
            return json.load(f).get("project_id", "")
    except Exception:
        return ""


def _bearer(creds) -> str:
    from google.auth.transport.requests import Request  # type: ignore

    creds.refresh(Request())
    return creds.token


async def notify(app, user_id: int, title: str, body: str) -> None:
    """Best-effort push to all of a user's registered devices."""
    settings = app.state.settings
    creds = _load_credentials(settings)
    if creds is None:
        return
    project_id = _project_id(settings)
    if not project_id:
        return
    engine = app.state.engine

    with Session(engine) as session:
        tokens = [
            t.token
            for t in session.exec(
                select(PushToken).where(PushToken.user_id == user_id)
            ).all()
        ]
    if not tokens:
        return

    try:
        access_token = await asyncio.to_thread(_bearer, creds)
    except Exception:
        return

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {"Authorization": f"Bearer {access_token}"}
    stale: list[str] = []
    async with httpx.AsyncClient(timeout=10.0) as client:
        for tk in tokens:
            payload = {
                "message": {
                    "token": tk,
                    "notification": {"title": title, "body": body},
                    "android": {"priority": "high"},
                }
            }
            try:
                resp = await client.post(url, headers=headers, json=payload)
            except Exception:
                continue
            # 404/400 UNREGISTERED → token is dead; prune it.
            if resp.status_code in (400, 404):
                stale.append(tk)

    if stale:
        with Session(engine) as session:
            session.exec(delete(PushToken).where(PushToken.token.in_(stale)))
            session.commit()
