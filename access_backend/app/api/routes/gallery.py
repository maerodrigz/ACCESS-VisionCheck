"""Member-facing event gallery — approved event documentation media only."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import media as media_crud
from app.database import get_db
from app.models.user import User
from app.schemas.member_api import GalleryMediaOut

router = APIRouter(prefix="/gallery", tags=["Gallery"])


@router.get("", response_model=list[GalleryMediaOut])
def list_member_gallery(
    file_type: str | None = Query(None, description="photo | video"),
    search: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _: User = Depends(require_approved),
):
    """Approved event/documentation media for the member gallery (no evaluation uploads)."""
    rows = media_crud.list_approved_event_gallery(
        db,
        file_type=file_type,
        search=search,
        limit=limit,
        offset=offset,
    )
    out: list[GalleryMediaOut] = []
    for m in rows:
        try:
            payload = media_crud.gallery_media_json(m)
        except ValueError:
            continue
        out.append(GalleryMediaOut(**payload))
    return out
