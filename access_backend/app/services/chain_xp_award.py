"""Chain-scoped ranking XP — at most one award per submission chain."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.crud import member_ranking as ranking_crud
from app.crud.submission_chain import append_chain_event, get_chain_for_media, lock_chain
from app.models.submission_chain_constants import XP_RECONCILIATION_NEEDS_MANUAL_REVIEW


def apply_chain_xp_award(
    db: Session,
    *,
    media_id: int,
    member_id: int,
    points: int,
) -> int:
    """Award ranking points once per chain; returns points applied (0 if blocked)."""
    if points <= 0:
        return 0

    chain = get_chain_for_media(db, media_id)
    if chain is None:
        return _legacy_direct_award(db, media_id, member_id, points)

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

    ranking_crud.add_points(db, member_id, points)
    chain.xp_awarded_total = points
    chain.xp_awarded_media_id = media_id
    chain.xp_award_locked = True
    chain.xp_awarded_at = datetime.now(timezone.utc)

    data["xp_pending"] = False
    data["xp_awarded_at_review"] = True
    data["xp_eligible"] = True
    data["xp_chain_id"] = chain.id
    data["xp_chain_award_role"] = "chain_creditor"
    ev.criteria_json = json.dumps(data)

    append_chain_event(
        db,
        chain_id=chain.id,
        event_type="chain_xp_awarded",
        media_id=media_id,
        payload={"points": points, "member_id": member_id},
    )
    return points


def _legacy_direct_award(db: Session, media_id: int, member_id: int, points: int) -> int:
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
