"""Build safe Facebook Page token health payloads (no token values)."""

from __future__ import annotations

import re
from typing import Any

from sqlalchemy.orm import Session

from app.config import facebook_credentials
from app.crud import facebook_page_token_health as health_crud
from app.crud import system_settings as settings_crud
from app.models.facebook_page_token_health import (
    EXPIRY_UNKNOWN,
    STATUS_CONNECTED,
    STATUS_DISCONNECTED,
    STATUS_NEEDS_ATTENTION,
    STATUS_UNKNOWN,
)
from app.services.facebook_service import inspect_page_token, list_page_albums, resolve_page_album_id

_EAA_RE = re.compile(r"EAA[A-Za-z0-9]+")
_LONG_SECRET_RE = re.compile(r"(?i)(access_token|token|secret)=([^&\s]+)")
_BEARER_RE = re.compile(r"(?i)bearer\s+[A-Za-z0-9._\-]+")


def sanitize_facebook_error(message: str | None) -> str | None:
    if not message:
        return None
    text = str(message)
    text = _EAA_RE.sub("[redacted-token]", text)
    text = _LONG_SECRET_RE.sub(r"\1=[redacted]", text)
    text = _BEARER_RE.sub("Bearer [redacted]", text)
    return text[:500]


def _connection_status(*, page_id_set: bool, token_set: bool, token_ok: bool | None) -> str:
    if not page_id_set and not token_set:
        return STATUS_DISCONNECTED
    if not token_set or not page_id_set:
        return STATUS_DISCONNECTED
    if token_ok is True:
        return STATUS_CONNECTED
    if token_ok is False:
        return STATUS_NEEDS_ATTENTION
    return STATUS_UNKNOWN


def build_status_payload(db: Session, *, live: bool = False) -> dict[str, Any]:
    """
    Safe admin status.

    live=False: config flags + persisted health only (no Graph call).
    live=True: run inspect_page_token once, persist metadata, return updated payload.
    """
    cfg = settings_crud.settings_payload(db)
    publishing_enabled = bool(cfg.get("enable_facebook_publishing", True))
    page_id, page_token = facebook_credentials()
    page_id_set = bool(page_id)
    token_set = bool(page_token)
    missing: list[str] = []
    if not page_id_set:
        missing.append("FACEBOOK_PAGE_ID")
    if not token_set:
        missing.append("FACEBOOK_PAGE_ACCESS_TOKEN")

    health_row = health_crud.get_or_create(db)
    token_check: dict[str, Any] | None = None
    album_id = health_row.album_id
    album_name = health_row.album_name
    page_token_valid: bool | None = health_row.last_ok
    verified_now = False

    if live:
        verified_now = True
        if not token_set:
            token_check = {"ok": False, "reason": "missing_token"}
            err = "FACEBOOK_PAGE_ACCESS_TOKEN is not set."
            health_crud.save_verification(
                db,
                connection_status=_connection_status(
                    page_id_set=page_id_set, token_set=False, token_ok=False
                ),
                page_id=page_id or None,
                page_name=None,
                last_ok=False,
                last_error=err,
                token_expires_at=None,
                expiry_visibility=EXPIRY_UNKNOWN,
                album_id=None,
                album_name=None,
            )
            page_token_valid = False
            album_id = None
            album_name = None
        else:
            token_check = inspect_page_token()
            # Never include raw token fields if a future inspect adds them.
            token_check = {
                k: token_check.get(k)
                for k in ("ok", "reason", "token_subject_id", "token_subject_name")
                if k in token_check
            }
            if token_check.get("reason"):
                token_check["reason"] = sanitize_facebook_error(str(token_check["reason"]))

            token_ok = bool(token_check.get("ok"))
            page_token_valid = token_ok
            subject_id = str(token_check.get("token_subject_id") or "") or None
            subject_name = token_check.get("token_subject_name")
            if isinstance(subject_name, str):
                subject_name = subject_name.strip() or None
            else:
                subject_name = None

            # inspect_page_token does not return Meta expiry — keep unknown.
            expires_at = None
            expiry_visibility = EXPIRY_UNKNOWN

            err = None if token_ok else sanitize_facebook_error(
                str(token_check.get("reason") or "Token validation failed")
            )
            if token_set and not token_ok:
                missing.append("PAGE_ACCESS_TOKEN (wrong type — need Page token from me/accounts)")

            album_id = None
            album_name = None
            if token_ok and page_id_set:
                try:
                    album_id = resolve_page_album_id()
                    for album in list_page_albums():
                        if str(album.get("id")) == album_id:
                            album_name = album.get("name")
                            break
                except Exception as exc:  # noqa: BLE001
                    # Album lookup is optional; keep verification result.
                    err_album = sanitize_facebook_error(str(exc))
                    if err is None:
                        # Soft note only when token itself is ok
                        pass
                    else:
                        err = err or err_album

            health_crud.save_verification(
                db,
                connection_status=_connection_status(
                    page_id_set=page_id_set, token_set=token_set, token_ok=token_ok
                ),
                page_id=subject_id or page_id or None,
                page_name=subject_name,
                last_ok=token_ok,
                last_error=err,
                token_expires_at=expires_at,
                expiry_visibility=expiry_visibility,
                album_id=album_id,
                album_name=album_name,
            )
        health_row = health_crud.get_or_create(db)
    else:
        # Cached path — no Graph. Refresh disconnected flags if env cleared.
        if not token_set or not page_id_set:
            page_token_valid = False if (not token_set or not page_id_set) else page_token_valid

    health = health_crud.as_public_dict(health_row)
    # Prefer live/config page id when health row empty
    if not health.get("page_id") and page_id_set:
        health["page_id"] = page_id

    connection_status = health.get("connection_status") or STATUS_UNKNOWN
    if not live:
        # Recompute status from config + last_ok without Graph
        connection_status = _connection_status(
            page_id_set=page_id_set,
            token_set=token_set,
            token_ok=page_token_valid if health_row.last_verified_at else None,
        )
        health["connection_status"] = connection_status

    graph_ready = bool(page_id_set and token_set and page_token_valid is True)

    if graph_ready:
        reminder = (
            "Graph API ready. Bulk photos publish as swipeable grid post(s) on your Page feed "
            "(up to 10 photos per post)."
        )
    elif token_set and page_token_valid is False and health.get("last_error"):
        reminder = str(health["last_error"])
    elif token_set and health_row.last_verified_at is None:
        reminder = (
            "Facebook Page token is configured but has not been verified yet. "
            "Click Check Connection to validate with Meta."
        )
    else:
        reminder = (
            "Auto-post to your Page needs FACEBOOK_PAGE_ID and FACEBOOK_PAGE_ACCESS_TOKEN in "
            "access_backend/.env (then restart the backend). Without a token, use browser share "
            "to publish one best pick at a time."
        )

    # Safe token_check for clients (never include secrets)
    if token_check is None and health_row.last_verified_at is not None:
        token_check = {
            "ok": bool(health_row.last_ok),
            "reason": health_row.last_error,
            "token_subject_id": health_row.page_id,
            "token_subject_name": health_row.page_name,
        }

    return {
        "configured": graph_ready,
        "browser_share_available": publishing_enabled,
        "publishing_enabled": publishing_enabled,
        "page_id_set": page_id_set,
        "access_token_set": token_set,
        "page_token_valid": page_token_valid,
        "token_check": token_check,
        "album_id": album_id or health.get("album_id"),
        "album_name": album_name or health.get("album_name"),
        "missing": missing,
        "reminder": reminder,
        "health": health,
        "verified_now": verified_now,
        "live_check": live,
    }
