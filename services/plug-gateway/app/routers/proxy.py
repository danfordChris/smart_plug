"""Authenticated reverse-proxy to Home Assistant.

Every route requires a valid access token. Requests are forwarded to the
upstream HA with the server-side long-lived token injected — clients never see
it. Writes are restricted to switch turn_on/turn_off/toggle (least privilege).
"""
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status

from ..deps import get_current_user, get_ha_client
from ..models import User

router = APIRouter(prefix="/api", tags=["proxy"])

# Only these service calls are allowed through the gateway.
_ALLOWED_SERVICES = {
    "switch": {"turn_on", "turn_off", "toggle"},
}


async def _forward(
    client: httpx.AsyncClient,
    method: str,
    path: str,
    json_body=None,
) -> Response:
    try:
        upstream = await client.request(method, path, json=json_body)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Upstream Home Assistant unreachable: {exc}",
        )
    media_type = upstream.headers.get("content-type", "application/json")
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        media_type=media_type,
    )


@router.get("/")
async def ha_root(
    _user: User = Depends(get_current_user),
    client: httpx.AsyncClient = Depends(get_ha_client),
):
    return await _forward(client, "GET", "/api/")


@router.get("/config")
async def ha_config(
    _user: User = Depends(get_current_user),
    client: httpx.AsyncClient = Depends(get_ha_client),
):
    return await _forward(client, "GET", "/api/config")


@router.get("/states")
async def ha_states(
    _user: User = Depends(get_current_user),
    client: httpx.AsyncClient = Depends(get_ha_client),
):
    return await _forward(client, "GET", "/api/states")


@router.get("/states/{entity_id}")
async def ha_state(
    entity_id: str,
    _user: User = Depends(get_current_user),
    client: httpx.AsyncClient = Depends(get_ha_client),
):
    return await _forward(client, "GET", f"/api/states/{entity_id}")


@router.post("/services/{domain}/{service}")
async def ha_service(
    domain: str,
    service: str,
    request: Request,
    _user: User = Depends(get_current_user),
    client: httpx.AsyncClient = Depends(get_ha_client),
):
    allowed = _ALLOWED_SERVICES.get(domain, set())
    if service not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Service {domain}.{service} is not permitted via the gateway",
        )
    try:
        body = await request.json()
    except Exception:
        body = {}
    return await _forward(client, "POST", f"/api/services/{domain}/{service}", body)
