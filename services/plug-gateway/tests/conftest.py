"""Shared fixtures: a TestClient wired to a temp DB and a mocked HA upstream."""
import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.deps import get_ha_client
from app.main import create_app

HA_TOKEN = "ha-secret-token-server-side"


class MockHA:
    """Records forwarded requests and returns canned Home Assistant responses."""

    def __init__(self):
        self.requests: list[httpx.Request] = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        path = request.url.path
        method = request.method
        if path == "/api/" and method == "GET":
            return httpx.Response(200, json={"message": "API running"})
        if path == "/api/config":
            return httpx.Response(200, json={"version": "2026.6.0"})
        if path == "/api/states":
            return httpx.Response(
                200,
                json=[
                    {"entity_id": "switch.x", "state": "on", "attributes": {}},
                ],
            )
        if path.startswith("/api/states/"):
            return httpx.Response(
                200,
                json={"entity_id": path.rsplit("/", 1)[-1], "state": "on", "attributes": {}},
            )
        if path.startswith("/api/services/"):
            return httpx.Response(200, json=[])
        return httpx.Response(404, json={"error": "not found"})

    @property
    def last(self) -> httpx.Request:
        return self.requests[-1]


@pytest.fixture
def mock_ha() -> MockHA:
    return MockHA()


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        ha_base_url="http://ha.test",
        ha_token=HA_TOKEN,
        jwt_secret="unit-test-secret",
        access_ttl_minutes=30,
        refresh_ttl_days=30,
        db_path=str(tmp_path / "gateway_test.db"),
    )


@pytest.fixture
def client(settings, mock_ha):
    app = create_app(settings)
    # Inject a mock HA client that carries the same server-side token header the
    # real one would, so tests can assert the gateway injects it.
    mock_client = httpx.AsyncClient(
        base_url=settings.ha_base_url,
        headers={"Authorization": f"Bearer {settings.ha_token}"},
        transport=httpx.MockTransport(mock_ha.handler),
    )
    app.dependency_overrides[get_ha_client] = lambda: mock_client
    with TestClient(app) as c:
        yield c
