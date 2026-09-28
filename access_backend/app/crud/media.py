"""media_files CRUD."""

from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import Date, cast, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.config import settings

from app.models.documentation_request import DocumentationRequest
from app.models.media_constants import (
    APPROVAL_APPROVED,
    APPROVAL_PENDING,
    APPROVAL_REJECTED,
    FB_FAILED,
    FB_NOT_PUBLISHED,
    FB_PUBLISHED,
    FB_PUBLISHING,
    MEDIA_CATEGORY_EVALUATION,
    MEDIA_CATEGORY_EVENT,
)
from app.models.archive import Archive
from app.models.media_file import MediaFile


def count_member_evaluations_today(db: Session, user_id: int) -> int:
    """Practice evaluation uploads today (UTC) — same rule as POST /media daily cap."""
    today = datetime.now(timezone.utc).date()
    return (
        db.scalar(
            select(func.count())
            .select_from(MediaFile)
            .where(
                MediaFile.uploaded_by == user_id,
                MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
                cast(MediaFile.uploaded_at, Date) == today,
            )
        )
        or 0
    )


def list_media(
    db: Session,
    *,
    uploaded_by: int | None = None,
    file_type: str | None = None,
    search: str | None = None,
    request_id: int | None = None,
    media_category: str | None = None,
    approval_status: str | None = None,
    facebook_publish_status: str | None = None,
    exclude_archived: bool = True,
) -> list[MediaFile]:
    q = select(MediaFile).options(
        joinedload(MediaFile.evaluations),
        joinedload(MediaFile.ai_detection_results),
        joinedload(MediaFile.uploader),
        joinedload(MediaFile.request),
    )
    if uploaded_by is not None:
        q = q.where(MediaFile.uploaded_by == uploaded_by)
    if file_type:
        q = q.where(MediaFile.file_type == file_type)
    if request_id is not None:
        q = q.where(MediaFile.request_id == request_id)
    if media_category:
        q = q.where(MediaFile.media_category == media_category)
    if approval_status:
        q = q.where(MediaFile.approval_status == approval_status)
    if facebook_publish_status:
        q = q.where(MediaFile.facebook_publish_status == facebook_publish_status)
    if search:
        term = f"%{search.strip()}%"
        q = q.where(or_(MediaFile.file_name.ilike(term), MediaFile.file_type.ilike(term)))
    if exclude_archived:
        archived_ids = select(Archive.media_id)
        q = q.where(~MediaFile.id.in_(archived_ids))
    q = q.order_by(MediaFile.uploaded_at.desc())
    return list(db.scalars(q).unique())


def list_approved_event_gallery(
    db: Session,
    *,
    file_type: str | None = None,
    search: str | None = None,
    limit: int | None = None,
    offset: int = 0,
) -> list[MediaFile]:
    """Approved event documentation media linked to approved requests."""
    q = (
        select(MediaFile)
        .options(
            joinedload(MediaFile.uploader),
            joinedload(MediaFile.request),
        )
        .join(DocumentationRequest, MediaFile.request_id == DocumentationRequest.id)
        .where(MediaFile.media_category == MEDIA_CATEGORY_EVENT)
        .where(MediaFile.approval_status != APPROVAL_REJECTED)
        .where(MediaFile.request_id.isnot(None))
        .where(DocumentationRequest.status == "approved")
    )
    if file_type:
        q = q.where(MediaFile.file_type == file_type)
    if search:
        term = f"%{search.strip()}%"
        q = q.where(
            or_(
                MediaFile.file_name.ilike(term),
                DocumentationRequest.title.ilike(term),
            )
        )
    q = q.order_by(MediaFile.uploaded_at.desc())
    if limit is not None:
        q = q.limit(limit).offset(offset)
    return list(db.scalars(q).unique())


def gallery_media_json(m: MediaFile, base_url: str | None = None) -> dict:
    """Member gallery payload — excludes evaluation scores and AI metadata."""
    req = m.request
    if req is None or m.request_id is None:
        raise ValueError("Gallery media must be linked to a documentation request")
    url = m.file_url
    if base_url and url.startswith("/"):
        url = f"{base_url}{url}"
    return {
        "id": m.id,
        "request_id": m.request_id,
        "file_name": m.file_name,
        "file_type": m.file_type,
        "file_url": url,
        "uploaded_at": m.uploaded_at,
        "event_title": req.title,
        "event_date": req.event_date,
        "event_description": (req.description or "").strip() or None,
        "facebook_publish_status": m.facebook_publish_status,
        "facebook_post_id": m.facebook_post_id
        if m.facebook_publish_status == "published"
        else None,
    }


def get(db: Session, media_id: int) -> MediaFile | None:
    return db.scalar(
        select(MediaFile)
        .options(
            joinedload(MediaFile.evaluations),
            joinedload(MediaFile.ai_detection_results),
            joinedload(MediaFile.comments),
            joinedload(MediaFile.request),
        )
        .where(MediaFile.id == media_id)
    )


def _delete_media_file_from_disk(file_url: str | None) -> None:
    if not file_url or not file_url.strip():
        return
    from app.services.firebase_storage import delete_firebase_url

    if delete_firebase_url(file_url):
        return
    url = file_url.strip()
    if url.startswith("http://") or url.startswith("https://"):
        return
    rel = url.lstrip("/")
    if rel.startswith("uploads/"):
        rel = rel[len("uploads/") :]
    local = Path(settings.upload_dir) / rel
    if local.is_file():
        local.unlink(missing_ok=True)


def delete_media(db: Session, media: MediaFile) -> None:
    _delete_media_file_from_disk(media.file_url)
    try:
        db.delete(media)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise RuntimeError(
            "This file is linked to other records and could not be deleted. "
            "Try archiving it instead, or remove related evaluations first."
        ) from exc


def create(db: Session, data: dict) -> MediaFile:
    row = MediaFile(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return get(db, row.id)  # type: ignore[arg-type]


def set_approval(
    db: Session,
    media: MediaFile,
    *,
    status: str,
    rejection_reason: str | None = None,
) -> MediaFile:
    media.approval_status = status
    media.approval_rejection_reason = rejection_reason if status == APPROVAL_REJECTED else None
    db.commit()
    db.refresh(media)
    return media


def set_facebook_publish_status(
    db: Session,
    media: MediaFile,
    *,
    status: str,
    facebook_post_id: str | None = None,
    error: str | None = None,
) -> MediaFile:
    media.facebook_publish_status = status
    if status == FB_PUBLISHING:
        pass
    elif status == FB_PUBLISHED:
        media.facebook_post_id = facebook_post_id
        media.facebook_published_at = datetime.now(timezone.utc)
        media.is_best_shot = False
    elif status == FB_FAILED:
        if error:
            media.approval_rejection_reason = media.approval_rejection_reason  # no-op preserve
    elif status == FB_NOT_PUBLISHED:
        media.facebook_post_id = None
        media.facebook_published_at = None
    db.commit()
    db.refresh(media)
    return media


def set_curation(
    db: Session,
    media: MediaFile,
    *,
    is_best_shot: bool | None = None,
    album_name_override: str | None = None,
    update_album: bool = False,
) -> MediaFile:
    if is_best_shot is not None:
        if media.facebook_publish_status == FB_PUBLISHED and is_best_shot:
            raise ValueError("Published media cannot be marked as a best pick.")
        media.is_best_shot = is_best_shot
    if update_album:
        media.album_name_override = (album_name_override or "").strip() or None
    db.commit()
    db.refresh(media)
    return media


def is_event_documentation_publishable(media: MediaFile) -> bool:
    return (
        media.media_category == MEDIA_CATEGORY_EVENT
        and media.approval_status != APPROVAL_REJECTED
        and media.is_best_shot
        and media.facebook_publish_status in (FB_NOT_PUBLISHED, FB_FAILED)
    )
