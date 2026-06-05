"""Auth flow: signup gating, login, refresh rotation, logout, invites."""
from tests.helpers import bearer, login, signup


def test_first_user_becomes_active_admin(client):
    res = signup(client, "owner@home.test", "ownerpass123")
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["role"] == "admin"
    assert body["status"] == "active"


def test_second_user_is_pending_and_cannot_login(client):
    signup(client, "owner@home.test", "ownerpass123")
    res = signup(client, "guest@home.test", "guestpass123")
    assert res.status_code == 201
    assert res.json()["status"] == "pending"
    assert res.json()["role"] == "user"

    # Pending users are blocked at login with a clear 403.
    res = login(client, "guest@home.test", "guestpass123")
    assert res.status_code == 403
    assert "approval" in res.json()["detail"].lower()


def test_duplicate_email_rejected(client):
    signup(client, "owner@home.test", "ownerpass123")
    res = signup(client, "owner@home.test", "different123")
    assert res.status_code == 409


def test_login_returns_tokens_and_me(client):
    signup(client, "owner@home.test", "ownerpass123")
    res = login(client, "owner@home.test", "ownerpass123")
    assert res.status_code == 200, res.text
    tokens = res.json()
    assert tokens["role"] == "admin"
    assert tokens["access_token"] and tokens["refresh_token"]
    assert tokens["expires_in"] > 0

    me = client.get("/auth/me", headers=bearer(tokens["access_token"]))
    assert me.status_code == 200
    assert me.json()["email"] == "owner@home.test"


def test_login_wrong_password(client):
    signup(client, "owner@home.test", "ownerpass123")
    res = login(client, "owner@home.test", "WRONGpass123")
    assert res.status_code == 401


def test_refresh_rotates_and_old_token_dies(client):
    signup(client, "owner@home.test", "ownerpass123")
    tokens = login(client, "owner@home.test", "ownerpass123").json()
    old_refresh = tokens["refresh_token"]

    res = client.post("/auth/refresh", json={"refresh_token": old_refresh})
    assert res.status_code == 200
    new_tokens = res.json()
    assert new_tokens["refresh_token"] != old_refresh

    # Old refresh token is now revoked.
    again = client.post("/auth/refresh", json={"refresh_token": old_refresh})
    assert again.status_code == 401

    # The new access token works.
    me = client.get("/auth/me", headers=bearer(new_tokens["access_token"]))
    assert me.status_code == 200


def test_logout_revokes_refresh(client):
    signup(client, "owner@home.test", "ownerpass123")
    tokens = login(client, "owner@home.test", "ownerpass123").json()

    out = client.post("/auth/logout", json={"refresh_token": tokens["refresh_token"]})
    assert out.status_code == 204

    res = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert res.status_code == 401


def test_invite_code_activates_immediately(client):
    signup(client, "owner@home.test", "ownerpass123")
    admin_tokens = login(client, "owner@home.test", "ownerpass123").json()

    inv = client.post("/admin/invites", headers=bearer(admin_tokens["access_token"]))
    assert inv.status_code == 201, inv.text
    code = inv.json()["code"]

    res = signup(client, "invited@home.test", "invitedpass123", invite_code=code)
    assert res.status_code == 201
    assert res.json()["status"] == "active"

    # And the invited user can log in straight away.
    assert login(client, "invited@home.test", "invitedpass123").status_code == 200


def test_bad_invite_code_rejected(client):
    signup(client, "owner@home.test", "ownerpass123")
    res = signup(client, "x@home.test", "password123", invite_code="not-a-real-code")
    assert res.status_code == 400


def test_short_password_rejected(client):
    res = signup(client, "owner@home.test", "short")
    assert res.status_code == 422
