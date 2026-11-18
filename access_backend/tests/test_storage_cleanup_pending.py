"""Pending cloud cleanup stays retryable without exposing storage URLs."""

from __future__ import annotations

import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

from app.api.routes.admin import _media_json
from app.api.routes.evaluations import _evaluation_out_for_row
from app.api.routes.media import remove_practice_media_storage
from app.crud.media import REMOVED_STORAGE_FILE_URL, is_storage_cleanup_pending
from app.services.supabase_storage import member_list_file_url


def _media(**overrides):
    base = {
        "id": 7,
        "uploaded_by": 4,
        "storage_removed_at": None,
        "file_url": "supabase-ref:access-media/private/photo.jpg",
        "submission_chain_id": None,
        "replaces_media_id": None,
        "replacement_lifecycle": None,
        "media_category": "member_evaluation",
        "evaluations": [SimpleNamespace(id=11, overall_score=0.82)],
        "ai_detection_results": [],
        "request": None,
        "uploader": None,
        "request_id": None,
        "file_name": "photo.jpg",
        "file_type": "photo",
        "approval_status": "not_applicable",
        "approval_rejection_reason": None,
        "facebook_publish_status": "not_published",
        "facebook_post_id": None,
        "facebook_published_at": None,
        "is_best_shot": False,
        "album_name_override": None,
        "uploaded_at": datetime(2026, 11, 1, tzinfo=timezone.utc),
    }
    base.update(overrides)
    return SimpleNamespace(**base)


def _evaluation(media):
    return SimpleNamespace(
        id=11,
        media_id=media.id,
        media=media,
        criteria_json="{}",
        overall_score=0.82,
        feedback="kept",
        sharpness_score=0.5,
        brightness_score=0.5,
        contrast_score=0.5,
        blur_score=0.5,
        noise_score=0.5,
        quality_level="Good",
        recommendation="keep",
        evaluated_at=datetime(2026, 11, 1, tzinfo=timezone.utc),
    )


class StorageCleanupPendingTest(unittest.TestCase):
    def test_pending_only_when_flag_set_and_url_is_not_placeholder(self) -> None:
        self.assertFalse(is_storage_cleanup_pending(_media()))
        pending = _media(storage_removed_at=datetime.now(timezone.utc))
        self.assertTrue(is_storage_cleanup_pending(pending))
        done = _media(
            storage_removed_at=datetime.now(timezone.utc),
            file_url=REMOVED_STORAGE_FILE_URL,
        )
        self.assertFalse(is_storage_cleanup_pending(done))

    def test_member_evaluation_hides_private_url_while_pending(self) -> None:
        media = _media(storage_removed_at=datetime.now(timezone.utc))
        ai = SimpleNamespace(
            review_status="verified_human",
            ai_probability=0.12,
            detection_result="human",
            admin_remarks="kept",
        )
        out = _evaluation_out_for_row(MagicMock(), _evaluation(media), ai=ai)
        self.assertTrue(out.storage_removed)
        self.assertTrue(out.storage_cleanup_pending)
        self.assertEqual(out.file_url, "")
        self.assertNotIn("supabase-ref", out.file_url)
        self.assertNotIn("private/photo", out.model_dump_json())
        self.assertEqual(out.overall_score, 0.82)
        self.assertEqual(media.evaluations[0].overall_score, 0.82)

    def test_completed_cleanup_is_not_pending(self) -> None:
        media = _media(
            storage_removed_at=datetime.now(timezone.utc),
            file_url=REMOVED_STORAGE_FILE_URL,
        )
        ai = SimpleNamespace(
            review_status="verified_human",
            ai_probability=0.12,
            detection_result="human",
            admin_remarks=None,
        )
        out = _evaluation_out_for_row(MagicMock(), _evaluation(media), ai=ai)
        self.assertTrue(out.storage_removed)
        self.assertFalse(out.storage_cleanup_pending)
        self.assertEqual(member_list_file_url(media.file_url, storage_removed=True), "")

    def test_other_member_cannot_retry_delete(self) -> None:
        media = _media()
        user = SimpleNamespace(id=99)
        with patch("app.api.routes.media.media_crud.get", return_value=media), patch(
            "app.api.routes.media.media_crud.remove_practice_storage_only"
        ) as remove:
            with self.assertRaises(HTTPException) as caught:
                remove_practice_media_storage(media.id, MagicMock(), user)
        self.assertEqual(caught.exception.status_code, 403)
        remove.assert_not_called()

    def test_admin_distinguishes_pending_and_completed(self) -> None:
        with patch(
            "app.api.routes.admin.normalize_supabase_storage_url",
            side_effect=lambda url: url or "",
        ):
            self._assert_admin_statuses()

    def _assert_admin_statuses(self) -> None:
        pending = _media_json(_media(storage_removed_at=datetime(2026, 11, 2, tzinfo=timezone.utc)))
        self.assertTrue(pending["storage_cleanup_pending"])
        self.assertIsNotNone(pending["storage_removed_at"])
        self.assertIn("private/photo", pending["file_url"])

        completed = _media_json(
            _media(
                storage_removed_at=datetime(2026, 11, 2, tzinfo=timezone.utc),
                file_url=REMOVED_STORAGE_FILE_URL,
            )
        )
        self.assertFalse(completed["storage_cleanup_pending"])
        self.assertIsNotNone(completed["storage_removed_at"])

        active = _media_json(_media())
        self.assertFalse(active["storage_cleanup_pending"])
        self.assertIsNone(active["storage_removed_at"])


if __name__ == "__main__":
    unittest.main()
