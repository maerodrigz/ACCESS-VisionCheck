"""Chain-scoped ranking XP — at most one award per submission chain."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.crud import member_ranking as ranking_crud
from app.crud.submission_chain import (
    append_chain_event,
    ensure_submission_chain_for_evaluation,
    get_chain_for_media,
    lock_chain,
)
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import (
    XP_RECONCILIATION_NEEDS_MANUAL_REVIEW,
    XP_RECONCILIATION_PENDING,
)

logger = logging.getLogger(__name__)


def apply_chain_xp_award(
    db: Session,
    *,
    media_id: int,
    member_id: int,
    points: int,
) -> int:
    """Award ranking points once per chain; returns points applied (0 if blocked).

    Prefer the submission-chain ledger (``xp_awarded_total`` + ``xp_awarded_at``).
    If no chain is linked yet, attempt to create/recover one for practice
    evaluation media before awarding. Legacy untracked award remains only when
    a chain cannot be established (missing media / non-evaluation).
    """
    if points <= 0:
        return 0

    chain = get_chain_for_media(db, media_id)
    if chain is None:
        chain = _ensure_chain_for_xp_award(db, media_id=media_id, member_id=member_id)

    if chain is None:
        logger.warning(
            "XP award falling back to legacy untracked path media_id=%s member_id=%s points=%s",
            media_id,
            member_id,
            points,
        )
        return _legacy_direct_award(db, media_id, member_id, points)

    return _award_on_chain(
        db,
        chain=chain,
        media_id=media_id,
        member_id=member_id,
        points=points,
    )


def _ensure_chain_for_xp_award(
    db: Session,
    *,
    media_id: int,
    member_id: int,
) -> SubmissionChain | None:
    """Create or recover a practice-evaluation chain for future award tracking."""
    media = db.get(MediaFile, media_id)
    if media is None:
        return None

    chain = ensure_submission_chain_for_evaluation(db, media)
    if chain is not None:
        _align_chain_member(chain, member_id)
        return chain

    # Replacement whose parent never got a chain: create on the root, then link.
    if media.replaces_media_id is not None:
        parent = db.get(MediaFile, media.replaces_media_id)
        if parent is not None:
            chain = ensure_submission_chain_for_evaluation(db, parent)
            if chain is not None:
                media.submission_chain_id = chain.id
                _align_chain_member(chain, member_id)
                return chain

    # Practice evaluation row somehow skipped ensure at upload time.
    if media.media_category == MEDIA_CATEGORY_EVALUATION and media.replaces_media_id is None:
        chain = SubmissionChain(
            root_media_id=media.id,
            member_id=member_id or media.uploaded_by or 0,
            xp_reconciliation_status=XP_RECONCILIATION_PENDING,
        )
        db.add(chain)
        db.flush()
        media.submission_chain_id = chain.id
        _align_chain_member(chain, member_id)
        return chain

    return None


def _align_chain_member(chain: SubmissionChain, member_id: int) -> None:
    current = getattr(chain, "member_id", None)
    if member_id and (not current or current == 0):
        chain.member_id = member_id


def _award_on_chain(
    db: Session,
    *,
    chain: SubmissionChain,
    media_id: int,
    member_id: int,
    points: int,
) -> int:
    chain = lock_chain(db, chain.id)
    if chain.xp_award_locked or chain.xp_awarded_total > 0:
        return 0
    if chain.xp_awarded_media_id is not None:
        return 0

    ev = eval_crud.get_for_media(db, media_id)
    if not ev or not ev.criteria_json:
        return 0
    try:
        data = json.loads(ev.criteria_json)
    except json.JSONDecodeError:
        return 0
    if not isinstance(data, dict):
        return 0
    if data.get("xp_awarded_at_review"):
        return 0

    # Persist ledger fields before / with the points write so monthly XP can see them.
    awarded_at = datetime.now(timezone.utc)
    chain.xp_awarded_total = points
    chain.xp_awarded_media_id = media_id
    chain.xp_award_locked = True
    chain.xp_awarded_at = awarded_at
    _align_chain_member(chain, member_id)

    data["xp_pending"] = False
    data["xp_awarded_at_review"] = True
    data["xp_eligible"] = True
    data["xp_chain_id"] = chain.id
    data["xp_chain_award_role"] = "chain_creditor"
    data["xp_awarded_at"] = awarded_at.isoformat()
    ev.criteria_json = json.dumps(data)

    try:
        ranking_crud.add_points(db, member_id, points)
    except Exception:
        # Roll back in-session ledger markers if the balance write fails.
        chain.xp_awarded_total = 0
        chain.xp_awarded_media_id = None
        chain.xp_award_locked = False
        chain.xp_awarded_at = None
        data["xp_awarded_at_review"] = False
        data["xp_pending"] = True
        data.pop("xp_awarded_at", None)
        data.pop("xp_chain_id", None)
        data.pop("xp_chain_award_role", None)
        ev.criteria_json = json.dumps(data)
        raise

    append_chain_event(
        db,
        chain_id=chain.id,
        event_type="chain_xp_awarded",
        media_id=media_id,
        payload={"points": points, "member_id": member_id, "awarded_at": awarded_at.isoformat()},
    )
    return points


def _legacy_direct_award(db: Session, media_id: int, member_id: int, points: int) -> int:
    """Last-resort award when no evaluation chain can be established.

    Still idempotent via ``xp_awarded_at_review``. Does not create monthly-ledger
    rows (no chain). Prefer ``apply_chain_xp_award`` recovery over this path.
    """
    ev = eval_crud.get_for_media(db, media_id)
    if ev and ev.criteria_json:
        try:
            data = json.loads(ev.criteria_json)
            if isinstance(data, dict) and data.get("xp_awarded_at_review"):
                return 0
        except json.JSONDecodeError:
            pass
    ranking_crud.add_points(db, member_id, points)
    if ev and ev.criteria_json:
        try:
            data = json.loads(ev.criteria_json)
            if isinstance(data, dict):
                data["xp_awarded_at_review"] = True
                data["xp_pending"] = False
                data["xp_award_path"] = "legacy_untracked"
                data["xp_awarded_at"] = datetime.now(timezone.utc).isoformat()
                ev.criteria_json = json.dumps(data)
        except json.JSONDecodeError:
            pass
    return points


def mark_chain_xp_locked_if_paid(db: Session, media_id: int) -> None:
    """Conservative lock when re-upload is requested after explicit prior award."""
    from app.crud.submission_chain import conservative_sync_chain_xp_evidence, get_chain_for_media, lock_chain

    chain = get_chain_for_media(db, media_id)
    if chain is None:
        return
    chain = lock_chain(db, chain.id)
    conservative_sync_chain_xp_evidence(db, chain)
    if chain.xp_awarded_total > 0:
        chain.xp_award_locked = True
    elif chain.xp_award_locked:
        chain.xp_reconciliation_status = XP_RECONCILIATION_NEEDS_MANUAL_REVIEW
