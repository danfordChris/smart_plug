"""Alerts feed: recording (via events helper), listing, unread count, mark-read,
clear, and per-user isolation."""
from app.events import record_alert

from .helpers import admin_session, bearer, login, signup


def _engine(client):
    return client.app.state.engine


def test_requires_auth(client):
    assert client.get("/alerts").status_code == 401


def test_record_list_count_read_clear(client):
    token = admin_session(client)["access_token"]
    me = client.get("/auth/me", headers=bearer(token)).json()
    engine = _engine(client)

    record_alert(engine, me["id"], "auto_off", "Turned off Radio after 30 min idle.", "switch.radio")
    record_alert(engine, me["id"], "offline", "Fridge went offline.", "switch.fridge")

    listed = client.get("/alerts", headers=bearer(token)).json()
    assert len(listed) == 2
    assert {a["kind"] for a in listed} == {"auto_off", "offline"}
    assert all(a["read"] is False for a in listed)

    assert client.get("/alerts/unread_count", headers=bearer(token)).json()["count"] == 2

    assert client.post("/alerts/read", headers=bearer(token)).status_code == 204
    assert client.get("/alerts/unread_count", headers=bearer(token)).json()["count"] == 0

    assert client.delete("/alerts", headers=bearer(token)).status_code == 204
    assert client.get("/alerts", headers=bearer(token)).json() == []


def test_per_user_isolation(client):
    admin = admin_session(client)["access_token"]
    signup(client, "u2@home.test", "password123")
    uid = next(u["id"] for u in client.get("/admin/users", headers=bearer(admin)).json()
               if u["email"] == "u2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    u2 = login(client, "u2@home.test", "password123").json()["access_token"]
    admin_id = client.get("/auth/me", headers=bearer(admin)).json()["id"]

    record_alert(_engine(client), admin_id, "auto_off", "admin alert", "switch.x")

    assert len(client.get("/alerts", headers=bearer(admin)).json()) == 1
    assert client.get("/alerts", headers=bearer(u2)).json() == []
