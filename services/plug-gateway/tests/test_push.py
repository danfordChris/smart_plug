"""Push-token register/unregister + that the sender degrades without creds."""
import asyncio

from app import push
from app.models import PushToken
from sqlmodel import Session, select

from .helpers import admin_session, bearer, login, signup


def _engine(client):
    return client.app.state.engine


def test_requires_auth(client):
    assert client.post("/push/register", json={"token": "x"}).status_code == 401


def test_register_is_idempotent_and_rehomes(client):
    admin = admin_session(client)["access_token"]
    admin_id = client.get("/auth/me", headers=bearer(admin)).json()["id"]

    assert client.post("/push/register", json={"token": "tok-1", "platform": "android"},
                       headers=bearer(admin)).status_code == 204
    # Same token again → no duplicate row.
    assert client.post("/push/register", json={"token": "tok-1", "platform": "android"},
                       headers=bearer(admin)).status_code == 204

    with Session(_engine(client)) as s:
        rows = s.exec(select(PushToken).where(PushToken.token == "tok-1")).all()
    assert len(rows) == 1
    assert rows[0].user_id == admin_id


def test_unregister_scoped_to_user(client):
    admin = admin_session(client)["access_token"]
    signup(client, "u2@home.test", "password123")
    uid = next(u["id"] for u in client.get("/admin/users", headers=bearer(admin)).json()
               if u["email"] == "u2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    u2 = login(client, "u2@home.test", "password123").json()["access_token"]

    client.post("/push/register", json={"token": "tok-admin"}, headers=bearer(admin))
    # u2 cannot remove admin's token.
    assert client.post("/push/unregister", json={"token": "tok-admin"},
                       headers=bearer(u2)).status_code == 204
    with Session(_engine(client)) as s:
        assert s.exec(select(PushToken).where(PushToken.token == "tok-admin")).first() is not None
    # admin can.
    assert client.post("/push/unregister", json={"token": "tok-admin"},
                       headers=bearer(admin)).status_code == 204
    with Session(_engine(client)) as s:
        assert s.exec(select(PushToken).where(PushToken.token == "tok-admin")).first() is None


def test_notify_noops_without_credentials(client):
    # No FCM creds configured → notify returns quietly (no exception).
    admin = admin_session(client)["access_token"]
    admin_id = client.get("/auth/me", headers=bearer(admin)).json()["id"]
    client.post("/push/register", json={"token": "tok"}, headers=bearer(admin))
    # Should not raise even though a token exists.
    asyncio.get_event_loop().run_until_complete(
        push.notify(client.app, admin_id, "Title", "Body")
    )
