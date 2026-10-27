"""Regression: upload_media must not shadow module-level logging (UnboundLocalError)."""

from __future__ import annotations

import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.api.routes import media as media_routes

SAMPLE_BYTES = b"access-eval-upload-logging-scope"


def _run(coro):
    return asyncio.run(coro)


def test_upload_media_supabase_fallback_uses_module_logging() -> None:
    """Supabase failure logs a warning before optional notify; inner import broke this path."""

    async def invoke() -> None:
        upload = AsyncMock()
        upload.filename = "clip.mp4"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)

        user = SimpleNamespace(id=9)
        db = MagicMock()
        bg = MagicMock()
        row = SimpleNamespace(id=77)

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=True):
                with patch.object(
                    media_routes.settings_crud,
                    "is_ai_media_evaluation_enabled",
                    return_value=True,
                ):
                    with patch.object(media_routes, "assert_evaluation_video_duration"):
                        with patch.object(
                            media_routes.media_crud,
                            "assert_member_evaluation_not_duplicate",
                        ):
                            with patch.object(
                                media_routes, "_member_evaluations_today", return_value=0
                            ):
                                with patch.object(
                                    media_routes,
                                    "evaluation_rules",
                                    return_value={"max_files_per_day": 5},
                                ):
                                    with patch(
                                        "app.services.supabase_storage.is_supabase_storage_configured",
                                        return_value=True,
                                    ):
                                        with patch(
                                            "app.services.supabase_storage.upload_media_bytes",
                                            return_value=None,
                                        ):
                                            with patch(
                                                "app.services.firebase_storage.is_firebase_storage_configured",
                                                return_value=False,
                                            ):
                                                with patch.object(
                                                    media_routes, "_ensure_upload_dir"
                                                ) as ensure_dir:
                                                    dest = MagicMock()
                                                    dest.write_bytes = MagicMock()
                                                    root = MagicMock()
                                                    root.__truediv__ = MagicMock(
                                                        return_value=dest
                                                    )
                                                    ensure_dir.return_value = root
                                                    with patch.object(
                                                        media_routes.media_crud,
                                                        "create",
                                                        return_value=row,
                                                    ):
                                                        with patch.object(
                                                            media_routes.media_crud,
                                                            "get",
                                                            return_value=row,
                                                        ):
                                                            with patch.object(
                                                                media_routes, "_media_out"
                                                            ):
                                                                with patch.object(
                                                                    media_routes,
                                                                    "stash_evaluation_upload",
                                                                ):
                                                                    with patch.object(
                                                                        media_routes.logging,
                                                                        "getLogger",
                                                                    ) as get_logger:
                                                                        logger = MagicMock()
                                                                        get_logger.return_value = (
                                                                            logger
                                                                        )
                                                                        await media_routes.upload_media(
                                                                            background_tasks=bg,
                                                                            file=upload,
                                                                            request_id=None,
                                                                            file_name="VID_test.mp4",
                                                                            evaluation_metadata=None,
                                                                            cloud_file_url=None,
                                                                            db=db,
                                                                            current_user=user,
                                                                        )
                                                                        logger.warning.assert_called_once()

    _run(invoke())


def test_upload_media_does_not_bind_logging_as_local() -> None:
    """Static guard: nested import logging made logging local for the whole function."""
    import inspect

    source = inspect.getsource(media_routes.upload_media)
    assert "import logging" not in source
