"""Async / isolated worker for quality shadow scoring.

Uses a dedicated bounded ThreadPoolExecutor so shadow work never blocks the
HTTP response path or the primary media-eval deferred worker beyond a cheap
schedule() call when the feature flag is on.
"""

from __future__ import annotations

import logging
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_executor: ThreadPoolExecutor | None = None
_executor_lock = threading.Lock()


def get_quality_shadow_executor() -> ThreadPoolExecutor:
    global _executor
    with _executor_lock:
        if _executor is None:
            from app.config import settings

            workers = max(1, int(settings.quality_shadow_max_workers))
            _executor = ThreadPoolExecutor(
                max_workers=workers,
                thread_name_prefix="quality-shadow",
            )
        return _executor


def shutdown_quality_shadow_executor(*, wait: bool = True) -> None:
    """Test / lifespan helper."""
    global _executor
    with _executor_lock:
        if _executor is not None:
            _executor.shutdown(wait=wait)
            _executor = None


def maybe_schedule_quality_shadow(
    *,
    evaluation_id: int | None,
    media_id: int,
    file_bytes: bytes | None,
    is_photo: bool,
) -> bool:
    """Schedule shadow scoring when enabled and eligible.

    Returns True if a job was submitted. When the flag is off, returns False
    without creating the executor or importing TensorFlow / MUSIQ.
    """
    from app.config import settings

    if not settings.quality_shadow_enabled:
        return False
    if not is_photo:
        logger.info("quality shadow: skip non-photo media_id=%s", media_id)
        return False
    if not file_bytes:
        payload = b""
    else:
        # Copy so caller can discard its buffer; avoid sharing mutable memory across threads.
        payload = bytes(file_bytes)

    get_quality_shadow_executor().submit(
        _run_shadow_job,
        evaluation_id,
        media_id,
        payload,
    )
    return True


def _resolve_photo_bytes(media_id: int, content: bytes) -> bytes:
    """Use in-memory copy when present; otherwise reload from upload cache / storage.

    Deferred photo saves often call run_pipeline with empty file_bytes when a trusted
    client quality preview already exists. Shadow still needs image bytes and must not
    substitute Phase 1 research CSV scores.
    """
    if content:
        return content
    try:
        from app.services.upload_bytes_cache import take_evaluation_upload

        cached = take_evaluation_upload(media_id)
        if cached:
            return cached
    except Exception:  # noqa: BLE001
        logger.exception("quality shadow: upload cache read failed media_id=%s", media_id)
    try:
        from app.crud import media as media_crud
        from app.database import SessionLocal
        from app.services.media_file_bytes import read_media_file_bytes

        db = SessionLocal()
        try:
            media = media_crud.get(db, media_id)
            if media is None or not (media.file_url or "").strip():
                return b""
            loaded = read_media_file_bytes(media.file_url, timeout=120.0)
            return loaded or b""
        finally:
            db.close()
    except Exception:  # noqa: BLE001
        logger.exception("quality shadow: storage read failed media_id=%s", media_id)
        return b""


def _run_shadow_job(evaluation_id: int | None, media_id: int, content: bytes) -> None:
    from app.config import settings
    from app.services.quality_shadow.logging_store import append_shadow_record
    from app.services.quality_shadow.scoring import run_shadow_score

    try:
        log_dir = Path(settings.quality_shadow_log_dir)
        if not log_dir.is_absolute():
            from app.config import BACKEND_ROOT

            log_dir = BACKEND_ROOT / log_dir
        cache = (settings.quality_shadow_tfhub_cache_dir or "").strip() or None
        if cache and not Path(cache).is_absolute():
            from app.config import BACKEND_ROOT

            cache = str(BACKEND_ROOT / cache)

        payload = _resolve_photo_bytes(media_id, content)
        record = run_shadow_score(
            content=payload,
            evaluation_id=evaluation_id,
            media_id=media_id,
            anon_salt=settings.quality_shadow_anon_salt or settings.jwt_secret,
            tfhub_cache_dir=cache,
            skip_musiq=False,
        )
        if not payload:
            record["error"] = record.get("error") or "no_image_bytes_after_reload"
        path = append_shadow_record(log_dir, record)
        logger.info(
            "quality shadow: logged evaluation_id=%s status=%s musiq=%s path=%s",
            evaluation_id,
            record.get("status"),
            record.get("musiq_status"),
            path.name,
        )
    except Exception:  # noqa: BLE001
        logger.exception(
            "quality shadow job failed evaluation_id=%s media_id=%s",
            evaluation_id,
            media_id,
        )


def run_shadow_job_sync_for_tests(
    *,
    evaluation_id: int | None,
    media_id: int,
    content: bytes,
) -> dict[str, Any]:
    """Synchronous path for unit tests (no executor)."""
    from app.config import settings
    from app.services.quality_shadow.logging_store import append_shadow_record
    from app.services.quality_shadow.scoring import run_shadow_score

    log_dir = Path(settings.quality_shadow_log_dir)
    if not log_dir.is_absolute():
        from app.config import BACKEND_ROOT

        log_dir = BACKEND_ROOT / log_dir
    record = run_shadow_score(
        content=content,
        evaluation_id=evaluation_id,
        media_id=media_id,
        anon_salt=settings.quality_shadow_anon_salt or settings.jwt_secret,
        tfhub_cache_dir=None,
        skip_musiq=False,
    )
    append_shadow_record(log_dir, record)
    return record
