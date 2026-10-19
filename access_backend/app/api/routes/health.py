from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend
    from app.services.probe_dino_detector import checkpoint_path, probe_detector_available

    backend = active_ai_detector_backend()
    integrity: dict = {"detector_backend": backend}
    if backend == "probe":
        integrity["probe_checkpoint_ready"] = probe_detector_available()
        integrity["probe_checkpoint"] = checkpoint_path().name
        integrity["probe_low_risk_threshold"] = float(settings.probe_low_risk_threshold)
        integrity["probe_high_risk_threshold"] = float(settings.probe_high_risk_threshold)
    return {"status": "ok", "db": "connected", "integrity": integrity}
