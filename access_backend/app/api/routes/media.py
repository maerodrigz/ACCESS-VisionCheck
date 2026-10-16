"""Media uploads and repository."""

import asyncio
import uuid
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import Date, cast, func, select
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import media as media_crud
from app.crud import media as media_crud
from app.crud import system_settings as settings_crud
from app.database import get_db
from app.models.media_file import MediaFile
from app.models.media_constants import (
    APPROVAL_NOT_APPLICABLE,
    FB_NOT_PUBLISHED,
    MEDIA_CATEGORY_EVENT,
    MEDIA_CATEGORY_EVALUATION,
)
from app.models.user import User
from app.schemas.member_api import MediaEvaluateOut, MediaOut
from app.services.deferred_media_pipeline import media_processing_status, schedule_deferred_media_evaluation
from app.services.media_evaluator import evaluate_bytes
from app.services.media_upload_config import (
    assert_evaluation_video_duration,
    evaluation_rules,
    is_allowed_extension,
    is_video_extension,
    rules_for_category,
)

router = APIRouter(prefix="/media", tags=["Media"])


def _ensure_upload_dir() -> Path:
    from app.config import settings

    path = Path(settings.upload_dir)
    path.mkdir(parents=True, exist_ok=True)
    (path / "images").mkdir(exist_ok=True)
    (path / "videos").mkdir(exist_ok=True)
    return path


def _member_evaluations_today(db: Session, user_id: int) -> int:
    return media_crud.count_member_evaluations_today(db, user_id)


def _validate_upload_file(db: Session, ext: str, content: bytes, media_category: str) -> None:
    if not is_allowed_extension(db, ext, media_category):
        rules = rules_for_category(db, media_category)
        allowed = sorted(
            set(rules["allowed_image_formats"]) | set(rules["allowed_video_formats"])
        )
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed extensions: {', '.join(allowed)}",
        )
    rules = rules_for_category(db, media_category)
    max_bytes = int(rules["max_upload_mb"]) * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"File exceeds {rules['max_upload_mb']}MB limit for this workflow.",
        )
    if not content:
        raise HTTPException(status_code=400, detail="Empty file.")


def _media_out(m, base_url: str | None = None) -> MediaOut:
    ev = m.evaluations[-1] if m.evaluations else None
    ai = m.ai_detection_results[-1] if m.ai_detection_results else None
    url = m.file_url
    if base_url and url.startswith("/"):
        url = f"{base_url}{url}"
    return MediaOut(
        id=m.id,
        uploaded_by=m.uploaded_by,
        request_id=m.request_id,
        file_name=m.file_name,
        file_type=m.file_type,
        file_url=url,
        uploaded_at=m.uploaded_at,
        overall_score=ev.overall_score if ev else None,
        ai_detected=ai.detection_result == "ai_generated" if ai else False,
        ai_probability=ai.ai_probability if ai else None,
        feedback=ev.feedback if ev else None,
        processing_status=media_processing_status(m),
    )


@router.get("", response_model=list[MediaOut])
def list_media(
    file_type: str | None = None,
    search: str | None = None,
    mine: bool = False,
    request_id: int | None = None,
    media_category: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    uploaded_by = current_user.id if mine else None
    items = media_crud.list_media(
        db,
        uploaded_by=uploaded_by,
        file_type=file_type,
        search=search,
        request_id=request_id,
        media_category=media_category,
    )
    return [_media_out(m) for m in items]


@router.get("/{media_id}", response_model=MediaOut)
def get_media(
    media_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    m = media_crud.get(db, media_id)
    if not m:
        raise HTTPException(status_code=404, detail="Media not found")
    return _media_out(m)


@router.post("/evaluate", response_model=MediaEvaluateOut)
async def evaluate_media(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    """Quality preview: EfficientNet-B0 + FFmpeg (no DB save, no authenticity model). Gemini via POST /ai/media-evaluation-feedback."""
    _ = current_user
    if not settings_crud.is_ai_media_evaluation_enabled(db):
        raise HTTPException(
            status_code=503,
            detail="AI media evaluation is disabled by the system administrator.",
        )
    ext = Path(file.filename or "").suffix.lower()
    content = await file.read()
    _validate_upload_file(db, ext, content, MEDIA_CATEGORY_EVALUATION)
    is_video = is_video_extension(db, ext, MEDIA_CATEGORY_EVALUATION)
    if is_video:
        assert_evaluation_video_duration(db, ext, content)

    payload = await asyncio.to_thread(
        evaluate_bytes,
        content,
        file_name=file.filename or "upload",
        include_authenticity=False,
    )
    if payload is None:
        raise HTTPException(
            status_code=422,
            detail="Could not analyze this media. Run: python scripts/train_efficientnet_heads.py",
        )

    return MediaEvaluateOut(
        evaluation=payload,
        media_type="video" if is_video else "photo",
        scoring_engine=payload.get("scoring_engine", "efficientnet-b0+ffmpeg"),
    )


@router.post("/upload", response_model=MediaOut)
async def upload_media(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    request_id: int | None = Form(default=None),
    file_name: str | None = Form(None),
    evaluation_metadata: str | None = Form(None),
    cloud_file_url: str | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    ext = Path(file.filename or "").suffix.lower()
    content = await file.read()

    from app.services.supabase_storage import is_supabase_storage_configured, supabase_max_upload_bytes

    if is_supabase_storage_configured() and len(content) > supabase_max_upload_bytes():
        from app.config import settings

        limit = int(settings.supabase_max_upload_mb or 50)
        raise HTTPException(
            status_code=400,
            detail=f"File exceeds storage limit ({limit}MB on Supabase). Use a smaller photo or shorter video.",
        )

    is_event = request_id is not None
    media_category = MEDIA_CATEGORY_EVENT if is_event else MEDIA_CATEGORY_EVALUATION
    _validate_upload_file(db, ext, content, media_category)
    is_video = is_video_extension(db, ext, media_category)
    if media_category == MEDIA_CATEGORY_EVALUATION and is_video:
        assert_evaluation_video_duration(db, ext, content)

    display_name = (file_name or file.filename or "upload").strip()[:255]
    file_type = "video" if is_video else "photo"

    approval_status = APPROVAL_NOT_APPLICABLE

    if media_category == MEDIA_CATEGORY_EVALUATION:
        if not settings_crud.is_ai_media_evaluation_enabled(db):
            raise HTTPException(
                status_code=503,
                detail="AI media evaluation is disabled by the system administrator.",
            )
        eval_rules = evaluation_rules(db)
        daily_limit = int(eval_rules["max_files_per_day"])
        if _member_evaluations_today(db, current_user.id) >= daily_limit:
            raise HTTPException(
                status_code=429,
                detail=f"Daily evaluation limit reached ({daily_limit} uploads per day).",
            )

    cloud = (cloud_file_url or "").strip()
    stored_url: str | None = None

    if cloud.startswith("https://"):
        stored_url = cloud
    else:
        from app.services.supabase_storage import is_supabase_storage_configured, upload_media_bytes as supabase_upload
        from app.services.firebase_storage import is_firebase_storage_configured, upload_media_bytes

        if is_supabase_storage_configured():
            sb_url = supabase_upload(
                content,
                file_name=display_name,
                folder="media",
                user_id=current_user.id,
            )
            if sb_url:
                stored_url = sb_url
        if not stored_url and is_firebase_storage_configured():
            fb_url = upload_media_bytes(
                content,
                file_name=display_name,
                folder="media",
                user_id=current_user.id,
            )
            if fb_url:
                stored_url = fb_url

    if not stored_url:
        upload_root = _ensure_upload_dir()
        sub = "videos" if is_video else "images"
        filename = f"{uuid.uuid4().hex}{ext}"
        rel_path = f"{sub}/{filename}"
        dest = upload_root / rel_path
        dest.write_bytes(content)
        stored_url = f"/uploads/{rel_path}"

    row = media_crud.create(
        db,
        {
            "uploaded_by": current_user.id,
            "request_id": request_id,
            "file_name": display_name,
            "file_type": file_type,
            "file_url": stored_url,
            "media_category": media_category,
            "approval_status": approval_status,
            "facebook_publish_status": FB_NOT_PUBLISHED,
        },
    )
    row = media_crud.get(db, row.id)
    if is_event and request_id is not None:
        from app.services import notification_events as notify_events

        try:
            notify_events.notify_requestor_event_gallery_upload(db, request_id=request_id)
        except Exception:
            import logging

            logging.getLogger(__name__).exception(
                "Requestor gallery notify failed for request %s", request_id
            )
    if media_category == MEDIA_CATEGORY_EVALUATION and settings_crud.is_ai_media_evaluation_enabled(db):
        metadata_copy = evaluation_metadata
        media_id = row.id

        def _enqueue_pipeline() -> None:
            schedule_deferred_media_evaluation(media_id, metadata_copy)

        background_tasks.add_task(_enqueue_pipeline)
    row = media_crud.get(db, row.id)
    return _media_out(row)  # type: ignore[arg-type]
