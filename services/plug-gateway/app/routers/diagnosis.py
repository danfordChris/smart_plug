"""Per-plug appliance diagnosis: a structured status label + NL explanation,
derived from stored telemetry by the classic-ML bundle (with heuristic
fallback). Every route requires a valid access token."""
from fastapi import APIRouter, Depends, Request
from sqlmodel import Session, select

from ..db import get_session
from ..deps import get_current_user
from ..ml import explain, service
from ..models import DeviceConfig, User
from ..schemas import DiagnosisOut, FindingOut

router = APIRouter(prefix="/diagnosis", tags=["diagnosis"])


def _to_out(entity_id: str, result: dict, currency: str) -> DiagnosisOut:
    findings = [
        FindingOut(
            code=f["code"],
            severity=f.get("severity", "ok"),
            message=explain.render_finding(f, currency=currency),
        )
        for f in result.get("findings", [])
    ]
    return DiagnosisOut(
        entity_id=entity_id,
        status_label=result.get("status_label", "Healthy"),
        severity=result.get("severity", "ok"),
        explanation=result.get("explanation", ""),
        findings=findings,
        appliance_guess=result.get("appliance_guess", ""),
        confidence=result.get("confidence", 0.0),
        model_version=result.get("model_version", ""),
    )


@router.get("/{entity_id}", response_model=DiagnosisOut)
def get_diagnosis(
    entity_id: str,
    request: Request,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    settings = request.app.state.settings
    bundle = getattr(request.app.state, "ml_bundle", None)
    cfg = session.exec(
        select(DeviceConfig).where(
            DeviceConfig.created_by == user.id,
            DeviceConfig.entity_id == entity_id,
        )
    ).first()
    appliance_type = cfg.appliance_type if cfg else ""
    display_name = cfg.display_name if (cfg and cfg.display_name) else ""
    result = service.diagnose_entity(
        request.app.state.engine, settings, bundle, entity_id,
        appliance_type, display_name,
    )
    return _to_out(entity_id, result, settings.currency_symbol)
