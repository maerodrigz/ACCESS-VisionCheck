"""End-to-end re-upload lock workflow on access_waverep_test only (QA isolated DB)."""

from __future__ import annotations

import os
import re
import unittest
import uuid
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.config import settings
from app.core.security import create_access_token
from app.crud import evaluation as eval_crud
from app.crud import submission_chain as chain_crud
from app.database import SessionLocal, engine
from app.migrations._migration_guard import dispose_engine_pool
from app.migrations.submission_chains_phase1 import upgrade_submission_chains_phase1
from app.models.enums import RoleName
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.role import Role
from app.models.submission_chain_constants import REPLACEMENT_LIFECYCLE_ACTIVE
from app.models.user import User
from app.services.ai_review_workflow import apply_ai_review
from main import app

# Reuse HTTP helpers from phase 2.5 tests.
from tests.test_replacement_upload_http_phase25 import (  # noqa: E402
    _assert_waverep_only,
    _error_detail,
    _isolated_test_db_configured,
    _root_awaiting_reupload,
    _token,
    _unique_jpeg,
    _user_by_role,
)


def _ensure_eval_for_media(db, media_id: int) -> None:
    if eval_crud.get_for_media(db, media_id) is not None:
        return
    eval_crud.create_evaluation(
        db,
        {
            "media_id": media_id,
            "sharpness_score": 0.8,
            "brightness_score": 0.8,
            "contrast_score": 0.8,
            "blur_score": 0.8,
            "noise_score": 0.8,
            "overall_score": 0.75,
            "feedback": "QA practice evaluation for re-upload lock E2E.",
        },
    )
    db.commit()


def _member_eval_row(client: TestClient, member: User, media_id: int) -> dict:
    headers = {"Authorization": f"Bearer {_token(member)}"}
    resp = client.get(
        "/api/evaluations",
        headers=headers,
        params={"mine": "true", "media_id": str(media_id)},
    )
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert isinstance(rows, list) and len(rows) == 1, rows
    return rows[0]


@pytest.mark.skipif(
    not _isolated_test_db_configured(),
    reason="Set ACCESS_PYTEST_DB=access_waverep_test and DATABASE_URL access_waverep_test",
)
class ReuploadLockE2EWaverepTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        _assert_waverep_only()
        dispose_engine_pool(engine)
        upgrade_submission_chains_phase1(engine)

    def setUp(self) -> None:
        _assert_waverep_only()
        self.client = TestClient(app)
        self._pipeline_patch = patch(
            "app.api.routes.media.schedule_deferred_media_evaluation",
        )
        self._pipeline_patch.start()

    def tearDown(self) -> None:
        self._pipeline_patch.stop()
        self.client.close()

    def _member(self) -> User:
        db = SessionLocal()
        try:
            user = _user_by_role(db, RoleName.MEMBER)
            if user is None:
                self.skipTest("No approved Member in access_waverep_test")
            return user
        finally:
            db.close()

    def _admin(self) -> User:
        db = SessionLocal()
        try:
            user = _user_by_role(db, RoleName.ADMIN)
            if user is None:
                self.skipTest("No approved Admin in access_waverep_test")
            return user
        finally:
            db.close()

    def _upload_replacement(self, member: User, root_id: int, *, seed: str | None = None):
        seed = seed or uuid.uuid4().hex
        content = _unique_jpeg(seed)
        headers = {"Authorization": f"Bearer {_token(member)}"}
        return self.client.post(
            "/api/media/upload",
            headers=headers,
            files={"file": (f"rep_{seed}.jpg", content, "image/jpeg")},
            data={"replaces_media_id": str(root_id)},
        )

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_e2e_reupload_lock_full_workflow(self) -> None:
        """Admin request → member upload → lock pending → admin verify → lock permanent."""
        member = self._member()
        admin = self._admin()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
            root_name = root.file_name
            root_url = root.file_url
            root_ai = eval_crud.get_ai_for_media(db, root_id)
            assert root_ai is not None
            self.assertEqual((root_ai.review_status or "").lower(), "reupload_requested")
            _ensure_eval_for_media(db, root_id)
        finally:
            db.close()

        # 2 — Member API shows upload allowed.
        row = _member_eval_row(self.client, member, root_id)
        self.assertTrue(row.get("can_reupload"), row)
        self.assertFalse(row.get("replacement_verified"), row)

        # 3 — Member submits one replacement.
        first = self._upload_replacement(member, root_id, seed="e2e-first")
        self.assertEqual(first.status_code, 200, first.text)
        rep_id = int(first.json()["id"])

        # 4 — Second replacement blocked while pending.
        second = self._upload_replacement(member, root_id, seed="e2e-second")
        self.assertEqual(second.status_code, 409, second.text)
        detail = _error_detail(second)
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "replacement_already_active")

        row_pending = _member_eval_row(self.client, member, root_id)
        self.assertFalse(row_pending.get("can_reupload"), row_pending)
        self.assertEqual(row_pending.get("active_replacement_media_id"), rep_id)

        # 5 — Admin verifies replacement (HTTP admin review on replacement AI row).
        db = SessionLocal()
        try:
            ai_rep = eval_crud.get_ai_for_media(db, rep_id)
            if ai_rep is None:
                ai_rep = eval_crud.create_ai_result(
                    db,
                    {
                        "media_id": rep_id,
                        "ai_probability": 0.08,
                        "detection_result": "human",
                        "review_status": "pending_review",
                        "reviewed_by_admin": False,
                    },
                )
                db.commit()
            ai_rep_id = ai_rep.id
        finally:
            db.close()

        verify = self.client.patch(
            f"/api/admin/ai-detection/{ai_rep_id}",
            headers={"Authorization": f"Bearer {_token(admin)}"},
            json={
                "review_status": "verified_human",
                "admin_remarks": "Replacement verified for capstone E2E QA test.",
            },
        )
        self.assertEqual(verify.status_code, 200, verify.text)

        # 6–7 — Verified state; re-upload not available.
        row_after = _member_eval_row(self.client, member, root_id)
        self.assertFalse(row_after.get("can_reupload"), row_after)
        self.assertTrue(row_after.get("replacement_verified"), row_after)
        self.assertIn(
            (row_after.get("review_status") or "").lower(),
            ("verified_human", "accepted_with_warning"),
        )

        # 8 — Direct API upload rejected after verification.
        third = self._upload_replacement(member, root_id, seed="e2e-after-verify")
        self.assertEqual(third.status_code, 409, third.text)
        blocked = _error_detail(third)
        if isinstance(blocked, dict):
            self.assertIn(
                blocked.get("code"),
                ("replacement_not_requested", "replacement_already_active"),
            )

        # 9 — Submission history intact; root file preserved.
        hist = self.client.get(
            f"/api/evaluations/chains/{root_id}",
            headers={"Authorization": f"Bearer {_token(member)}"},
        )
        self.assertEqual(hist.status_code, 200, hist.text)
        body = hist.json()
        media_items = body.get("media") or []
        self.assertGreaterEqual(len(media_items), 2, body)
        ids = {m.get("media_id") for m in media_items}
        self.assertIn(root_id, ids)
        self.assertIn(rep_id, ids)

        db = SessionLocal()
        try:
            root_after = db.get(MediaFile, root_id)
            assert root_after is not None
            self.assertEqual(root_after.file_name, root_name)
            self.assertEqual(root_after.file_url, root_url)
            rep = db.get(MediaFile, rep_id)
            assert rep is not None
            self.assertEqual(rep.replaces_media_id, root_id)
            chain = chain_crud.get_chain_for_media(db, root_id)
            assert chain is not None
            self.assertIsNone(chain.active_replacement_media_id)
            self.assertIsNone(chain.awaiting_replacement_media_id)
        finally:
            db.close()


if __name__ == "__main__":
    unittest.main()
