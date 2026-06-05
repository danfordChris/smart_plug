"""Admin: approval, disable (with token revocation), and access control."""
from tests.helpers import admin_session, bearer, login, signup


def test_non_admin_cannot_use_admin_routes(client):
    # owner = admin; create + activate a normal user via invite.
    admin = admin_session(client)
    inv = client.post("/admin/invites", headers=bearer(admin["access_token"]))
    code = inv.json()["code"]
    signup(client, "user@home.test", "userpass123", invite_code=code)
    user = login(client, "user@home.test", "userpass123").json()

    res = client.get("/admin/users", headers=bearer(user["access_token"]))
    assert res.status_code == 403


def test_admin_approves_pending_user(client):
    admin = admin_session(client)
    signup(client, "pending@home.test", "pendingpass123")  # status: pending

    # Locate the pending user.
    users = client.get("/admin/users", headers=bearer(admin["access_token"])).json()
    pending = next(u for u in users if u["email"] == "pending@home.test")
    assert pending["status"] == "pending"

    # Before approval: login blocked.
    assert login(client, "pending@home.test", "pendingpass123").status_code == 403

    ok = client.post(
        f"/admin/users/{pending['id']}/approve",
        headers=bearer(admin["access_token"]),
    )
    assert ok.status_code == 200
    assert ok.json()["status"] == "active"

    # After approval: login works.
    assert login(client, "pending@home.test", "pendingpass123").status_code == 200


def test_disable_revokes_sessions(client):
    admin = admin_session(client)
    inv = client.post("/admin/invites", headers=bearer(admin["access_token"]))
    code = inv.json()["code"]
    signup(client, "user@home.test", "userpass123", invite_code=code)
    user = login(client, "user@home.test", "userpass123").json()
    me = client.get("/auth/me", headers=bearer(user["access_token"]))
    user_id = me.json()["id"]

    dis = client.post(
        f"/admin/users/{user_id}/disable",
        headers=bearer(admin["access_token"]),
    )
    assert dis.status_code == 200
    assert dis.json()["status"] == "disabled"

    # Refresh token no longer works (sessions revoked).
    res = client.post("/auth/refresh", json={"refresh_token": user["refresh_token"]})
    assert res.status_code == 401
    # And re-login is blocked.
    assert login(client, "user@home.test", "userpass123").status_code == 403


def test_admin_cannot_disable_self(client):
    admin = admin_session(client)
    me = client.get("/auth/me", headers=bearer(admin["access_token"])).json()
    res = client.post(
        f"/admin/users/{me['id']}/disable",
        headers=bearer(admin["access_token"]),
    )
    assert res.status_code == 400
