"""Admin endpoints for event documentation media (separate from member evaluation workflow)."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.crud import facebook_post as fb_crud
from app.crud import media as media_crud
from app.database import get_db
from app.models.media_constants import (
    APPROVAL_APPROVED,
    APPROVAL_PENDING,
    APPROVAL_REJECTED,
    MEDIA_CATEGORY_EVENT,
)
from app.models.user import User
from app.config import settings, facebook_credentials
from app.crud import system_settings as settings_crud
from app.services.facebook_publish_guard import ensure_facebook_publishing_enabled
from app.services.facebook_service import inspect_page_token, list_page_albums, resolve_page_album_id
from app.services.event_facebook_publish import bulk_publish_event_media
from app.services.supabase_storage import (
    normalize_supabase_storage_url,
    resolve_supabase_storage_urls,
)

router = APIRouter(prefix="/admin/event-media", tags=["Event Media"])


class ApprovalUpdateBody(BaseModel):
    status: str = Field(..., description="approved | rejected")
    rejection_reason: str | None = Field(None, max_length=500)


class MediaCurationUpdateBody(BaseModel):
    is_best_shot: bool | None = None
    album_name_override: str | None = Field(None, max_length=255)


class BulkFacebookPublishBody(BaseModel):
    media_ids: list[int] = Field(..., min_length=1, max_length=50)
    message: str | None = Field(None, max_length=5000)


def _event_media_json(m, file_url: str | None = None) -> dict:
    req = m.request
    resolved = (
        file_url
        if file_url is not None
        else normalize_supabase_storage_url(m.file_url or "")
    )
    return {
        "id": m.id,
        "file_name": m.file_name,
        "file_type": m.file_type,
        "file_url": resolved,
        "request_id": m.request_id,
        "media_category": m.media_category,
        "approval_status": m.approval_status,
        "approval_rejection_reason": m.approval_rejection_reason,
        "facebook_publish_status": m.facebook_publish_status,
        "facebook_post_id": m.facebook_post_id,
        "facebook_published_at": m.facebook_published_at.isoformat() if m.facebook_published_at else None,
        "event_title": req.title if req else None,
        "event_date": req.event_date.isoformat() if req and req.event_date else None,
        "event_description": req.description if req else None,
        "uploaded_by": m.uploaded_by,
        "uploader_name": m.uploader.fullname if m.uploader else "Unknown",
        "uploaded_at": m.uploaded_at.isoformat() if m.uploaded_at else None,
        "is_best_shot": bool(m.is_best_shot),
        "album_name_override": m.album_name_override,
    }


@router.get("")
def list_event_media(
    approval_status: str | None = Query(None),
    facebook_publish_status: str | None = Query(None),
    request_id: int | None = Query(None),
    search: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Event documentation media only — never includes member evaluation uploads."""
    rows = media_crud.list_event_documentation_media(
        db,
        approval_status=approval_status,
        facebook_publish_status=facebook_publish_status,
        request_id=request_id,
        search=search,
    )
    urls = resolve_supabase_storage_urls([m.file_url or "" for m in rows])
    return [_event_media_json(m, file_url=urls[i]) for i, m in enumerate(rows)]


@router.patch("/{media_id}/approval")
def update_event_media_approval(
    media_id: int,
    body: ApprovalUpdateBody,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    media = media_crud.get(db, media_id)
    if not media or media.media_category != MEDIA_CATEGORY_EVENT:
        raise HTTPException(status_code=404, detail="Event documentation media not found")

    status = body.status.strip().lower()
    if status not in (APPROVAL_APPROVED, APPROVAL_REJECTED):
        raise HTTPException(status_code=400, detail="status must be approved or rejected")
    if status == APPROVAL_REJECTED and not (body.rejection_reason or "").strip():
        raise HTTPException(status_code=400, detail="rejection_reason is required when rejecting")

    updated = media_crud.set_approval(
        db,
        media,
        status=status,
        rejection_reason=body.rejection_reason,
    )
    return _event_media_json(updated)


@router.patch("/{media_id}/curation")
def update_event_media_curation(
    media_id: int,
    body: MediaCurationUpdateBody,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    media = media_crud.get(db, media_id)
    if not media or media.media_category != MEDIA_CATEGORY_EVENT:
        raise HTTPException(status_code=404, detail="Event documentation media not found")
    if body.is_best_shot is None and body.album_name_override is None:
        raise HTTPException(status_code=400, detail="No fields to update")
    try:
        updated = media_crud.set_curation(
            db,
            media,
            is_best_shot=body.is_best_shot,
            album_name_override=body.album_name_override,
            update_album=body.album_name_override is not None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _event_media_json(updated)


@router.post("/facebook/publish")
def publish_event_media_to_facebook(
    body: BulkFacebookPublishBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """
    Bulk publish approved event documentation media via Facebook Graph API.
    Continues on individual failures; does not cancel the batch.
    """
    ensure_facebook_publishing_enabled(db)
    return bulk_publish_event_media(
        db,
        media_ids=body.media_ids,
        message=body.message,
        actor=admin,
    )


@router.get("/facebook/status")
def facebook_config_status(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Whether Graph API credentials are set (never returns secret values)."""
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
    token_check = inspect_page_token() if token_set else {"ok": False, "reason": "missing_token"}
    token_ok = bool(token_check.get("ok"))
    graph_ready = page_id_set and token_set and token_ok
    album_id: str | None = None
    album_name: str | None = None
    if graph_ready:
        try:
            album_id = resolve_page_album_id()
            for album in list_page_albums():
                if str(album.get("id")) == album_id:
                    album_name = album.get("name")
                    break
        except Exception:
            album_id = None
    if token_set and not token_ok:
        missing.append("PAGE_ACCESS_TOKEN (wrong type — need Page token from me/accounts)")

    if graph_ready:
        reminder = (
            "Graph API ready. Bulk photos publish as swipeable grid post(s) on your Page feed "
            "(up to 10 photos per post)."
        )
    elif token_set and not token_ok and token_check.get("reason"):
        reminder = str(token_check["reason"])
    else:
        reminder = (
            "Auto-post to your Page needs FACEBOOK_PAGE_ID and FACEBOOK_PAGE_ACCESS_TOKEN in "
            "access_backend/.env (then restart the backend). Without a token, use browser share "
            "to publish one best pick at a time."
        )

    return {
        "configured": graph_ready,
        "browser_share_available": publishing_enabled,
        "publishing_enabled": publishing_enabled,
        "page_id_set": page_id_set,
        "access_token_set": token_set,
        "page_token_valid": token_ok,
        "token_check": token_check,
        "album_id": album_id,
        "album_name": album_name,
        "missing": missing,
        "reminder": reminder,
    }


@router.get("/facebook/history")
def facebook_publish_history(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    rows = fb_crud.list_recent(db, limit=limit)
    out = []
    for row in rows:
        media = media_crud.get(db, row.media_id)
        if not media or media.media_category != MEDIA_CATEGORY_EVENT:
            continue
        out.append(
            {
                "id": row.id,
                "media_id": row.media_id,
                "file_name": media.file_name,
                "event_title": media.request.title if media.request else None,
                "message": row.message,
                "facebook_post_id": row.facebook_post_id,
                "status": row.status,
                "error_message": row.error_message,
                "created_at": row.created_at.isoformat() if row.created_at else None,
                "facebook_published_at": media.facebook_published_at.isoformat()
                if media.facebook_published_at
                else None,
            }
        )
    return out


@router.get("/stats")
def event_media_stats(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    rows = media_crud.list_media(db, media_category=MEDIA_CATEGORY_EVENT)
    pending = sum(1 for r in rows if r.approval_status == APPROVAL_PENDING)
    approved = sum(1 for r in rows if r.approval_status == APPROVAL_APPROVED)
    rejected = sum(1 for r in rows if r.approval_status == APPROVAL_REJECTED)
    not_published = sum(1 for r in rows if r.facebook_publish_status == "not_published")
    published = sum(1 for r in rows if r.facebook_publish_status == "published")
    failed = sum(1 for r in rows if r.facebook_publish_status == "failed")
    return {
        "total": len(rows),
        "pending_approval": pending,
        "approved": approved,
        "rejected": rejected,
        "facebook_not_published": not_published,
        "facebook_published": published,
        "facebook_failed": failed,
    }
