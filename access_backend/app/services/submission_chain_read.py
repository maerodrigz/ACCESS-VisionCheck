"""Read-only submission chain metadata for API responses (Phase 1)."""

from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from app.models.media_file import MediaFile
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import (
    CHAIN_ROLE_REPLACEMENT,
    CHAIN_ROLE_ROOT,
)


def chain_metadata_for_media(db: Session, media: MediaFile | None) -> dict[str, Any]:
    """Backward-compatible optional fields; no XP inference."""
    empty: dict[str, Any] = {
        "submission_chain_id": None,
        "chain_root_media_id": None,
        "replaces_media_id": None,
        "chain_role": None,
        "replacement_lifecycle": None,
        "xp_reconciliation_status": None,
        "active_replacement_media_id": None,
        "awaiting_replacement_media_id": None,
    }
    if media is None:
        return empty

    out = dict(empty)
    out["replaces_media_id"] = media.replaces_media_id
    out["replacement_lifecycle"] = media.replacement_lifecycle

    chain_id = media.submission_chain_id
    if not chain_id:
        return out

    chain = db.get(SubmissionChain, chain_id)
    if chain is None:
        out["submission_chain_id"] = chain_id
        return out

    out["submission_chain_id"] = chain.id
    out["chain_root_media_id"] = chain.root_media_id
    out["xp_reconciliation_status"] = chain.xp_reconciliation_status
    out["active_replacement_media_id"] = chain.active_replacement_media_id
    out["awaiting_replacement_media_id"] = chain.awaiting_replacement_media_id

    if media.replaces_media_id is not None:
        out["chain_role"] = CHAIN_ROLE_REPLACEMENT
    elif media.id == chain.root_media_id:
        out["chain_role"] = CHAIN_ROLE_ROOT
    else:
        out["chain_role"] = CHAIN_ROLE_ROOT

    return out
