"""Alert recording helper, shared by the scheduler and the monitor loops."""
from sqlmodel import Session

from .models import Alert

# Appliance types that must NEVER be auto-switched off (food spoilage / safety).
CRITICAL_TYPES = {"fridge", "waterHeater"}


def record_alert(engine, user_id: int, kind: str, message: str, entity_id: str = "") -> None:
    """Persist an in-app alert for a user. Best-effort; swallows DB errors so a
    logging failure never breaks a control action."""
    try:
        with Session(engine) as session:
            session.add(
                Alert(
                    user_id=user_id,
                    entity_id=entity_id,
                    kind=kind,
                    message=message,
                )
            )
            session.commit()
    except Exception:
        pass
