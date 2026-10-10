from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import require_member
from app.crud import announcement as announcement_crud
from app.database import get_db
from app.models.user import User
from app.schemas.member_api import AnnouncementOut

router = APIRouter(prefix="/announcements", tags=["Announcements"])


def _out(row) -> AnnouncementOut:
    poster = row.poster.fullname if row.poster else None
    return AnnouncementOut(
        id=row.id,
        title=row.title,
        content=row.content,
        posted_by_name=poster,
        created_at=row.created_at,
    )


@router.get("", response_model=list[AnnouncementOut])
def list_announcements(
    db: Session = Depends(get_db),
    _: User = Depends(require_member),
):
    rows = announcement_crud.list_all(db, limit=50)
    return [_out(r) for r in rows]
