from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_approved
from app.crud import audit_log as audit_crud
from app.crud import facebook_post as fb_crud
from app.crud import media as media_crud
from app.database import get_db
from app.models.user import User
from app.config import settings
from app.models.media_constants import MEDIA_CATEGORY_EVENT
from app.services.facebook_publish_guard import ensure_facebook_publishing_enabled
from app.services import facebook_service
from app.services.facebook_service import FacebookServiceError, resolve_image_source

router = APIRouter(prefix="/facebook", tags=["Facebook"])


class FacebookShareBody(BaseModel):
    media_id: int
    message: str | None = Field(default=None, max_length=5000)
    mode: str = Field(default="browser", description="browser | api")


class FacebookShareOpenedBody(BaseModel):
    media_id: int
    message: str | None = Field(default=None, max_length=5000)
    share_url: str | None = Field(default=None, max_length=2000)


def _post_out(row) -> dict:
    return {
        "id": row.id,
        "media_id": row.media_id,
        "message": row.message,
        "facebook_post_id": row.facebook_post_id,
        "status": row.status,
        "error_message": row.error_message,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def _ensure_event_publishable(media) -> None:
    if getattr(media, "media_category", None) != MEDIA_CATEGORY_EVENT:
        raise HTTPException(
            status_code=403,
            detail="Facebook publishing is only available for event documentation media.",
        )
    if media.approval_status == "rejected":
        raise HTTPException(status_code=403, detail="Rejected event media cannot be published to Facebook.")


def _share_media(
    db: Session,
    *,
    media_id: int,
    message: str | None,
    actor: User,
) -> dict:
    media = media_crud.get(db, media_id)
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")
    _ensure_event_publishable(media)

    default_message = message or f"{media.file_name} — ACCESS VisionCheck"
    row = fb_crud.create_attempt(db, media_id=media_id, message=default_message)

    public_url, local_path = resolve_image_source(media.file_url, media.file_type)

    try:
        fb_id = facebook_service.post_to_facebook(
            default_message,
            image_url=public_url,
            local_path=local_path,
        )
        row = fb_crud.mark_success(db, row, fb_id)
        audit_crud.create(
            db,
            user_id=actor.id,
            action="facebook_share",
            description=f"Posted media {media_id} to Facebook as {fb_id}",
        )
        return _post_out(row)
    except FacebookServiceError as exc:
        fb_crud.mark_failed(db, row, str(exc))
        status = 400
        if exc.code in ("missing_token", "invalid_page_id"):
            status = 503
        elif exc.code == "graph_api_error":
            status = 502
        elif exc.code == "image_unreachable":
            status = 400
        raise HTTPException(status_code=status, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        fb_crud.mark_failed(db, row, str(exc))
        raise HTTPException(status_code=500, detail="Backend error while posting to Facebook.") from exc


def _share_via_browser(
    db: Session,
    *,
    media_id: int,
    message: str | None,
    actor: User,
    share_url: str | None,
) -> dict:
    media = media_crud.get(db, media_id)
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")
    _ensure_event_publishable(media)
    default_message = message or f"{media.file_name} — ACCESS VisionCheck"
    row = fb_crud.create_attempt(db, media_id=media_id, message=default_message)
    row = fb_crud.mark_opened_in_browser(db, row)
    audit_crud.create(
        db,
        user_id=actor.id,
        action="facebook_share_browser",
        description=f"Opened Facebook share for media {media_id}",
    )
    public, _ = resolve_image_source(media.file_url, media.file_type)
    link = share_url or public or ""
    page_id = (settings.facebook_page_id or "").strip()
    page_link = f"https://www.facebook.com/profile.php?id={page_id}" if page_id else ""
    return {
        **_post_out(row),
        "share_url": link,
        "facebook_sharer_url": (
            f"https://www.facebook.com/sharer/sharer.php?u={link}" if link else ""
        ),
        "facebook_page_url": page_link,
    }


@router.post("/share/opened")
def log_facebook_share_opened(
    body: FacebookShareOpenedBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    """Log that the user opened Facebook to share (no Graph API / token)."""
    ensure_facebook_publishing_enabled(db)
    return _share_via_browser(
        db,
        media_id=body.media_id,
        message=body.message,
        actor=current_user,
        share_url=body.share_url,
    )


@router.post("/share")
def share_to_facebook(
    body: FacebookShareBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    """Share media: default opens browser flow; use mode=api for server Graph API post."""
    ensure_facebook_publishing_enabled(db)
    if body.mode.strip().lower() == "api":
        token = (settings.facebook_page_access_token or "").strip()
        if not token:
            raise HTTPException(
                status_code=503,
                detail="FACEBOOK_PAGE_ACCESS_TOKEN is not set. Use browser share or add token to .env.",
            )
        return _share_media(db, media_id=body.media_id, message=body.message, actor=current_user)
    return _share_via_browser(
        db,
        media_id=body.media_id,
        message=body.message,
        actor=current_user,
        share_url=None,
    )

