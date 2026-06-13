"""Device-config CRUD + per-user isolation + auto-off decision logic."""
from app.monitor import auto_off_due

from .helpers import admin_session, bearer, login, signup

ENTITY = "switch.radio_sonoff_10024a097a_1"


def test_requires_auth(client):
    assert client.get("/device-config").status_code == 401
    assert client.put(f"/device-config/{ENTITY}", json={}).status_code == 401


def test_get_returns_defaults_when_unset(client):
    token = admin_session(client)["access_token"]
    res = client.get(f"/device-config/{ENTITY}", headers=bearer(token))
    assert res.status_code == 200
    body = res.json()
    assert body["entity_id"] == ENTITY
    assert body["display_name"] == ""
    assert body["auto_off_enabled"] is False
    assert body["alerts_enabled"] is True


def test_upsert_and_partial_patch(client):
    token = admin_session(client)["access_token"]
    r1 = client.put(
        f"/device-config/{ENTITY}",
        json={"display_name": "Living Room Radio", "appliance_type": "radio"},
        headers=bearer(token),
    )
    assert r1.status_code == 200, r1.text
    assert r1.json()["display_name"] == "Living Room Radio"
    assert r1.json()["appliance_type"] == "radio"
    assert r1.json()["auto_off_enabled"] is False  # untouched default

    # Patch only auto-off; name must persist.
    r2 = client.put(
        f"/device-config/{ENTITY}",
        json={"auto_off_enabled": True, "auto_off_idle_minutes": 15,
              "power_entity_id": "sensor.radio_power"},
        headers=bearer(token),
    )
    assert r2.json()["auto_off_enabled"] is True
    assert r2.json()["auto_off_idle_minutes"] == 15
    assert r2.json()["display_name"] == "Living Room Radio"

    listed = client.get("/device-config", headers=bearer(token)).json()
    assert len(listed) == 1


def test_validation(client):
    token = admin_session(client)["access_token"]
    assert client.put(f"/device-config/{ENTITY}", json={"appliance_type": "toaster"},
                      headers=bearer(token)).status_code == 422
    assert client.put(f"/device-config/{ENTITY}", json={"auto_off_idle_minutes": 0},
                      headers=bearer(token)).status_code == 422
    assert client.put("/device-config/light.kitchen", json={"display_name": "x"},
                      headers=bearer(token)).status_code == 400


def test_per_user_isolation(client):
    admin = admin_session(client)["access_token"]
    signup(client, "u2@home.test", "password123")
    uid = next(u["id"] for u in client.get("/admin/users", headers=bearer(admin)).json()
               if u["email"] == "u2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    u2 = login(client, "u2@home.test", "password123").json()["access_token"]

    client.put(f"/device-config/{ENTITY}", json={"display_name": "admin name"}, headers=bearer(admin))
    client.put(f"/device-config/{ENTITY}", json={"display_name": "u2 name"}, headers=bearer(u2))

    assert client.get(f"/device-config/{ENTITY}", headers=bearer(admin)).json()["display_name"] == "admin name"
    assert client.get(f"/device-config/{ENTITY}", headers=bearer(u2)).json()["display_name"] == "u2 name"


# ── Pure auto-off decision ───────────────────────────────────────────────
def test_auto_off_due():
    base = dict(is_on=True, critical=False, enabled=True, power_w=2.0,
                threshold_w=5.0, idle_elapsed_min=31, idle_minutes=30)
    assert auto_off_due(**base) is True
    assert auto_off_due(**{**base, "idle_elapsed_min": 10}) is False  # not idle long enough
    assert auto_off_due(**{**base, "power_w": 8.0}) is False  # still drawing
    assert auto_off_due(**{**base, "is_on": False}) is False  # already off
    assert auto_off_due(**{**base, "critical": True}) is False  # fridge etc.
    assert auto_off_due(**{**base, "enabled": False}) is False
    assert auto_off_due(**{**base, "power_w": None}) is False  # no reading
