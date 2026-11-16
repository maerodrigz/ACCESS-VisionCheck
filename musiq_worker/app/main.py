"""MUSIQ + OpenCV quality worker HTTP API."""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, status

from app import __version__
from app.auth import require_worker_token
from app.config import apply_runtime_env, get_settings
from app.evaluate import evaluate_photo_bytes, evaluate_video_bytes
from app.musiq_engine import (
    MUSIQ_MODEL_ID,
    MUSIQ_MODEL_VERSION,
    engine_handle,
    is_ready,
    load_error,
    load_musiq,
)

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    apply_runtime_env(settings)
    if settings.preload_musiq:
        logger.info("Preloading MUSIQ into %s", settings.tfhub_cache_dir)
        await asyncio.to_thread(
            load_musiq,
            tfhub_cache_dir=settings.tfhub_cache_dir,
            handle=settings.musiq_handle,
        )
    yield


app = FastAPI(
    title="ACCESS VisionCheck MUSIQ Worker",
    version=__version__,
    lifespan=lifespan,
)


@app.get("/health")
def health() -> dict[str, Any]:
    """Liveness: process is up (MUSIQ may still be loading)."""
    return {
        "status": "ok",
        "service": "musiq-worker",
        "version": __version__,
        "musiq_ready": is_ready(),
    }


@app.get("/ready")
def ready() -> dict[str, Any]:
    """Readiness: MUSIQ SavedModel is loaded and callable."""
    if not is_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "not_ready",
                "musiq_ready": False,
                "error": load_error() or "MUSIQ not loaded",
                "model_id": MUSIQ_MODEL_ID,
            },
        )
    return {
        "status": "ready",
        "musiq_ready": True,
        "model_id": MUSIQ_MODEL_ID,
        "model_version": MUSIQ_MODEL_VERSION,
        "engine_handle": engine_handle(),
    }


@app.post("/v1/evaluate", dependencies=[Depends(require_worker_token)])
async def evaluate(
    file: UploadFile = File(...),
    media_type: str = Form(default="photo"),
    file_ext: str = Form(default=""),
) -> dict[str, Any]:
    """Score photo or video bytes. Auth required. Never invents MUSIQ scores."""
    settings = get_settings()
    media_type_norm = (media_type or "photo").strip().lower()
    if media_type_norm not in ("photo", "image", "video"):
        raise HTTPException(status_code=400, detail="media_type must be photo or video")

    content = await file.read()
    if media_type_norm == "video":
        if len(content) > settings.max_video_bytes:
            raise HTTPException(status_code=413, detail="video exceeds MAX_VIDEO_BYTES")
    else:
        if len(content) > settings.max_image_bytes:
            raise HTTPException(status_code=413, detail="image exceeds MAX_IMAGE_BYTES")

    async def _run() -> dict[str, Any]:
        if media_type_norm == "video":
            ext = file_ext or (file.filename or "")
            if "." in ext and not ext.startswith("."):
                ext = "." + ext.rsplit(".", 1)[-1]
            return await asyncio.to_thread(
                evaluate_video_bytes,
                content,
                ext=ext or ".mp4",
                max_frames=settings.video_sample_frames,
            )
        return await asyncio.to_thread(evaluate_photo_bytes, content)

    try:
        result = await asyncio.wait_for(_run(), timeout=settings.request_timeout_sec)
    except asyncio.TimeoutError as exc:
        raise HTTPException(
            status_code=504,
            detail="worker evaluation timed out",
        ) from exc

    result["worker_version"] = __version__
    result["filename"] = file.filename
    return result
