"""Dependency-aware permanent member/requestor deletion with storage cleanup."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.crud import media as media_crud
from app.crud.media import REMOVED_STORAGE_FILE_URL
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.pending_storage_deletion import PendingStorageDeletion
from app.models.request_assignment import RequestAssignment
from app.models.submission_chain import SubmissionChain
from app.models.user import User
from app.services.storage_deletion import StorageDeleteOutcome, delete_storage_for_file_url

logger = logging.getLogger(__name__)


@dataclass
class PermanentDeletionStats:
    media_deleted: int = 0
    media_failed: int = 0
    storage_deleted: int = 0
    storage_queued: int = 0
    chains_removed: int = 0
    assignments_removed: int = 0
    row_block_reasons: list[str] = field(default_factory=list)


class PermanentDeletionIncompleteError(RuntimeError):
    """Raised when media/storage cleanup must finish before the user row is removed."""

    def __init__(self, stats: PermanentDeletionStats):
        self.stats = stats
        super().__init__(format_incomplete_cleanup_error(stats))


def _queue_pending_storage(
    db: Session,
    *,
    media: MediaFile,
    owner_user_id: int,
    file_url: str,
    bucket: str | None,
    object_path: str | None,
    error: str | None,
) -> None:
    existing = db.scalar(
        select(PendingStorageDeletion).where(
            PendingStorageDeletion.media_id == media.id,
            PendingStorageDeletion.file_url == file_url,
        )
    )
    if existing:
        existing.attempts = int(existing.attempts or 0) + 1
        existing.last_error = (error or "")[:2000] or None
        return
    db.add(
        PendingStorageDeletion(
            media_id=media.id,
            owner_user_id=owner_user_id,
            file_url=file_url,
            bucket=bucket,
            object_path=object_path,
            attempts=1,
            last_error=(error or "")[:2000] or None,
        )
    )


def delete_submission_chains_for_member(
    db: Session,
    user_id: int,
    *,
    media_ids: list[int] | None = None,
) -> int:
    """Remove submission chains owned by the member (and any chain rooted on their media).

    Clears RESTRICT FK from submission_chains.root_media_id before media rows can be deleted.
    """
    by_member = list(db.scalars(select(SubmissionChain).where(SubmissionChain.member_id == user_id)))
    chains: dict[int, SubmissionChain] = {c.id: c for c in by_member}
    if media_ids:
        for c in db.scalars(select(SubmissionChain).where(SubmissionChain.root_media_id.in_(media_ids))):
            chains[c.id] = c
    if not chains:
        return 0

    chain_ids = list(chains.keys())
    root_ids = [c.root_media_id for c in chains.values()]
    db.execute(
        update(MediaFile)
        .where(MediaFile.submission_chain_id.in_(chain_ids))
        .values(submission_chain_id=None)
    )
    # Clear self-FKs that could confuse cascade ordering.
    db.execute(
        update(SubmissionChain)
        .where(SubmissionChain.id.in_(chain_ids))
        .values(
            active_replacement_media_id=None,
            awaiting_replacement_media_id=None,
            xp_awarded_media_id=None,
        )
    )
    db.flush()
    for chain in chains.values():
        db.delete(chain)
    db.flush()
    # Belt-and-suspenders: remove any residual RESTRICT rows for these roots.
    if root_ids:
        db.execute(delete(SubmissionChain).where(SubmissionChain.root_media_id.in_(root_ids)))
        db.flush()
    return len(chains)


def _media_ids_for_permanent_delete(
    db: Session,
    user_id: int,
    *,
    include_event_gallery: bool,
) -> list[int]:
    q = select(MediaFile.id).where(MediaFile.uploaded_by == user_id)
    if not include_event_gallery:
        q = q.where(MediaFile.media_category == MEDIA_CATEGORY_EVALUATION)
    return list(db.scalars(q.order_by(MediaFile.id.desc())))


def _clear_root_chain_for_media(db: Session, media_id: int) -> None:
    """Ensure no submission_chains.root_media_id RESTRICT remains for this media."""
    remaining = list(
        db.scalars(select(SubmissionChain).where(SubmissionChain.root_media_id == media_id))
    )
    if not remaining:
        return
    ids = [c.id for c in remaining]
    db.execute(
        update(MediaFile)
        .where(MediaFile.submission_chain_id.in_(ids))
        .values(submission_chain_id=None)
    )
    db.execute(
        update(SubmissionChain)
        .where(SubmissionChain.id.in_(ids))
        .values(
            active_replacement_media_id=None,
            awaiting_replacement_media_id=None,
            xp_awarded_media_id=None,
        )
    )
    db.flush()
    for chain in remaining:
        db.delete(chain)
    db.flush()


def delete_owned_media_for_user(
    db: Session,
    user_id: int,
    *,
    include_event_gallery: bool,
) -> PermanentDeletionStats:
    """Remove storage then DB rows for member-owned uploads. Queues failed Supabase deletes."""
    stats = PermanentDeletionStats()
    media_ids = _media_ids_for_permanent_delete(db, user_id, include_event_gallery=include_event_gallery)
    stats.chains_removed = delete_submission_chains_for_member(db, user_id, media_ids=media_ids)

    for media_id in media_ids:
        media = media_crud.get(db, media_id)
        if not media or media.uploaded_by != user_id:
            continue
        file_url = (media.file_url or "").strip()
        storage = delete_storage_for_file_url(file_url)
        if storage.outcome == StorageDeleteOutcome.DELETED:
            stats.storage_deleted += 1
        elif storage.outcome == StorageDeleteOutcome.FAILED:
            _queue_pending_storage(
                db,
                media=media,
                owner_user_id=user_id,
                file_url=file_url,
                bucket=storage.bucket,
                object_path=storage.object_path,
                error=storage.error,
            )
            stats.storage_queued += 1
            stats.media_failed += 1
            db.flush()
            continue
        # DELETED or NOT_APPLICABLE (missing local/external already gone): proceed to row delete.

        # If cloud bytes were removed (or never present), avoid re-attempting storage on retry.
        if (
            storage.outcome == StorageDeleteOutcome.DELETED
            and file_url
            and file_url != REMOVED_STORAGE_FILE_URL
        ):
            media.file_url = REMOVED_STORAGE_FILE_URL
            db.flush()

        _clear_root_chain_for_media(db, media.id)
        try:
            media_crud.delete_media_row_only(db, media, commit=False)
            stats.media_deleted += 1
        except RuntimeError as exc:
            stats.media_failed += 1
            reason = str(exc)
            stats.row_block_reasons.append(f"media_id={media.id}: {reason}")
            logger.warning(
                "permanent delete: media row %s blocked after storage outcome=%s: %s",
                media.id,
                storage.outcome.value,
                reason,
            )

    db.commit()
    return stats


def assert_requestor_permanent_delete_allowed(db: Session, user: User) -> None:
    if not user.role or user.role.role_name != RoleName.ORGANIZATION:
        return
    count = (
        db.scalar(
            select(func.count())
            .select_from(DocumentationRequest)
            .where(DocumentationRequest.requestor_id == user.id)
        )
        or 0
    )
    if count > 0:
        raise RuntimeError(
            f"This requestor has {count} documentation request(s). "
            "Deactivate the account to block access while preserving institutional records, "
            "or remove requests through documentation workflows first."
        )


def cleanup_member_assignments(db: Session, user: User, *, acting_admin_id: int) -> int:
    removed = 0
    if not user.role or user.role.role_name != RoleName.MEMBER:
        return removed
    for row in db.scalars(
        select(RequestAssignment).where(RequestAssignment.assigned_by == user.id)
    ).all():
        row.assigned_by = acting_admin_id
    for row in db.scalars(
        select(RequestAssignment).where(RequestAssignment.member_id == user.id)
    ).all():
        db.delete(row)
        removed += 1
    db.flush()
    return removed


def retry_pending_storage_for_user(db: Session, user_id: int) -> PermanentDeletionStats:
    """Retry queued blob deletes; remove media rows when storage succeeds."""
    stats = PermanentDeletionStats()
    rows = list(
        db.scalars(
            select(PendingStorageDeletion).where(PendingStorageDeletion.owner_user_id == user_id)
        )
    )
    for pending in rows:
        media = media_crud.get(db, pending.media_id) if pending.media_id else None
        storage = delete_storage_for_file_url(pending.file_url)
        pending.attempts = int(pending.attempts or 0) + 1
        if storage.outcome == StorageDeleteOutcome.FAILED:
            pending.last_error = (storage.error or "retry failed")[:2000]
            stats.media_failed += 1
            stats.storage_queued += 1
            continue
        stats.storage_deleted += 1
        if media is not None:
            if media.file_url and media.file_url != REMOVED_STORAGE_FILE_URL:
                media.file_url = REMOVED_STORAGE_FILE_URL
                db.flush()
            _clear_root_chain_for_media(db, media.id)
            try:
                media_crud.delete_media_row_only(db, media, commit=False)
                stats.media_deleted += 1
            except RuntimeError as exc:
                stats.media_failed += 1
                stats.row_block_reasons.append(f"media_id={media.id}: {exc}")
                pending.last_error = str(exc)[:2000]
                continue
        db.delete(pending)
    db.commit()
    return stats


def format_incomplete_cleanup_error(stats: PermanentDeletionStats) -> str:
    """Admin-facing message when permanent delete must stop before removing the user row."""
    if stats.storage_queued > 0:
        return (
            f"Permanent deletion paused: {stats.media_failed} media file(s) could not finish cleanup. "
            f"{stats.storage_queued} storage object(s) are queued for retry. "
            "The account is still active. Use Retry storage cleanup, then try permanent delete again."
        )
    if stats.media_failed > 0:
        detail = ""
        if stats.row_block_reasons:
            detail = " " + stats.row_block_reasons[0]
        return (
            f"Permanent deletion paused: {stats.media_failed} media database record(s) could not be removed"
            f" after storage cleanup.{detail} "
            "The account is still active. Use Retry permanent delete after the linked records are cleared. "
            "Do not use storage cleanup retry when nothing is queued."
        )
    return (
        "Permanent deletion paused: cleanup is incomplete. "
        "The account is still active."
    )


def incomplete_cleanup_http_detail(stats: PermanentDeletionStats) -> dict:
    """Structured 409 body for Admin Web (message + retry flags)."""
    return {
        "message": format_incomplete_cleanup_error(stats),
        "account_deleted": False,
        "media_deleted": stats.media_deleted,
        "media_failed": stats.media_failed,
        "storage_deleted": stats.storage_deleted,
        "storage_queued": stats.storage_queued,
        "chains_removed": stats.chains_removed,
        "assignments_removed": stats.assignments_removed,
        "can_retry_storage": stats.storage_queued > 0,
        "partial_failure": True,
    }
