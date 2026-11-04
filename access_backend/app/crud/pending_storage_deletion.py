"""Retry queue for failed storage deletes."""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.pending_storage_deletion import PendingStorageDeletion
from app.services.member_permanent_deletion import PermanentDeletionStats, retry_pending_storage_for_user


def count_pending_for_user(db: Session, user_id: int) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(PendingStorageDeletion)
            .where(PendingStorageDeletion.owner_user_id == user_id)
        )
        or 0
    )


def retry_for_user(db: Session, user_id: int) -> PermanentDeletionStats:
    return retry_pending_storage_for_user(db, user_id)
