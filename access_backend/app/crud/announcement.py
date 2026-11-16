from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.crud import announcement_member_read as read_crud
from app.models.announcement import Announcement
from app.models.announcement_member_read import AnnouncementMemberRead


def create(db: Session, *, title: str, content: str, posted_by: int) -> Announcement:
    row = Announcement(title=title, content=content, posted_by=posted_by)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get(db: Session, announcement_id: int) -> Announcement | None:
    return db.scalar(
        select(Announcement)
        .options(joinedload(Announcement.poster))
        .where(Announcement.id == announcement_id)
    )


def list_all(db: Session, limit: int = 50) -> list[Announcement]:
    """Admin / system history: never filters by member expiry."""
    return list(
        db.scalars(
            select(Announcement)
            .options(joinedload(Announcement.poster))
            .order_by(Announcement.created_at.desc())
            .limit(limit)
        )
    )


def list_active_for_member(
    db: Session, *, user_id: int, limit: int = 50
) -> list[tuple[Announcement, AnnouncementMemberRead | None]]:
    """Member feed: unread always shown; read rows hidden after expires_at."""
    rows = list_all(db, limit=limit)
    if not rows:
        return []
    reads = read_crud.reads_for_user(
        db, user_id=user_id, announcement_ids=[int(r.id) for r in rows]
    )
    now = datetime.now(timezone.utc)
    out: list[tuple[Announcement, AnnouncementMemberRead | None]] = []
    for ann in rows:
        read = reads.get(int(ann.id))
        if read is not None:
            expires = read.expires_at
            if expires.tzinfo is None:
                expires = expires.replace(tzinfo=timezone.utc)
            if expires <= now:
                continue
        out.append((ann, read))
    return out
