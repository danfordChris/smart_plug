"""Diagnosis endpoint + admin ML guards."""
from datetime import datetime, timedelta

from sqlmodel import Session

from app.models import DeviceConfig, PlugTelemetry
from app.ml import registry, train as train_mod

from .helpers import admin_session, bearer, login, signup


def _engine(client):
    return client.app.state.engine


def _seed(client, entity_id, power, state, n=18, user_id=1, appliance_type=""):
    eng = _engine(client)
    base = datetime(2026, 6, 9, 9, 0, 0)
    with Session(eng) as s:
        if appliance_type:
            s.add(DeviceConfig(created_by=user_id, entity_id=entity_id,
                               appliance_type=appliance_type,
                               power_entity_id=f"sensor.{entity_id.split('.')[-1]}_power"))
        for i in range(n):
            s.add(PlugTelemetry(user_id=user_id, entity_id=entity_id, power_w=power,
                                state=state, recorded_at=base + timedelta(seconds=30 * i)))
        s.commit()


def test_requires_auth(client):
    assert client.get("/diagnosis/switch.x").status_code == 401


def test_collecting_when_insufficient_data(client):
    token = admin_session(client)["access_token"]
    _seed(client, "switch.new", 8.0, "on", n=4)  # below MIN_SAMPLES
    res = client.get("/diagnosis/switch.new", headers=bearer(token))
    assert res.status_code == 200
    body = res.json()
    assert body["model_version"] == "insufficient-data"
    assert any(f["code"] == "collecting" for f in body["findings"])


def test_stuck_on_diagnosis(client):
    token = admin_session(client)["access_token"]
    _seed(client, "switch.radio", 40.0, "off", n=18, appliance_type="radio")
    res = client.get("/diagnosis/switch.radio", headers=bearer(token))
    assert res.status_code == 200
    body = res.json()
    assert body["severity"] == "warning"
    assert body["status_label"] == "Needs attention"
    codes = {f["code"] for f in body["findings"]}
    assert "stuck_on" in codes
    assert body["explanation"]


def test_trained_bundle_served(client, tmp_path):
    token = admin_session(client)["access_token"]
    _seed(client, "switch.heater", 50.0, "on", n=18, appliance_type="heater")
    train_mod.train(str(tmp_path), per_type=8, window=120, seed=2)
    client.app.state.ml_bundle = registry.load_bundle(str(tmp_path))
    res = client.get("/diagnosis/switch.heater", headers=bearer(token)).json()
    assert res["model_version"] != "insufficient-data"
    assert res["model_version"] != "heuristic-fallback"
    # Heater stuck low → not_heating fault surfaces.
    assert any(f["code"] == "not_heating" for f in res["findings"])


def test_reload_endpoint_admin_only(client):
    admin = admin_session(client)["access_token"]
    # non-admin
    signup(client, "u2@home.test", "password123")
    uid = next(u["id"] for u in client.get("/admin/users", headers=bearer(admin)).json()
               if u["email"] == "u2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    u2 = login(client, "u2@home.test", "password123").json()["access_token"]
    assert client.post("/admin/ml/reload", headers=bearer(u2)).status_code == 403
    assert client.post("/admin/ml/reload", headers=bearer(admin)).status_code == 200
