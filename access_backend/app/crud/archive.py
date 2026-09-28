from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.archive import Archive


def list_archives(db: Session) -> list[Archive]:
    return list(db.scalars(select(Archive).order_by(Archive.archived_at.desc())))


def archived_media_ids(db: Session) -> set[int]:
    return set(db.scalars(select(Archive.media_id)))


def get_for_media(db: Session, media_id: int) -> Archive | None:
    return db.scalar(select(Archive).where(Archive.media_id == media_id))


def create(db: Session, data: dict, archived_by: int) -> Archive:
    row = Archive(**data, archived_by=archived_by)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def create_if_not_exists(db: Session, media_id: int, archived_by: int) -> Archive:
    existing = get_for_media(db, media_id)
    if existing:
        return existing
    return create(db, {"media_id": media_id}, archived_by)
