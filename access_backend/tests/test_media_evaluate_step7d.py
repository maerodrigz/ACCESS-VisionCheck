"""Step 7D: /media/evaluate preview runs off the asyncio event loop."""

from __future__ import annotations

import asyncio
import io
import threading
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from PIL import Image

from app.api.routes import media as media_routes
from app.services.media_evaluator import deferred_authenticity_preview


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), color=(50, 60, 70)).save(buf, format="JPEG")
    return buf.getvalue()


def _run(coro):
    return asyncio.run(coro)


def test_evaluate_media_uses_to_thread() -> None:
    captured: dict[str, object] = {}

    async def fake_to_thread(func, /, *args, **kwargs):
        captured["thread"] = threading.current_thread().name
        captured["func"] = func
        captured["kwargs"] = kwargs
        return {"scoring_engine": "efficientnet-b0+ffmpeg", "criteria": [], "overall_score": 4.0}

    upload = MagicMock()
    upload.filename = "sample.jpg"
    upload.read = AsyncMock(return_value=_jpeg_bytes())
    db = MagicMock()

    async def invoke():
        with patch("app.api.routes.media.asyncio.to_thread", side_effect=fake_to_thread):
            with patch.object(media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True):
                with patch.object(media_routes, "_validate_upload_file"):
                    with patch.object(media_routes, "is_video_extension", return_value=False):
                        return await media_routes.evaluate_media(upload, db=db, current_user=MagicMock())

    out = _run(invoke())
    assert captured["func"].__name__ == "evaluate_bytes"
    assert captured["kwargs"] == {"file_name": "sample.jpg", "include_authenticity": False}
    assert out.media_type == "photo"


def test_evaluate_media_propagates_none_as_422() -> None:
    upload = MagicMock()
    upload.filename = "sample.jpg"
    upload.read = AsyncMock(return_value=_jpeg_bytes())
    db = MagicMock()

    async def invoke():
        with patch("app.api.routes.media.asyncio.to_thread", return_value=None):
            with patch.object(media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True):
                with patch.object(media_routes, "_validate_upload_file"):
                    with patch.object(media_routes, "is_video_extension", return_value=False):
                        await media_routes.evaluate_media(upload, db=db, current_user=MagicMock())

    with pytest.raises(HTTPException) as exc:
        _run(invoke())
    assert exc.value.status_code == 422


def test_evaluate_media_to_thread_runs_sync_work_off_loop() -> None:
    main_thread = threading.current_thread().name
    worker_thread: dict[str, str | None] = {"name": None}

    def sync_eval(*_a, **_k):
        worker_thread["name"] = threading.current_thread().name
        return {
            "scoring_engine": "efficientnet-b0+ffmpeg",
            "ai_detection": deferred_authenticity_preview(),
            "criteria": [{"name": "Sharpness", "score": 4}],
            "overall_score": 4.0,
        }

    upload = MagicMock()
    upload.filename = "clip.mp4"
    upload.read = AsyncMock(return_value=b"video-bytes")
    db = MagicMock()

    async def invoke():
        with patch.object(media_routes, "evaluate_bytes", side_effect=sync_eval):
            with patch.object(media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True):
                with patch.object(media_routes, "_validate_upload_file"):
                    with patch.object(media_routes, "is_video_extension", return_value=True):
                        return await media_routes.evaluate_media(upload, db=db, current_user=MagicMock())

    out = _run(invoke())
    assert worker_thread["name"] is not None
    assert worker_thread["name"] != main_thread
    assert out.media_type == "video"
    assert out.evaluation["ai_detection"]["analysis_status"] == "deferred"


def test_default_detector_probe() -> None:
    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend

    assert settings.ai_detector_backend == "probe"
    assert active_ai_detector_backend() == "probe"
