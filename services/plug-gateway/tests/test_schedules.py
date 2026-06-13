"""Schedule CRUD + per-user isolation + matching logic."""
from app.models import Schedule
from app.scheduler import day_matches, is_due

from .helpers import admin_session, bearer, login, signup

ENTITY = "switch.number_01_sonoff_10024a097a_1"


def _make(client, token, **over):
    body = {
        "entity_id": ENTITY,
        "action": "on",
        "time_hhmm": "06:30",
        "days": "",
        "enabled": True,
        "label": "Morning on",
    }
    body.update(over)
    return client.post("/schedules", json=body, headers=bearer(token))


def test_requires_auth(client):
    assert client.get("/schedules").status_code == 401
    assert client.post("/schedules", json={}).status_code == 401


def test_create_list_update_delete(client):
    token = admin_session(client)["access_token"]

    res = _make(client, token, label="Evening off", action="off", time_hhmm="22:00")
    assert res.status_code == 201, res.text
    sid = res.json()["id"]
    assert res.json()["action"] == "off"
    assert res.json()["time_hhmm"] == "22:00"

    listed = client.get("/schedules", headers=bearer(token))
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == sid

    patched = client.patch(
        f"/schedules/{sid}", json={"enabled": False, "days": "0,2,4"},
        headers=bearer(token),
    )
    assert patched.status_code == 200
    assert patched.json()["enabled"] is False
    assert patched.json()["days"] == "0,2,4"

    deleted = client.delete(f"/schedules/{sid}", headers=bearer(token))
    assert deleted.status_code == 204
    assert client.get("/schedules", headers=bearer(token)).json() == []


def test_per_user_isolation(client):
    admin = admin_session(client)["access_token"]
    # Second user, approved by admin.
    signup(client, "user2@home.test", "password123")
    users = client.get("/admin/users", headers=bearer(admin)).json()
    uid = next(u["id"] for u in users if u["email"] == "user2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    user2 = login(client, "user2@home.test", "password123").json()["access_token"]

    _make(client, admin, label="admin sched")
    _make(client, user2, label="user2 sched")

    admin_list = client.get("/schedules", headers=bearer(admin)).json()
    user2_list = client.get("/schedules", headers=bearer(user2)).json()
    assert [s["label"] for s in admin_list] == ["admin sched"]
    assert [s["label"] for s in user2_list] == ["user2 sched"]

    # user2 cannot touch admin's schedule.
    other_id = admin_list[0]["id"]
    assert client.patch(
        f"/schedules/{other_id}", json={"enabled": False}, headers=bearer(user2)
    ).status_code == 404
    assert client.delete(
        f"/schedules/{other_id}", headers=bearer(user2)
    ).status_code == 404


def test_validation_rejects_bad_input(client):
    token = admin_session(client)["access_token"]
    assert _make(client, token, action="dim").status_code == 422
    assert _make(client, token, time_hhmm="25:00").status_code == 422
    assert _make(client, token, time_hhmm="6:30").status_code == 422
    assert _make(client, token, entity_id="light.kitchen").status_code == 422
    assert _make(client, token, days="7").status_code == 422


def test_days_canonicalised(client):
    token = admin_session(client)["access_token"]
    res = _make(client, token, days="4, 0, 0 , 2")
    assert res.status_code == 201
    assert res.json()["days"] == "0,2,4"


# ── Pure matching logic ──────────────────────────────────────────────────
def test_day_matches():
    assert day_matches("", 3) is True  # empty = every day
    assert day_matches("0,2,4", 2) is True
    assert day_matches("0,2,4", 3) is False
    assert day_matches("garbage", 1) is True  # fail-open on bad data


def test_is_due():
    base = Schedule(
        entity_id=ENTITY, action="on", time_hhmm="06:30", days="", enabled=True,
        created_by=1,
    )
    assert is_due(base, "06:30", 0) is True
    assert is_due(base, "06:31", 0) is False
    base.enabled = False
    assert is_due(base, "06:30", 0) is False
    base.enabled = True
    base.days = "5,6"  # weekends only
    assert is_due(base, "06:30", 5) is True
    assert is_due(base, "06:30", 0) is False
