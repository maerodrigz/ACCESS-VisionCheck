"""Submission chain CRUD — replacement uploads and XP audit (Phase 2)."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import (
    REPLACEMENT_LIFECYCLE_ACTIVE,
    REPLACEMENT_LIFECYCLE_SUPERSEDED,
    REPLACEMENT_LIFECYCLE_TERMINAL,
    XP_RECONCILIATION_NEEDS_MANUAL_REVIEW,
    XP_RECONCILIATION_PENDING,
)
from app.models.submission_chain_event import SubmissionChainEvent

REUPLOAD_REQUESTED_STATUS = "reupload_requested"

EVENT_REUPLOAD_REQUESTED = "reupload_requested"
EVENT_REPLACEMENT_UPLOADED = "replacement_uploaded"
EVENT_REPLACEMENT_ACCEPTED = "replacement_accepted"
EVENT_REPLACEMENT_REJECTED = "replacement_rejected"
EVENT_CHAIN_XP_AWARDED = "chain_xp_awarded"

REPLACEMENT_REVIEW_ACCEPTED = frozenset({"verified_human", "accepted_with_warning"})
REPLACEMENT_REVIEW_TERMINAL = frozenset(
    {"confirmed_ai_generated", "verified_ai_generated", "rejected"}
)


def member_can_reupload(
    db: Session,
    *,
    member_id: int,
    media: MediaFile,
    chain: SubmissionChain | None,
    ai_review_status: str | None,
) -> bool:
    """Server-authoritative: member may submit one linked replacement for this target."""
    from app.config import settings

    if not settings.replacement_upload_enabled:
        return False
    if media.uploaded_by != member_id:
        return False
    if media.media_category != MEDIA_CATEGORY_EVALUATION:
        return False
    if media.replaces_media_id is not None:
        return False
    if (ai_review_status or "").strip().lower() != REUPLOAD_REQUESTED_STATUS:
        return False
    if chain is None:
        return False
    if chain.active_replacement_media_id is not None:
        return False
    if chain.awaiting_replacement_media_id != media.id:
        return False
    return True


def member_replacement_verified(db: Session, chain: SubmissionChain | None, media: MediaFile) -> bool:
    """True when a superseded replacement exists and the chain re-upload slot is closed."""
    if chain is None or media.id != chain.root_media_id:
        return False
    if chain.active_replacement_media_id is not None:
        return False
    if chain.awaiting_replacement_media_id is not None:
        return False
    for mid in _media_ids_in_chain(db, chain):
        row = db.get(MediaFile, mid)
        if row and row.replacement_lifecycle == REPLACEMENT_LIFECYCLE_SUPERSEDED:
            return True
    return False


class ReplacementUploadError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def append_chain_event(
    db: Session,
    *,
    chain_id: int,
    event_type: str,
    media_id: int | None = None,
    actor_user_id: int | None = None,
    payload: dict | None = None,
) -> SubmissionChainEvent:
    row = SubmissionChainEvent(
        chain_id=chain_id,
        media_id=media_id,
        event_type=event_type,
        payload=json.dumps(payload) if payload else None,
        actor_user_id=actor_user_id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row


def get_chain_for_media(db: Session, media_id: int) -> SubmissionChain | None:
    media = db.get(MediaFile, media_id)
    if media is None:
        return None
    if media.submission_chain_id:
        return db.get(SubmissionChain, media.submission_chain_id)
    return db.scalar(select(SubmissionChain).where(SubmissionChain.root_media_id == media_id))


def ensure_submission_chain_for_evaluation(db: Session, media: MediaFile) -> SubmissionChain | None:
    """Create or link a root submission chain for a practice evaluation upload."""
    if media.media_category != MEDIA_CATEGORY_EVALUATION:
        return None
    if media.replaces_media_id is not None:
        return get_chain_for_media(db, media.replaces_media_id)
    chain = get_chain_for_media(db, media.id)
    if chain is not None:
        if media.submission_chain_id != chain.id:
            media.submission_chain_id = chain.id
        return chain
    chain = SubmissionChain(
        root_media_id=media.id,
        member_id=media.uploaded_by or 0,
        xp_reconciliation_status=XP_RECONCILIATION_PENDING,
    )
    db.add(chain)
    db.flush()
    media.submission_chain_id = chain.id
    return chain


def lock_chain(db: Session, chain_id: int) -> SubmissionChain:
    chain = db.scalar(
        select(SubmissionChain).where(SubmissionChain.id == chain_id).with_for_update()
    )
    if chain is None:
        raise ReplacementUploadError("chain_not_found", "Submission chain not found.", 404)
    return chain


def conservative_sync_chain_xp_evidence(db: Session, chain: SubmissionChain) -> None:
    """Lock chain XP only from explicit evaluation markers — never invent awards."""
    if chain.xp_awarded_total > 0:
        chain.xp_award_locked = True
        return
    media_ids = _media_ids_in_chain(db, chain)
    for mid in media_ids:
        ev = eval_crud.get_for_media(db, mid)
        if not ev or not ev.criteria_json:
            continue
        try:
            data = json.loads(ev.criteria_json)
        except json.JSONDecodeError:
            continue
        if not isinstance(data, dict):
            continue
        if data.get("xp_awarded_at_review") is True:
            points = int(data.get("xp_points_preview") or 0)
            if points <= 0:
                legacy = data.get("legacy") if isinstance(data.get("legacy"), dict) else {}
                points = max(0, int(round(float(legacy.get("overall_score", 0)) * 100)))
            chain.xp_awarded_total = max(chain.xp_awarded_total, points)
            chain.xp_awarded_media_id = mid
            chain.xp_award_locked = True
            if chain.xp_reconciliation_status == XP_RECONCILIATION_PENDING:
                chain.xp_reconciliation_status = XP_RECONCILIATION_NEEDS_MANUAL_REVIEW
            return


def on_active_replacement_review_outcome(
    db: Session,
    *,
    media_id: int,
    review_status: str,
    actor_user_id: int | None = None,
) -> None:
    """Clear active replacement slot when admin resolves the replacement media review."""
    chain = get_chain_for_media(db, media_id)
    if chain is None or chain.active_replacement_media_id != media_id:
        return
    chain = lock_chain(db, chain.id)
    replacement = db.get(MediaFile, media_id)
    if replacement is None or replacement.replacement_lifecycle != REPLACEMENT_LIFECYCLE_ACTIVE:
        return
    status = (review_status or "").strip().lower()
    if status in REPLACEMENT_REVIEW_ACCEPTED:
        replacement.replacement_lifecycle = REPLACEMENT_LIFECYCLE_SUPERSEDED
        chain.active_replacement_media_id = None
        chain.awaiting_replacement_media_id = None
        root_ai = eval_crud.get_ai_for_media(db, chain.root_media_id)
        if root_ai is not None:
            prev_root = (root_ai.review_status or "").strip().lower()
            if prev_root == REUPLOAD_REQUESTED_STATUS:
                root_ai.review_status = status
                root_ai.reviewed_by_admin = True
                root_ai.reviewed_at = datetime.now(timezone.utc)
                if actor_user_id is not None:
                    root_ai.reviewed_by = actor_user_id
        append_chain_event(
            db,
            chain_id=chain.id,
            event_type=EVENT_REPLACEMENT_ACCEPTED,
            media_id=media_id,
            actor_user_id=actor_user_id,
            payload={"review_status": status},
        )
    elif status in REPLACEMENT_REVIEW_TERMINAL:
        replacement.replacement_lifecycle = REPLACEMENT_LIFECYCLE_TERMINAL
        chain.active_replacement_media_id = None
        if chain.awaiting_replacement_media_id is None:
            chain.awaiting_replacement_media_id = chain.root_media_id
        append_chain_event(
            db,
            chain_id=chain.id,
            event_type=EVENT_REPLACEMENT_REJECTED,
            media_id=media_id,
            actor_user_id=actor_user_id,
            payload={"review_status": status},
        )


def on_admin_reupload_requested(db: Session, *, media_id: int, member_id: int | None) -> None:
    chain = get_chain_for_media(db, media_id)
    if chain is None:
        media = db.get(MediaFile, media_id)
        if media is None:
            return
        chain = ensure_submission_chain_for_evaluation(db, media)
        if chain is None:
            return
    chain = lock_chain(db, chain.id)
    if chain.active_replacement_media_id is not None:
        raise ReplacementUploadError(
            "active_replacement_exists",
            "Clear or complete the active replacement before requesting re-upload again.",
            409,
        )
    conservative_sync_chain_xp_evidence(db, chain)
    chain.awaiting_replacement_media_id = media_id
    append_chain_event(
        db,
        chain_id=chain.id,
        event_type=EVENT_REUPLOAD_REQUESTED,
        media_id=media_id,
        payload={"member_id": member_id},
    )


def peek_replacement_target(
    db: Session,
    *,
    member_id: int,
    replaces_media_id: int,
) -> None:
    """Fail-fast checks without row locks (before blob storage)."""
    target = db.get(MediaFile, replaces_media_id)
    if target is None:
        raise ReplacementUploadError("invalid_replacement_target", "Media not found.", 400)
    if target.uploaded_by != member_id:
        raise ReplacementUploadError("invalid_replacement_target", "You do not own this media.", 403)
    if target.media_category != MEDIA_CATEGORY_EVALUATION:
        raise ReplacementUploadError(
            "invalid_replacement_target",
            "Only practice evaluation media can be replaced.",
            400,
        )
    ai = eval_crud.get_ai_for_media(db, replaces_media_id)
    status = (ai.review_status if ai else "") or ""
    if status.strip().lower() != REUPLOAD_REQUESTED_STATUS:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "Administrator has not requested a re-upload for this submission.",
            409,
        )
    chain = get_chain_for_media(db, replaces_media_id)
    if chain is None:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "Administrator has not requested a re-upload for this submission.",
            409,
        )
    if chain.active_replacement_media_id is not None:
        raise ReplacementUploadError(
            "replacement_already_active",
            "A replacement upload is already in progress for this chain.",
            409,
        )
    if chain.awaiting_replacement_media_id != replaces_media_id:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "Administrator has not requested a re-upload for this submission.",
            409,
        )


def validate_replacement_target(
    db: Session,
    *,
    member_id: int,
    replaces_media_id: int,
) -> tuple[MediaFile, SubmissionChain]:
    target = db.get(MediaFile, replaces_media_id)
    if target is None:
        raise ReplacementUploadError("invalid_replacement_target", "Media not found.", 400)
    if target.uploaded_by != member_id:
        raise ReplacementUploadError("invalid_replacement_target", "You do not own this media.", 403)
    if target.media_category != MEDIA_CATEGORY_EVALUATION:
        raise ReplacementUploadError(
            "invalid_replacement_target",
            "Only practice evaluation media can be replaced.",
            400,
        )
    ai = eval_crud.get_ai_for_media(db, replaces_media_id)
    status = (ai.review_status if ai else "") or ""
    if status.strip().lower() != REUPLOAD_REQUESTED_STATUS:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "Administrator has not requested a re-upload for this submission.",
            409,
        )
    chain = get_chain_for_media(db, replaces_media_id)
    if chain is None:
        raise ReplacementUploadError("chain_not_found", "Submission chain not found.", 409)
    chain = lock_chain(db, chain.id)
    awaiting = chain.awaiting_replacement_media_id
    if awaiting is not None and awaiting != replaces_media_id:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "This submission is not the active re-upload target.",
            409,
        )
    if chain.active_replacement_media_id is not None:
        raise ReplacementUploadError(
            "replacement_already_active",
            "A replacement upload is already in progress for this chain.",
            409,
        )
    if awaiting is None or awaiting != replaces_media_id:
        raise ReplacementUploadError(
            "replacement_not_requested",
            "Administrator has not requested a re-upload for this submission.",
            409,
        )
    return target, chain


def attach_replacement_media(
    db: Session,
    *,
    chain: SubmissionChain,
    replacement: MediaFile,
    replaces_media_id: int,
) -> None:
    replacement.replaces_media_id = replaces_media_id
    replacement.submission_chain_id = chain.id
    replacement.replacement_lifecycle = REPLACEMENT_LIFECYCLE_ACTIVE
    chain.active_replacement_media_id = replacement.id
    append_chain_event(
        db,
        chain_id=chain.id,
        event_type=EVENT_REPLACEMENT_UPLOADED,
        media_id=replacement.id,
        payload={"replaces_media_id": replaces_media_id},
    )


def _media_ids_in_chain(db: Session, chain: SubmissionChain) -> list[int]:
    rows = db.scalars(
        select(MediaFile.id).where(
            MediaFile.submission_chain_id == chain.id,
        )
    ).all()
    ids = list(rows)
    if chain.root_media_id not in ids:
        ids.append(chain.root_media_id)
    return ids


def list_chain_media_ordered(db: Session, chain: SubmissionChain) -> list[MediaFile]:
    root_id = chain.root_media_id
    by_id: dict[int, MediaFile] = {}
    for mid in _media_ids_in_chain(db, chain):
        m = db.get(MediaFile, mid)
        if m:
            by_id[m.id] = m
    ordered: list[MediaFile] = []
    current = by_id.get(root_id)
    if current:
        ordered.append(current)
    seen = {root_id}
    while True:
        nxt = next(
            (m for m in by_id.values() if m.replaces_media_id in seen and m.id not in seen),
            None,
        )
        if nxt is None:
            break
        ordered.append(nxt)
        seen.add(nxt.id)
    for m in by_id.values():
        if m.id not in seen:
            ordered.append(m)
    return ordered


def list_chain_events(db: Session, chain_id: int, *, limit: int = 100) -> list[SubmissionChainEvent]:
    return list(
        db.scalars(
            select(SubmissionChainEvent)
            .where(SubmissionChainEvent.chain_id == chain_id)
            .order_by(SubmissionChainEvent.created_at.desc())
            .limit(limit)
        )
    )
