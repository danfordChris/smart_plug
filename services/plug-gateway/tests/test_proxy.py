"""Proxy: auth required, token injection, verbatim forwarding, whitelist."""
from tests.helpers import admin_session, bearer

from .conftest import HA_TOKEN


def test_states_requires_auth(client):
    assert client.get("/api/states").status_code == 401
    assert client.get("/api/states", headers=bearer("garbage")).status_code == 401


def test_states_proxied_with_server_side_token(client, mock_ha):
    admin = admin_session(client)
    res = client.get("/api/states", headers=bearer(admin["access_token"]))
    assert res.status_code == 200
    assert res.json() == [{"entity_id": "switch.x", "state": "on", "attributes": {}}]

    # The gateway forwarded to HA with the server-side token — the client's
    # own JWT is NEVER sent upstream.
    forwarded = mock_ha.last
    assert forwarded.url.path == "/api/states"
    assert forwarded.headers["authorization"] == f"Bearer {HA_TOKEN}"
    assert admin["access_token"] not in forwarded.headers["authorization"]


def test_config_and_single_state_proxied(client):
    admin = admin_session(client)
    h = bearer(admin["access_token"])
    assert client.get("/api/config", headers=h).json()["version"] == "2026.6.0"
    one = client.get("/api/states/switch.x", headers=h)
    assert one.status_code == 200
    assert one.json()["entity_id"] == "switch.x"


def test_switch_service_allowed(client, mock_ha):
    admin = admin_session(client)
    res = client.post(
        "/api/services/switch/turn_off",
        headers=bearer(admin["access_token"]),
        json={"entity_id": "switch.number_01_sonoff_10024a097a_1"},
    )
    assert res.status_code == 200
    forwarded = mock_ha.last
    assert forwarded.url.path == "/api/services/switch/turn_off"
    assert forwarded.headers["authorization"] == f"Bearer {HA_TOKEN}"


def test_non_whitelisted_service_blocked(client, mock_ha):
    admin = admin_session(client)
    h = bearer(admin["access_token"])
    # Wrong domain.
    r1 = client.post("/api/services/light/turn_on", headers=h, json={})
    assert r1.status_code == 403
    # Wrong service in an allowed domain.
    r2 = client.post("/api/services/switch/some_danger", headers=h, json={})
    assert r2.status_code == 403
    # Nothing was forwarded upstream for the blocked calls.
    assert all("services" not in r.url.path for r in mock_ha.requests)
