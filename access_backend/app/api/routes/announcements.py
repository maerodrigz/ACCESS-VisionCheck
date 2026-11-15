from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_member_or_organization
from app.crud import announcement as announcement_crud
from app.crud import announcement_member_read as read_crud
from app.database import get_db
from app.models.announcement import Announcement
from app.models.announcement_member_read import AnnouncementMemberRead
from app.models.user import User
from app.schemas.member_api import AnnouncementOut, AnnouncementReadOut

router = APIRouter(prefix="/announcements", tags=["Announcements"])


def _out(
    row: Announcement,
    read: AnnouncementMemberRead | None = None,
) -> AnnouncementOut:
    poster = row.poster.fullname if row.poster else None
    return AnnouncementOut(
        id=row.id,
        title=row.title,
        content=row.content,
        posted_by_name=poster,
        created_at=row.created_at,
        is_read=read is not None,
        first_read_at=read.first_read_at if read else None,
        expires_at=read.expires_at if read else None,
    )


@router.get("", response_model=list[AnnouncementOut])
def list_announcements(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_organization),
):
    """Active announcements for the current member (expired-after-read hidden)."""
    pairs = announcement_crud.list_active_for_member(db, user_id=current_user.id)
    return [_out(ann, read) for ann, read in pairs]


@router.get("/{announcement_id}", response_model=AnnouncementOut)
def get_announcement(
    announcement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_organization),
):
    """Detail for one announcement. 404 when missing or expired for this member."""
    row = announcement_crud.get(db, announcement_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Announcement not found")
    if read_crud.is_expired_for_user(
        db, announcement_id=announcement_id, user_id=current_user.id
    ):
        raise HTTPException(status_code=404, detail="Announcement not found")
    read = read_crud.get_for_user(
        db, announcement_id=announcement_id, user_id=current_user.id
    )
    return _out(row, read)


@router.post("/{announcement_id}/read", response_model=AnnouncementReadOut)
def mark_announcement_read(
    announcement_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_organization),
):
    """Mark detail as read. First open stamps expires_at; repeats are no-ops."""
    row = announcement_crud.get(db, announcement_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Announcement not found")
    if read_crud.is_expired_for_user(
        db, announcement_id=announcement_id, user_id=current_user.id
    ):
        raise HTTPException(status_code=404, detail="Announcement not found")

    stamped = read_crud.mark_first_read(
        db, announcement_id=announcement_id, user_id=current_user.id
    )
    return AnnouncementReadOut(
        announcement_id=announcement_id,
        is_read=True,
        first_read_at=stamped.first_read_at,
        expires_at=stamped.expires_at,
    )
