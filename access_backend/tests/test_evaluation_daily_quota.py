"""Daily practice evaluation upload quota (server-side, Asia/Manila calendar day)."""

from __future__ import annotations

import unittest
from datetime import date, datetime, timezone
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from zoneinfo import ZoneInfo

import pytest
from fastapi import HTTPException

from app.crud.system_settings import DEFAULTS
from app.services.media_upload_config import evaluation_rules


SAMPLE_BYTES = b"access-daily-quota-eval-bytes"


def _mock_media_row(**overrides):
    base = {
        "id": 99,
        "uploaded_by": 42,
        "request_id": None,
        "file_name": "Practice title",
        "file_type": "photo",
        "file_url": "/uploads/images/x.jpg",
        "uploaded_at": datetime.now(timezone.utc),
        "evaluations": [],
        "ai_detection_results": [],
        "storage_removed_at": None,
        "media_category": "member_evaluation",
    }
    base.update(overrides)
    return SimpleNamespace(**base)


class EvaluationDailyQuotaDefaultsTest(unittest.TestCase):
    def test_system_settings_default_is_three(self) -> None:
        self.assertEqual(DEFAULTS["max_evaluation_uploads_per_day"], 3)

    def test_evaluation_rules_fallback_max_files_per_day(self) -> None:
        db = MagicMock()
        with patch(
            "app.services.media_upload_config._cfg",
            return_value={"max_evaluation_uploads_per_day": None},
        ):
            rules = evaluation_rules(db)
        self.assertEqual(rules["max_files_per_day"], 3)


class EvaluationCalendarDateTest(unittest.TestCase):
    def test_manila_calendar_day_ahead_of_utc_near_midnight(self) -> None:
        utc_late = datetime(2026, 6, 1, 18, 30, tzinfo=timezone.utc)
        manila = utc_late.astimezone(ZoneInfo("Asia/Manila")).date()
        self.assertEqual(manila, date(2026, 6, 2))


class UploadRouteDailyQuotaTest(unittest.IsolatedAsyncioTestCase):
    async def _attempt_upload(self, *, count_today_side_effect):
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "photo.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)

        user = SimpleNamespace(id=42)
        db = MagicMock()
        bg = MagicMock()
        daily_limit = 3

        count_mock = MagicMock(side_effect=count_today_side_effect)

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud,
                    "is_ai_media_evaluation_enabled",
                    return_value=True,
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                    ):
                        with patch.object(media_routes, "_member_evaluations_today", count_mock):
                            with patch.object(
                                media_routes,
                                "evaluation_rules",
                                return_value={"max_files_per_day": daily_limit},
                            ):
                                with patch(
                                    "app.services.supabase_storage.is_supabase_storage_configured",
                                    return_value=False,
                                ):
                                    with patch(
                                        "app.services.firebase_storage.is_firebase_storage_configured",
                                        return_value=False,
                                    ):
                                        with patch.object(media_routes, "_ensure_upload_dir") as ensure_dir:
                                            tmp = MagicMock()
                                            tmp.__truediv__ = MagicMock(
                                                return_value=MagicMock(write_bytes=MagicMock())
                                            )
                                            ensure_dir.return_value = tmp
                                            with patch.object(
                                                media_routes.media_crud,
                                                "create",
                                                return_value=SimpleNamespace(id=99),
                                            ) as create_mock:
                                                with patch.object(
                                                    media_routes.media_crud,
                                                    "get",
                                                    return_value=_mock_media_row(),
                                                ):
                                                    with patch.object(media_routes, "_media_out"):
                                                        with patch.object(
                                                            media_routes, "stash_evaluation_upload"
                                                        ):
                                                            with patch(
                                                                "app.crud.submission_chain.ensure_submission_chain_for_evaluation"
                                                            ):
                                                                await media_routes.upload_media(
                                                                background_tasks=bg,
                                                                file=upload,
                                                                request_id=None,
                                                                file_name="Practice title",
                                                                evaluation_metadata=None,
                                                                cloud_file_url=None,
                                                                replaces_media_id=None,
                                                                db=db,
                                                                current_user=user,
                                                            )
                                                            return create_mock, count_mock

    async def test_next_day_reset_allows_upload_when_count_is_zero(self) -> None:
        create_mock, _ = await self._attempt_upload(count_today_side_effect=[0, 1])
        create_mock.assert_called_once()

    async def test_third_upload_allowed_when_two_already_today(self) -> None:
        create_mock, count_mock = await self._attempt_upload(count_today_side_effect=[2, 3])
        create_mock.assert_called_once()
        self.assertGreaterEqual(count_mock.call_count, 1)

    async def test_fourth_upload_blocked_before_insert(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "photo.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)
        user = SimpleNamespace(id=42)
        db = MagicMock()

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud,
                    "is_ai_media_evaluation_enabled",
                    return_value=True,
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                    ):
                        with patch.object(media_routes, "_member_evaluations_today", return_value=3):
                            with patch.object(
                                media_routes,
                                "evaluation_rules",
                                return_value={"max_files_per_day": 3},
                            ):
                                with pytest.raises(HTTPException) as exc:
                                    await media_routes.upload_media(
                                        background_tasks=MagicMock(),
                                        file=upload,
                                        request_id=None,
                                        file_name="Practice title",
                                        evaluation_metadata=None,
                                        cloud_file_url=None,
                                        replaces_media_id=None,
                                        db=db,
                                        current_user=user,
                                    )
        self.assertEqual(exc.value.status_code, 429)
        self.assertIn("3 uploads per day", exc.value.detail)

    async def test_concurrent_race_rolls_back_after_insert(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "photo.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)
        user = SimpleNamespace(id=42)
        db = MagicMock()

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud,
                    "is_ai_media_evaluation_enabled",
                    return_value=True,
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                    ):
                        with patch.object(
                            media_routes,
                            "_member_evaluations_today",
                            side_effect=[2, 4],
                        ):
                            with patch.object(
                                media_routes,
                                "evaluation_rules",
                                return_value={"max_files_per_day": 3},
                            ):
                                with patch(
                                    "app.services.supabase_storage.is_supabase_storage_configured",
                                    return_value=False,
                                ):
                                    with patch(
                                        "app.services.firebase_storage.is_firebase_storage_configured",
                                        return_value=False,
                                    ):
                                        with patch.object(media_routes, "_ensure_upload_dir") as ensure_dir:
                                            tmp = MagicMock()
                                            tmp.__truediv__ = MagicMock(
                                                return_value=MagicMock(write_bytes=MagicMock())
                                            )
                                            ensure_dir.return_value = tmp
                                            with patch.object(
                                                media_routes.media_crud,
                                                "create",
                                                return_value=SimpleNamespace(id=99),
                                            ):
                                                with patch.object(
                                                    media_routes.media_crud,
                                                    "delete_media",
                                                ) as delete_mock:
                                                    with patch.object(
                                                        media_routes.media_crud,
                                                        "discard_stored_upload_blob",
                                                    ):
                                                        with pytest.raises(HTTPException) as exc:
                                                            await media_routes.upload_media(
                                                                background_tasks=MagicMock(),
                                                                file=upload,
                                                                request_id=None,
                                                                file_name="Practice title",
                                                                evaluation_metadata=None,
                                                                cloud_file_url=None,
                                                                replaces_media_id=None,
                                                                db=db,
                                                                current_user=user,
                                                            )
        self.assertEqual(exc.value.status_code, 429)
        delete_mock.assert_called_once()


class CountMemberEvaluationsTodaySemanticsTest(unittest.TestCase):
    def test_counts_all_member_evaluation_media_for_calendar_day(self) -> None:
        """Quota counts uploads (any outcome), not skill-eligible-only."""
        from app.crud import media as media_crud

        db = MagicMock()
        db.scalar.return_value = 2
        with patch("app.crud.media.evaluation_calendar_date", return_value=date(2026, 11, 3)):
            count = media_crud.count_member_evaluations_today(db, user_id=7)
        self.assertEqual(count, 2)
        compiled = str(db.scalar.call_args[0][0])
        self.assertIn("media_category", compiled)
        self.assertIn("uploaded_by", compiled)


if __name__ == "__main__":
    unittest.main()
