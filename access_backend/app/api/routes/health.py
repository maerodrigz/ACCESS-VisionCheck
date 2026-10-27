from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    from app.services.detector_startup_status import integrity_detector_status

    payload: dict = {"status": "ok", "db": "connected", "integrity": integrity_detector_status()}
    if settings.health_show_database_name:
        payload["database"] = db.execute(text("SELECT current_database()")).scalar()
    return payload
