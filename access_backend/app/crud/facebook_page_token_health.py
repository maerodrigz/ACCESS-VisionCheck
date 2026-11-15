"""CRUD for singleton Facebook Page token health (never stores token values)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.facebook_page_token_health import (
    EXPIRY_UNKNOWN,
    HEALTH_ROW_ID,
    STATUS_UNKNOWN,
    FacebookPageTokenHealth,
)


def get_or_create(db: Session) -> FacebookPageTokenHealth:
    row = db.get(FacebookPageTokenHealth, HEALTH_ROW_ID)
    if row is not None:
        return row
    row = FacebookPageTokenHealth(
        id=HEALTH_ROW_ID,
        connection_status=STATUS_UNKNOWN,
        expiry_visibility=EXPIRY_UNKNOWN,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def save_verification(
    db: Session,
    *,
    connection_status: str,
    page_id: str | None,
    page_name: str | None,
    last_ok: bool,
    last_error: str | None,
    token_expires_at: datetime | None,
    expiry_visibility: str,
    album_id: str | None = None,
    album_name: str | None = None,
) -> FacebookPageTokenHealth:
    row = get_or_create(db)
    row.connection_status = connection_status
    row.page_id = page_id
    row.page_name = page_name
    row.last_verified_at = datetime.now(timezone.utc)
    row.last_ok = last_ok
    row.last_error = last_error
    row.token_expires_at = token_expires_at
    row.expiry_visibility = expiry_visibility
    if album_id is not None:
        row.album_id = album_id
    if album_name is not None:
        row.album_name = album_name
    db.commit()
    db.refresh(row)
    return row


def as_public_dict(row: FacebookPageTokenHealth | None) -> dict:
    if row is None:
        return {
            "connection_status": STATUS_UNKNOWN,
            "page_id": None,
            "page_name": None,
            "last_verified_at": None,
            "last_ok": None,
            "last_error": None,
            "token_expires_at": None,
            "expiry_visibility": EXPIRY_UNKNOWN,
            "expiry_label": "Expiration not confirmed",
            "album_id": None,
            "album_name": None,
        }
    expiry_visibility = (row.expiry_visibility or EXPIRY_UNKNOWN).strip().lower()
    if expiry_visibility == "dated" and row.token_expires_at is not None:
        expiry_label = row.token_expires_at.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    elif expiry_visibility == "never":
        expiry_label = "Never (confirmed by Meta)"
    else:
        expiry_label = "Expiration not confirmed"

    return {
        "connection_status": row.connection_status or STATUS_UNKNOWN,
        "page_id": row.page_id,
        "page_name": row.page_name,
        "last_verified_at": row.last_verified_at.isoformat() if row.last_verified_at else None,
        "last_ok": row.last_ok,
        "last_error": row.last_error,
        "token_expires_at": row.token_expires_at.isoformat() if row.token_expires_at else None,
        "expiry_visibility": expiry_visibility,
        "expiry_label": expiry_label,
        "album_id": row.album_id,
        "album_name": row.album_name,
    }
