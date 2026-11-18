"""Member practice storage removal for verified and pending practice uploads."""

from __future__ import annotations

import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.crud import media as media_crud
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION


def _media(**overrides):
    base = {
        "id": 7,
        "media_category": MEDIA_CATEGORY_EVALUATION,
        "storage_removed_at": None,
        "file_url": "/uploads/images/practice.jpg",
        "evaluations": [SimpleNamespace(id=1)],
        "ai_detection_results": [],
    }
    base.update(overrides)
    return SimpleNamespace(**base)


class PracticeStorageRemovalVerifiedTest(unittest.TestCase):
    def test_allows_verified_human(self) -> None:
        media = _media(
            ai_detection_results=[
                SimpleNamespace(review_status="verified_human"),
            ]
        )
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once_with("/uploads/images/practice.jpg")
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        self.assertIsInstance(out.storage_removed_at, datetime)
        self.assertEqual(out.storage_removed_at.tzinfo, timezone.utc)
        self.assertEqual(db.commit.call_count, 2)
        self.assertGreaterEqual(len(media.evaluations), 1)

    def test_allows_accepted_with_warning(self) -> None:
        media = _media(
            ai_detection_results=[
                SimpleNamespace(review_status="accepted_with_warning"),
            ]
        )
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once_with("/uploads/images/practice.jpg")
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        self.assertEqual(db.commit.call_count, 2)
        self.assertGreaterEqual(len(media.evaluations), 1)

    def test_allows_pending_review(self) -> None:
        media = _media(
            ai_detection_results=[
                SimpleNamespace(review_status="pending_review"),
            ]
        )
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once_with("/uploads/images/practice.jpg")
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        self.assertIsInstance(out.storage_removed_at, datetime)
        self.assertEqual(out.storage_removed_at.tzinfo, timezone.utc)
        self.assertEqual(db.commit.call_count, 2)
        self.assertGreaterEqual(len(media.evaluations), 1)

    def test_storage_failure_keeps_gallery_flag_and_evaluation(self) -> None:
        media = _media()
        db = MagicMock()
        with patch.object(
            media_crud,
            "_delete_media_file_from_disk",
            side_effect=RuntimeError("supabase down"),
        ):
            with self.assertRaises(RuntimeError):
                media_crud.remove_practice_storage_only(db, media)
        self.assertIsNotNone(media.storage_removed_at)
        self.assertEqual(media.file_url, "/uploads/images/practice.jpg")
        self.assertEqual(len(media.evaluations), 1)
        db.commit.assert_called_once()

    def test_retry_deletes_blob_after_gallery_flag(self) -> None:
        media = _media(storage_removed_at=datetime.now(timezone.utc))
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once_with("/uploads/images/practice.jpg")
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        db.commit.assert_called_once()

    def test_does_not_delete_blob_before_evaluation_exists(self) -> None:
        media = _media(evaluations=[])
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            with self.assertRaises(ValueError):
                media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_not_called()
        self.assertIsNone(media.storage_removed_at)
        db.commit.assert_not_called()

    def test_member_media_list_hides_removed_storage(self) -> None:
        captured: dict[str, object] = {}
        db = MagicMock()

        def scalars(query):
            captured["query"] = query
            result = MagicMock()
            result.unique.return_value = []
            return result

        db.scalars.side_effect = scalars
        media_crud.list_media(db, include_storage_removed=False)
        sql = str(captured["query"])
        self.assertIn("storage_removed_at IS NULL", sql)

        captured.clear()
        media_crud.list_media(db, include_storage_removed=True)
        admin_sql = str(captured["query"])
        self.assertNotIn("storage_removed_at IS NULL", admin_sql)


if __name__ == "__main__":
    unittest.main()
