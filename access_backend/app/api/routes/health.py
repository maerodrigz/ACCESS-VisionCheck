from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """Liveness: database reachable. Detector details stay out of production responses."""
    db.execute(text("SELECT 1"))
    payload: dict = {"status": "ok", "db": "connected"}
    if settings.health_show_database_name:
        payload["database"] = db.execute(text("SELECT current_database()")).scalar()
    if not settings.is_production:
        from app.services.detector_startup_status import integrity_detector_status

        payload["integrity"] = integrity_detector_status()
    return payload


@router.get("/ready")
def readiness_check(db: Session = Depends(get_db)):
    """Readiness: DB + authenticity detector checkpoint when PROBE is configured."""
    from fastapi.responses import JSONResponse

    from app.services.detector_startup_status import integrity_detector_status

    db.execute(text("SELECT 1"))
    integrity = integrity_detector_status()
    ready = True
    reasons: list[str] = []
    if not integrity.get("pytorch_available", False):
        ready = False
        reasons.append("pytorch_unavailable")
    if integrity.get("detector_backend") == "probe" and not integrity.get(
        "probe_checkpoint_on_disk", False
    ):
        ready = False
        reasons.append("probe_checkpoint_missing")
    body = {
        "status": "ready" if ready else "not_ready",
        "db": "connected",
        "reasons": reasons,
    }
    if not settings.is_production:
        body["integrity"] = integrity
    return JSONResponse(status_code=200 if ready else 503, content=body)
