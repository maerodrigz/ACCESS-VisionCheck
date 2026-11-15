"""Per-member announcement read stamps (idempotent first-open)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.announcement_member_read import AnnouncementMemberRead

READ_TTL = timedelta(hours=24)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def get_for_user(
    db: Session, *, announcement_id: int, user_id: int
) -> AnnouncementMemberRead | None:
    return db.scalar(
        select(AnnouncementMemberRead).where(
            AnnouncementMemberRead.announcement_id == announcement_id,
            AnnouncementMemberRead.user_id == user_id,
        )
    )


def reads_for_user(
    db: Session, *, user_id: int, announcement_ids: list[int] | None = None
) -> dict[int, AnnouncementMemberRead]:
    q = select(AnnouncementMemberRead).where(AnnouncementMemberRead.user_id == user_id)
    if announcement_ids is not None:
        if not announcement_ids:
            return {}
        q = q.where(AnnouncementMemberRead.announcement_id.in_(announcement_ids))
    rows = list(db.scalars(q))
    return {int(r.announcement_id): r for r in rows}


def is_expired_for_user(
    db: Session, *, announcement_id: int, user_id: int, now: datetime | None = None
) -> bool:
    row = get_for_user(db, announcement_id=announcement_id, user_id=user_id)
    if row is None:
        return False
    clock = now or _utc_now()
    expires = row.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires <= clock


def mark_first_read(
    db: Session, *, announcement_id: int, user_id: int
) -> AnnouncementMemberRead:
    """Stamp first_read_at / expires_at once. Concurrent opens keep the first stamp."""
    existing = get_for_user(db, announcement_id=announcement_id, user_id=user_id)
    if existing is not None:
        return existing

    now = _utc_now()
    row = AnnouncementMemberRead(
        announcement_id=announcement_id,
        user_id=user_id,
        first_read_at=now,
        expires_at=now + READ_TTL,
    )
    db.add(row)
    try:
        db.commit()
        db.refresh(row)
        return row
    except IntegrityError:
        db.rollback()
        raced = get_for_user(db, announcement_id=announcement_id, user_id=user_id)
        if raced is None:
            raise
        return raced
