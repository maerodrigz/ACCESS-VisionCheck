"""Deferred practice-evaluation pipeline (Step 7A): bounded worker pool + own DB sessions."""

from __future__ import annotations

import logging
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import TYPE_CHECKING

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.crud import media as media_crud
from app.database import SessionLocal
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.services.media_file_bytes import read_media_file_bytes
from app.services.media_pipeline import _payload_from_preview_metadata, run_pipeline

if TYPE_CHECKING:
    from app.models.media_file import MediaFile

logger = logging.getLogger(__name__)

_executor: ThreadPoolExecutor | None = None
_executor_lock = threading.Lock()
_media_locks_guard = threading.Lock()
_media_locks: dict[int, threading.Lock] = {}


def media_processing_status(media: MediaFile) -> str | None:
    """processing / completed for member evaluation uploads; None for event documentation."""
    if media.media_category != MEDIA_CATEGORY_EVALUATION:
        return None
    if media.evaluations:
        return "completed"
    return "processing"


def _media_job_lock(media_id: int) -> threading.Lock:
    with _media_locks_guard:
        lock = _media_locks.get(media_id)
        if lock is None:
            lock = threading.Lock()
            _media_locks[media_id] = lock
        return lock


def get_media_evaluation_executor() -> ThreadPoolExecutor:
    global _executor
    with _executor_lock:
        if _executor is None:
            from app.config import settings

            workers = max(1, int(settings.max_media_evaluation_workers))
            _executor = ThreadPoolExecutor(max_workers=workers, thread_name_prefix="media-eval")
        return _executor


def schedule_deferred_media_evaluation(
    media_id: int,
    evaluation_metadata: str | None = None,
) -> None:
    """Queue pipeline work on the bounded executor (safe to call from FastAPI BackgroundTasks)."""
    get_media_evaluation_executor().submit(
        run_deferred_media_pipeline_job,
        media_id,
        evaluation_metadata,
    )


def run_deferred_media_pipeline_job(
    media_id: int,
    evaluation_metadata: str | None = None,
) -> None:
    """Worker entry: own DB session, idempotent, no event-loop blocking."""
    with _media_job_lock(media_id):
        db: Session = SessionLocal()
        try:
            media = media_crud.get(db, media_id)
            if media is None:
                logger.warning("deferred pipeline: media_id=%s not found", media_id)
                return
            if media.media_category != MEDIA_CATEGORY_EVALUATION:
                return
            if eval_crud.get_for_media(db, media_id) is not None:
                logger.info("deferred pipeline: media_id=%s already evaluated, skipping", media_id)
                return

            preview = _payload_from_preview_metadata(evaluation_metadata)
            if preview is None:
                file_bytes = read_media_file_bytes(media.file_url, timeout=120.0)
                if not file_bytes:
                    logger.error(
                        "deferred pipeline: could not read stored bytes for media_id=%s url=%s",
                        media_id,
                        media.file_url,
                    )
                    return
            else:
                file_bytes = b""

            result = run_pipeline(
                db,
                media,
                file_bytes,
                evaluation_metadata=evaluation_metadata,
                require_full_analysis=True,
            )
            if result is None:
                db.rollback()
                logger.error(
                    "deferred pipeline: analysis failed for media_id=%s (no evaluation persisted)",
                    media_id,
                )
        except Exception:
            db.rollback()
            logger.exception("deferred pipeline failed for media_id=%s", media_id)
        finally:
            db.close()


def reconcile_pending_media_evaluations() -> int:
    """Startup: requeue evaluation uploads that have MediaFile but no MediaEvaluation."""
    from sqlalchemy import select

    from app.models.media_evaluation import MediaEvaluation
    from app.models.media_file import MediaFile

    db = SessionLocal()
    try:
        rows = db.scalars(
            select(MediaFile.id)
            .outerjoin(MediaEvaluation, MediaEvaluation.media_id == MediaFile.id)
            .where(
                MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
                MediaEvaluation.id.is_(None),
            )
        ).all()
        media_ids = list(rows)
    finally:
        db.close()

    for media_id in media_ids:
        schedule_deferred_media_evaluation(media_id, evaluation_metadata=None)

    if media_ids:
        logger.info("deferred pipeline: reconciled %s pending media evaluation(s)", len(media_ids))
    return len(media_ids)


def shutdown_media_evaluation_executor() -> None:
    """Test helper: wait for queued jobs."""
    global _executor
    with _executor_lock:
        if _executor is not None:
            _executor.shutdown(wait=True)
            _executor = None
