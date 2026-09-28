from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import event_calendar as event_crud
from app.database import get_db
from app.models.user import User
from app.schemas.member_api import EventOut

router = APIRouter(prefix="/events", tags=["Events"])


@router.get("", response_model=list[EventOut])
def list_events(db: Session = Depends(get_db), _: User = Depends(require_approved)):
    rows = event_crud.list_member_events(db)
    return [EventOut(**event_crud.event_to_json(e)) for e in rows]
