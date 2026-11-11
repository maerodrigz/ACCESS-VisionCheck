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
        delete_disk.assert_called_once()
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        self.assertIsInstance(out.storage_removed_at, datetime)
        self.assertEqual(out.storage_removed_at.tzinfo, timezone.utc)
        db.commit.assert_called_once()

    def test_allows_accepted_with_warning(self) -> None:
        media = _media(
            ai_detection_results=[
                SimpleNamespace(review_status="accepted_with_warning"),
            ]
        )
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once()
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        db.commit.assert_called_once()

    def test_allows_pending_review(self) -> None:
        media = _media(
            ai_detection_results=[
                SimpleNamespace(review_status="pending_review"),
            ]
        )
        db = MagicMock()
        with patch.object(media_crud, "_delete_media_file_from_disk") as delete_disk:
            out = media_crud.remove_practice_storage_only(db, media)
        delete_disk.assert_called_once()
        self.assertEqual(out.file_url, media_crud.REMOVED_STORAGE_FILE_URL)
        self.assertIsInstance(out.storage_removed_at, datetime)
        self.assertEqual(out.storage_removed_at.tzinfo, timezone.utc)
        db.commit.assert_called_once()


if __name__ == "__main__":
    unittest.main()
