"""Phase 2: linked replacement upload (isolated DB)."""

from __future__ import annotations

import json
import os
import re
import unittest
from unittest.mock import patch

import pytest

from app.config import settings
from app.crud import evaluation as eval_crud
from app.crud import submission_chain as chain_crud
from app.crud.submission_chain import ReplacementUploadError
from app.database import SessionLocal, engine
from app.migrations._migration_guard import dispose_engine_pool
from app.migrations.submission_chains_phase1 import upgrade_submission_chains_phase1
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import XP_RECONCILIATION_PENDING
from app.models.user import User
from app.services.ai_review_workflow import apply_ai_review
from app.services.chain_xp_award import apply_chain_xp_award


def _isolated_test_db_configured() -> bool:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test":
        return False
    url = (os.environ.get("DATABASE_URL") or settings.database_url or "").lower()
    match = re.search(r"/([^/?#]+)(?:\?|$)", url)
    return match is not None and match.group(1) == "access_waverep_test"


@pytest.mark.skipif(
    not _isolated_test_db_configured(),
    reason="Set ACCESS_PYTEST_DB=access_waverep_test",
)
class ReplacementUploadPhase2DbTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        dispose_engine_pool(engine)
        upgrade_submission_chains_phase1(engine)

    def _ensure_chain_for_media(self, db, media: MediaFile) -> SubmissionChain:
        chain = chain_crud.get_chain_for_media(db, media.id)
        if chain is not None:
            if media.submission_chain_id is None:
                media.submission_chain_id = chain.id
                db.commit()
            return chain
        chain = SubmissionChain(
            root_media_id=media.id,
            member_id=media.uploaded_by or 0,
            xp_reconciliation_status=XP_RECONCILIATION_PENDING,
        )
        db.add(chain)
        db.flush()
        media.submission_chain_id = chain.id
        db.commit()
        db.refresh(chain)
        return chain

    def _member(self) -> User:
        db = SessionLocal()
        try:
            user = db.query(User).first()
            if user is None:
                self.skipTest("No users in isolated DB")
            return user
        finally:
            db.close()

    def _root_with_reupload(self, member_id: int) -> tuple[MediaFile, SubmissionChain]:
        db = SessionLocal()
        try:
            root = MediaFile(
                uploaded_by=member_id,
                file_name="root_phase2.jpg",
                file_type="photo",
                file_url="/uploads/images/root_phase2.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(root)
            db.commit()
            db.refresh(root)
            self._ensure_chain_for_media(db, root)
            ai = eval_crud.create_ai_result(
                db,
                {
                    "media_id": root.id,
                    "ai_probability": 0.1,
                    "detection_result": "human",
                    "reviewed_by_admin": False,
                    "review_status": "pending_review",
                },
            )
            apply_ai_review(
                db,
                ai,
                review_status="reupload_requested",
                admin_remarks="Please upload a clearer video clip.",
            )
            chain = chain_crud.get_chain_for_media(db, root.id)
            assert chain is not None
            db.refresh(root)
            return root, chain
        finally:
            db.close()

    def test_reupload_requested_sets_awaiting(self) -> None:
        user = self._member()
        root, chain = self._root_with_reupload(user.id)
        self.assertEqual(chain.awaiting_replacement_media_id, root.id)

    def test_finalize_replacement_links_chain(self) -> None:
        user = self._member()
        root, chain = self._root_with_reupload(user.id)
        db = SessionLocal()
        try:
            rep = MediaFile(
                uploaded_by=user.id,
                file_name="rep_phase2.jpg",
                file_type="photo",
                file_url="/uploads/images/rep_phase2.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep)
            db.commit()
            db.refresh(rep)
            _, locked = chain_crud.validate_replacement_target(
                db, member_id=user.id, replaces_media_id=root.id
            )
            chain_crud.attach_replacement_media(
                db, chain=locked, replacement=rep, replaces_media_id=root.id
            )
            db.commit()
            db.refresh(rep)
            self.assertEqual(rep.replacement_lifecycle, "active")
            self.assertEqual(rep.replaces_media_id, root.id)
            self.assertEqual(locked.active_replacement_media_id, rep.id)
        finally:
            db.close()

    def test_reupload_locked_after_admin_verifies_replacement(self) -> None:
        user = self._member()
        root, chain = self._root_with_reupload(user.id)
        db = SessionLocal()
        try:
            rep = MediaFile(
                uploaded_by=user.id,
                file_name="rep_lock.jpg",
                file_type="photo",
                file_url="/uploads/rep_lock.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep)
            db.commit()
            db.refresh(rep)
            _, locked = chain_crud.validate_replacement_target(
                db, member_id=user.id, replaces_media_id=root.id
            )
            chain_crud.attach_replacement_media(
                db, chain=locked, replacement=rep, replaces_media_id=root.id
            )
            db.commit()
            self.assertFalse(
                chain_crud.member_can_reupload(
                    db,
                    member_id=user.id,
                    media=root,
                    chain=locked,
                    ai_review_status="reupload_requested",
                )
            )
            ai_rep = eval_crud.create_ai_result(
                db,
                {
                    "media_id": rep.id,
                    "ai_probability": 0.1,
                    "detection_result": "human",
                    "review_status": "pending_review",
                    "reviewed_by_admin": False,
                },
            )
            apply_ai_review(
                db,
                ai_rep,
                review_status="verified_human",
                admin_remarks="Replacement verified.",
            )
            db.refresh(locked)
            db.refresh(root)
            root_ai = eval_crud.get_ai_for_media(db, root.id)
            self.assertEqual(root_ai.review_status, "verified_human")
            self.assertFalse(
                chain_crud.member_can_reupload(
                    db,
                    member_id=user.id,
                    media=root,
                    chain=locked,
                    ai_review_status=root_ai.review_status,
                )
            )
            self.assertTrue(
                chain_crud.member_replacement_verified(db, locked, root),
            )
            with self.assertRaises(ReplacementUploadError) as ctx:
                chain_crud.peek_replacement_target(
                    db, member_id=user.id, replaces_media_id=root.id
                )
            self.assertEqual(ctx.exception.status_code, 409)
        finally:
            db.close()

    def test_duplicate_active_replacement_blocked(self) -> None:
        user = self._member()
        root, _chain = self._root_with_reupload(user.id)
        db = SessionLocal()
        try:
            rep1 = MediaFile(
                uploaded_by=user.id,
                file_name="rep_a.jpg",
                file_type="photo",
                file_url="/uploads/a.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep1)
            db.commit()
            db.refresh(rep1)
            _, c1 = chain_crud.validate_replacement_target(db, member_id=user.id, replaces_media_id=root.id)
            chain_crud.attach_replacement_media(db, chain=c1, replacement=rep1, replaces_media_id=root.id)
            db.commit()

            rep2 = MediaFile(
                uploaded_by=user.id,
                file_name="rep_b.jpg",
                file_type="photo",
                file_url="/uploads/b.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep2)
            db.commit()
            with self.assertRaises(ReplacementUploadError) as ctx:
                chain_crud.validate_replacement_target(db, member_id=user.id, replaces_media_id=root.id)
            self.assertEqual(ctx.exception.code, "replacement_already_active")
        finally:
            db.close()

    def test_wrong_owner_rejected(self) -> None:
        user = self._member()
        root, _ = self._root_with_reupload(user.id)
        db = SessionLocal()
        try:
            other = db.query(User).filter(User.id != user.id).first()
            if other is None:
                self.skipTest("Need second user")
            with self.assertRaises(ReplacementUploadError) as ctx:
                chain_crud.peek_replacement_target(
                    db, member_id=other.id, replaces_media_id=root.id
                )
            self.assertEqual(ctx.exception.status_code, 403)
        finally:
            db.close()

    def test_ensure_submission_chain_for_evaluation_creates_root(self) -> None:
        user = self._member()
        db = SessionLocal()
        try:
            media = MediaFile(
                uploaded_by=user.id,
                file_name="ensure_chain.jpg",
                file_type="photo",
                file_url="/uploads/ensure_chain.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(media)
            db.commit()
            db.refresh(media)
            chain = chain_crud.ensure_submission_chain_for_evaluation(db, media)
            db.commit()
            self.assertIsNotNone(chain)
            assert chain is not None
            self.assertEqual(chain.root_media_id, media.id)
            self.assertEqual(media.submission_chain_id, chain.id)
        finally:
            db.close()

    def test_chain_xp_awarded_only_once(self) -> None:
        user = self._member()
        db = SessionLocal()
        try:
            media = MediaFile(
                uploaded_by=user.id,
                file_name="xp_chain.jpg",
                file_type="photo",
                file_url="/uploads/xp.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(media)
            db.commit()
            db.refresh(media)
            chain = self._ensure_chain_for_media(db, media)
            eval_crud.create_evaluation(
                db,
                {
                    "media_id": media.id,
                    "sharpness_score": 1.0,
                    "brightness_score": 1.0,
                    "contrast_score": 1.0,
                    "blur_score": 1.0,
                    "noise_score": 1.0,
                    "overall_score": 0.8,
                    "feedback": "ok",
                    "criteria_json": json.dumps(
                        {"xp_pending": True, "xp_points_preview": 40, "xp_eligible": True}
                    ),
                },
            )
            first = apply_chain_xp_award(db, media_id=media.id, member_id=user.id, points=40)
            db.commit()
            second = apply_chain_xp_award(db, media_id=media.id, member_id=user.id, points=40)
            self.assertEqual(first, 40)
            self.assertEqual(second, 0)
            db.refresh(chain)
            self.assertEqual(chain.xp_awarded_total, 40)
        finally:
            db.close()

    def test_reupload_locks_chain_after_explicit_award_marker(self) -> None:
        user = self._member()
        db = SessionLocal()
        try:
            media = MediaFile(
                uploaded_by=user.id,
                file_name="xp_lock.jpg",
                file_type="photo",
                file_url="/uploads/lock.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(media)
            db.commit()
            db.refresh(media)
            self._ensure_chain_for_media(db, media)
            eval_crud.create_evaluation(
                db,
                {
                    "media_id": media.id,
                    "sharpness_score": 1.0,
                    "brightness_score": 1.0,
                    "contrast_score": 1.0,
                    "blur_score": 1.0,
                    "noise_score": 1.0,
                    "overall_score": 0.9,
                    "feedback": "ok",
                    "criteria_json": json.dumps(
                        {"xp_awarded_at_review": True, "xp_points_preview": 55}
                    ),
                },
            )
            ai = eval_crud.create_ai_result(
                db,
                {
                    "media_id": media.id,
                    "ai_probability": 0.1,
                    "detection_result": "human",
                    "review_status": "pending_review",
                    "reviewed_by_admin": False,
                },
            )
            apply_ai_review(
                db,
                ai,
                review_status="reupload_requested",
                admin_remarks="Need a new upload please.",
            )
            chain = chain_crud.get_chain_for_media(db, media.id)
            assert chain is not None
            db.refresh(chain)
            self.assertTrue(chain.xp_award_locked)
            self.assertGreaterEqual(chain.xp_awarded_total, 55)
        finally:
            db.close()


class ReplacementUploadFlagTest(unittest.TestCase):
    def test_flag_default_false(self) -> None:
        self.assertFalse(settings.replacement_upload_enabled)
