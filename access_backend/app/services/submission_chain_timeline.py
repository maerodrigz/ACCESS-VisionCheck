"""Read-only chain history payloads for member and admin APIs."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.crud import submission_chain as chain_crud
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_event import SubmissionChainEvent
from app.services.submission_chain_read import chain_metadata_for_media


def member_chain_history(db: Session, *, chain: SubmissionChain, member_id: int) -> dict:
    if chain.member_id != member_id:
        raise PermissionError("Chain does not belong to member")
    media_rows = chain_crud.list_chain_media_ordered(db, chain)
    items = []
    for m in media_rows:
        ai = eval_crud.get_ai_for_media(db, m.id)
        meta = chain_metadata_for_media(db, m)
        items.append(
            {
                "media_id": m.id,
                "file_name": m.file_name,
                "file_type": m.file_type,
                "uploaded_at": m.uploaded_at.isoformat() if m.uploaded_at else None,
                "review_status": ai.review_status if ai else None,
                "replaces_media_id": m.replaces_media_id,
                **meta,
            }
        )
    return {
        "chain_id": chain.id,
        "root_media_id": chain.root_media_id,
        "xp_awarded_total": chain.xp_awarded_total,
        "xp_award_locked": chain.xp_award_locked,
        "xp_reconciliation_status": chain.xp_reconciliation_status,
        "active_replacement_media_id": chain.active_replacement_media_id,
        "awaiting_replacement_media_id": chain.awaiting_replacement_media_id,
        "media": items,
    }


def admin_chain_timeline(db: Session, *, chain: SubmissionChain) -> dict:
    base = member_chain_history(db, chain=chain, member_id=chain.member_id)
    events = chain_crud.list_chain_events(db, chain.id)
    base["events"] = [_event_json(e) for e in events]
    for m in base["media"]:
        mid = m["media_id"]
        ai = eval_crud.get_ai_for_media(db, mid)
        m["admin_remarks"] = ai.admin_remarks if ai else None
        ev = eval_crud.get_for_media(db, mid)
        m["evaluation_id"] = ev.id if ev else None
    return base


def _event_json(e: SubmissionChainEvent) -> dict:
    return {
        "id": e.id,
        "event_type": e.event_type,
        "media_id": e.media_id,
        "actor_user_id": e.actor_user_id,
        "payload": e.payload,
        "created_at": e.created_at.isoformat() if e.created_at else None,
    }
