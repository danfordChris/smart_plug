"""Usage aggregation: integration math, bucketing, endpoint + isolation."""
from datetime import datetime, timedelta, timezone

from sqlmodel import Session

from app.models import DeviceConfig, PlugTelemetry
from app.usage import integrate_kwh, usage_series

from .helpers import admin_session, bearer, login, signup


def _engine(client):
    return client.app.state.engine


def test_integrate_kwh_trapezoid_with_gap_cap():
    base = datetime(2026, 6, 9, 10, 0, 0)
    # Two 30s steps at 1000 W → 1000 W * (60s) ≈ 0.01667 kWh.
    samples = [(base, 1000.0), (base + timedelta(seconds=30), 1000.0),
               (base + timedelta(seconds=60), 1000.0)]
    kwh = integrate_kwh(samples, cap_seconds=120)
    assert abs(kwh - (1000.0 * 60 / 3600 / 1000)) < 1e-6
    # A huge gap beyond the cap is not counted.
    gapped = [(base, 1000.0), (base + timedelta(hours=5), 1000.0)]
    assert integrate_kwh(gapped, cap_seconds=120) == 0.0


def test_usage_series_week_buckets(client):
    engine = _engine(client)
    now = datetime(2026, 6, 9, 12, 0, 0)  # treat as UTC
    with Session(engine) as s:
        for i in range(5):
            s.add(PlugTelemetry(user_id=1, entity_id="switch.a", power_w=1200.0,
                                state="on", recorded_at=now - timedelta(minutes=2) + timedelta(seconds=30 * i)))
        s.commit()
    res = usage_series(engine, ["switch.a"], "week", now, "UTC", tariff=500.0, monitor_seconds=30)
    assert res["period"] == "week"
    assert len(res["buckets"]) == 7
    # Energy landed in the last (today) bucket only.
    assert res["buckets"][6]["kwh"] > 0
    assert sum(b["kwh"] for b in res["buckets"][:6]) == 0
    assert res["by_entity"]["switch.a"] == res["total_kwh"]
    assert abs(res["total_cost"] - res["total_kwh"] * 500.0) < 1e-6


def test_bucket_counts_per_period(client):
    engine = _engine(client)
    now = datetime(2026, 6, 9, 12, 0, 0)
    counts = {p: len(usage_series(engine, [], p, now, "UTC", 500.0)["buckets"])
              for p in ("day", "week", "month", "year")}
    assert counts == {"day": 24, "week": 7, "month": 5, "year": 12}


def test_endpoint_requires_auth(client):
    assert client.get("/usage").status_code == 401
    assert client.get("/usage/switch.a").status_code == 401


def test_endpoint_aggregates_user_plugs(client):
    token = admin_session(client)["access_token"]
    engine = _engine(client)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    with Session(engine) as s:
        s.add(DeviceConfig(created_by=1, entity_id="switch.a",
                           power_entity_id="sensor.a_power"))
        for i in range(6):
            s.add(PlugTelemetry(user_id=1, entity_id="switch.a", power_w=900.0,
                                state="on", recorded_at=now - timedelta(minutes=3) + timedelta(seconds=30 * i)))
        s.commit()
    res = client.get("/usage", params={"period": "week"}, headers=bearer(token))
    assert res.status_code == 200
    body = res.json()
    assert len(body["buckets"]) == 7
    assert body["total_kwh"] > 0
    assert body["currency"] == "TSh"
    assert abs(body["total_cost"] - body["total_kwh"] * 500.0) < 1e-3
    assert "switch.a" in body["by_entity"]


def test_endpoint_isolation(client):
    admin = admin_session(client)["access_token"]
    engine = _engine(client)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    with Session(engine) as s:
        s.add(DeviceConfig(created_by=1, entity_id="switch.a", power_entity_id="sensor.a_power"))
        s.add(PlugTelemetry(user_id=1, entity_id="switch.a", power_w=900.0, state="on", recorded_at=now))
        s.commit()
    signup(client, "u2@home.test", "password123")
    uid = next(u["id"] for u in client.get("/admin/users", headers=bearer(admin)).json()
               if u["email"] == "u2@home.test")
    client.post(f"/admin/users/{uid}/approve", headers=bearer(admin))
    u2 = login(client, "u2@home.test", "password123").json()["access_token"]
    # u2 has no DeviceConfig → empty aggregate.
    body = client.get("/usage", params={"period": "week"}, headers=bearer(u2)).json()
    assert body["total_kwh"] == 0
    assert body["by_entity"] == {}


def test_invalid_period_falls_back_to_week(client):
    token = admin_session(client)["access_token"]
    body = client.get("/usage", params={"period": "decade"}, headers=bearer(token)).json()
    assert body["period"] == "week"
    assert len(body["buckets"]) == 7
