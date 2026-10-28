"""Unit tests for re-upload lock helpers (no database)."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.crud.submission_chain import member_can_reupload
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION


def _media(**kwargs):
    defaults = dict(
        uploaded_by=1,
        media_category=MEDIA_CATEGORY_EVALUATION,
        replaces_media_id=None,
        id=10,
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


def _chain(**kwargs):
    defaults = dict(
        active_replacement_media_id=None,
        awaiting_replacement_media_id=10,
        root_media_id=10,
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


class MemberCanReuploadTests(unittest.TestCase):
    @patch("app.config.settings")
    def test_allowed_when_awaiting_and_no_active(self, settings) -> None:
        settings.replacement_upload_enabled = True
        self.assertTrue(
            member_can_reupload(
                None,
                member_id=1,
                media=_media(),
                chain=_chain(),
                ai_review_status="reupload_requested",
            )
        )

    @patch("app.config.settings")
    def test_blocked_when_active_replacement(self, settings) -> None:
        settings.replacement_upload_enabled = True
        self.assertFalse(
            member_can_reupload(
                None,
                member_id=1,
                media=_media(),
                chain=_chain(active_replacement_media_id=99),
                ai_review_status="reupload_requested",
            )
        )

    @patch("app.config.settings")
    def test_blocked_when_not_awaiting_target(self, settings) -> None:
        settings.replacement_upload_enabled = True
        self.assertFalse(
            member_can_reupload(
                None,
                member_id=1,
                media=_media(id=10),
                chain=_chain(awaiting_replacement_media_id=None),
                ai_review_status="reupload_requested",
            )
        )

    @patch("app.config.settings")
    def test_blocked_after_admin_verified_status(self, settings) -> None:
        settings.replacement_upload_enabled = True
        self.assertFalse(
            member_can_reupload(
                None,
                member_id=1,
                media=_media(),
                chain=_chain(awaiting_replacement_media_id=None),
                ai_review_status="verified_human",
            )
        )

    @patch("app.config.settings")
    def test_blocked_when_feature_disabled(self, settings) -> None:
        settings.replacement_upload_enabled = False
        self.assertFalse(
            member_can_reupload(
                None,
                member_id=1,
                media=_media(),
                chain=_chain(),
                ai_review_status="reupload_requested",
            )
        )


if __name__ == "__main__":
    unittest.main()
