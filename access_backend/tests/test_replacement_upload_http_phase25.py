"""Phase 2.5: HTTP integration and safety checks for replacement upload (access_waverep_test only)."""

from __future__ import annotations

import json
import os
import re
import threading
import unittest
import uuid
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.config import settings
from app.core.security import create_access_token
from app.crud import evaluation as eval_crud
from app.crud import submission_chain as chain_crud
from app.database import SessionLocal, engine
from app.migrations._migration_guard import dispose_engine_pool
from app.migrations.submission_chains_phase1 import upgrade_submission_chains_phase1
from app.models.enums import RoleName, UserStatus
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.models.role import Role
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import (
    REPLACEMENT_LIFECYCLE_ACTIVE,
    REPLACEMENT_LIFECYCLE_SUPERSEDED,
    REPLACEMENT_LIFECYCLE_TERMINAL,
    XP_RECONCILIATION_PENDING,
)
from app.models.user import User
from app.services.ai_review_workflow import apply_ai_review
from app.services.chain_xp_award import apply_chain_xp_award
from main import app

# Minimal valid JPEG (1x1) — append unique bytes so file hashes differ per upload.
_MIN_JPEG = (
    b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
    b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c"
    b"\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c"
    b"\x1c $.\' \",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08"
    b"\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00"
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\xff\xc4\x00\x14\x10\x01\x00"
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08"
    b"\x01\x01\x00\x00?\x00\xaa\xff\xd9"
)


def _isolated_test_db_configured() -> bool:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test":
        return False
    url = (os.environ.get("DATABASE_URL") or settings.database_url or "").lower()
    match = re.search(r"/([^/?#]+)(?:\?|$)", url)
    return match is not None and match.group(1) == "access_waverep_test"


def _assert_waverep_only() -> None:
    with engine.connect() as conn:
        from sqlalchemy import text

        db_name = conn.execute(text("SELECT current_database()")).scalar()
        if db_name != "access_waverep_test":
            raise RuntimeError(f"Refusing test writes on database {db_name!r}")


def _unique_jpeg(seed: str) -> bytes:
    return _MIN_JPEG + seed.encode("utf-8")


def _error_detail(resp) -> dict | str | None:
    try:
        body = resp.json()
    except Exception:
        return None
    detail = body.get("detail")
    if isinstance(detail, list) and detail:
        first = detail[0]
        if isinstance(first, dict):
            return first
    return detail


def _token(user: User) -> str:
    return create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": user.role.role_name,
        }
    )


def _user_by_role(db, role_name: str) -> User | None:
    return (
        db.query(User)
        .join(Role)
        .filter(Role.role_name == role_name, User.status == UserStatus.APPROVED)
        .first()
    )


def _ensure_chain(db, media: MediaFile) -> SubmissionChain:
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


def _root_awaiting_reupload(db, member: User) -> MediaFile:
    root = MediaFile(
        uploaded_by=member.id,
        file_name=f"root_{uuid.uuid4().hex[:8]}.jpg",
        file_type="photo",
        file_url="/uploads/images/root_http.jpg",
        media_category=MEDIA_CATEGORY_EVALUATION,
    )
    db.add(root)
    db.commit()
    db.refresh(root)
    _ensure_chain(db, root)
    ai = eval_crud.create_ai_result(
        db,
        {
            "media_id": root.id,
            "ai_probability": 0.12,
            "detection_result": "human",
            "reviewed_by_admin": False,
            "review_status": "pending_review",
        },
    )
    apply_ai_review(
        db,
        ai,
        review_status="reupload_requested",
        admin_remarks="Please upload a clearer practice photo.",
    )
    db.refresh(root)
    return root


@pytest.mark.skipif(
    not _isolated_test_db_configured(),
    reason="Set ACCESS_PYTEST_DB=access_waverep_test",
)
class ReplacementUploadHttpPhase25Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        _assert_waverep_only()
        dispose_engine_pool(engine)
        upgrade_submission_chains_phase1(engine)

    def setUp(self) -> None:
        _assert_waverep_only()
        self.client = TestClient(app)
        self._pipeline_calls: list[int] = []
        self._pipeline_patch = patch(
            "app.api.routes.media.schedule_deferred_media_evaluation",
            side_effect=self._record_pipeline,
        )
        self._pipeline_patch.start()

    def tearDown(self) -> None:
        self._pipeline_patch.stop()
        self.client.close()

    def _record_pipeline(self, media_id: int, evaluation_metadata: str | None = None) -> None:
        self._pipeline_calls.append(media_id)

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

    def _upload_replacement(
        self,
        member: User,
        root_id: int,
        *,
        seed: str | None = None,
        filename: str = "replacement.jpg",
    ):
        seed = seed or uuid.uuid4().hex
        content = _unique_jpeg(seed)
        headers = {"Authorization": f"Bearer {_token(member)}"}
        return self.client.post(
            "/api/media/upload",
            headers=headers,
            files={"file": (filename, content, "image/jpeg")},
            data={"replaces_media_id": str(root_id)},
        )

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_replacement_upload_links_chain_preserves_root(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_name = root.file_name
            root_url = root.file_url
            root_id = root.id
        finally:
            db.close()

        resp = self._upload_replacement(member, root_id)
        self.assertEqual(resp.status_code, 200, resp.text)
        rep_id = resp.json()["id"]
        self.assertEqual(len(self._pipeline_calls), 1)
        self.assertEqual(self._pipeline_calls[0], rep_id)

        db = SessionLocal()
        try:
            root = db.get(MediaFile, root_id)
            assert root is not None
            self.assertEqual(root.file_name, root_name)
            self.assertEqual(root.file_url, root_url)
            rep = db.get(MediaFile, rep_id)
            assert rep is not None
            chain = chain_crud.get_chain_for_media(db, root_id)
            assert chain is not None
            self.assertEqual(rep.replaces_media_id, root_id)
            self.assertEqual(rep.replacement_lifecycle, REPLACEMENT_LIFECYCLE_ACTIVE)
            self.assertEqual(chain.active_replacement_media_id, rep_id)
        finally:
            db.close()

    @patch.object(settings, "replacement_upload_enabled", False)
    def test_http_replacement_disabled(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
        finally:
            db.close()
        resp = self._upload_replacement(member, root_id, seed="flag-off")
        self.assertEqual(resp.status_code, 400, resp.text)
        detail = resp.json().get("detail")
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "replacement_upload_disabled")
        else:
            self.assertIn("replacement_upload_disabled", resp.text)

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_wrong_owner_forbidden(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
            other = _user_by_role(db, RoleName.MEMBER)
            if other is None or other.id == member.id:
                other = db.query(User).filter(User.id != member.id).first()
            if other is None:
                self.skipTest("Need second user")
        finally:
            db.close()
        resp = self._upload_replacement(other, root_id, seed="wrong-owner")
        self.assertIn(resp.status_code, (403, 400))
        detail = resp.json().get("detail")
        if isinstance(detail, dict):
            self.assertIn(detail.get("code"), ("invalid_replacement_target",))

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_invalid_media_id(self) -> None:
        member = self._member()
        resp = self._upload_replacement(member, 999_999_999, seed="bad-id")
        self.assertEqual(resp.status_code, 400, resp.text)
        detail = _error_detail(resp)
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "invalid_replacement_target")

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_not_reupload_requested(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = MediaFile(
                uploaded_by=member.id,
                file_name="no_reupload.jpg",
                file_type="photo",
                file_url="/uploads/no_reupload.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(root)
            db.commit()
            db.refresh(root)
            _ensure_chain(db, root)
            eval_crud.create_ai_result(
                db,
                {
                    "media_id": root.id,
                    "ai_probability": 0.1,
                    "detection_result": "human",
                    "review_status": "pending_review",
                    "reviewed_by_admin": False,
                },
            )
            root_id = root.id
        finally:
            db.close()
        resp = self._upload_replacement(member, root_id, seed="no-reupload-status")
        self.assertEqual(resp.status_code, 409, resp.text)
        detail = _error_detail(resp)
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "replacement_not_requested")

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_invalid_file_type(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
        finally:
            db.close()
        headers = {"Authorization": f"Bearer {_token(member)}"}
        resp = self.client.post(
            "/api/media/upload",
            headers=headers,
            files={"file": ("bad.exe", b"MZ", "application/octet-stream")},
            data={"replaces_media_id": str(root_id)},
        )
        self.assertEqual(resp.status_code, 400)

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_duplicate_replacement_blocked(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
        finally:
            db.close()
        first = self._upload_replacement(member, root_id)
        self.assertEqual(first.status_code, 200, first.text)
        second = self._upload_replacement(member, root_id)
        self.assertEqual(second.status_code, 409, second.text)
        detail = _error_detail(second)
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "replacement_already_active")

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_http_concurrent_replacement_one_wins(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
        finally:
            db.close()

        barrier = threading.Barrier(2)
        results: list = []

        def worker() -> None:
            barrier.wait()
            seed = uuid.uuid4().hex
            client = TestClient(app)
            try:
                content = _unique_jpeg(seed)
                headers = {"Authorization": f"Bearer {_token(member)}"}
                r = client.post(
                    "/api/media/upload",
                    headers=headers,
                    files={"file": (f"{seed}.jpg", content, "image/jpeg")},
                    data={"replaces_media_id": str(root_id)},
                )
                results.append(r.status_code)
            finally:
                client.close()

        with patch.object(settings, "replacement_upload_enabled", True):
            with patch("app.api.routes.media.schedule_deferred_media_evaluation"):
                t1 = threading.Thread(target=worker)
                t2 = threading.Thread(target=worker)
            t1.start()
            t2.start()
            t1.join()
            t2.join()

        self.assertEqual(len(results), 2, results)
        self.assertEqual(sum(1 for c in results if c == 200), 1, results)
        self.assertEqual(sum(1 for c in results if c == 409), 1, results)

        db = SessionLocal()
        try:
            active_count = db.scalar(
                select(func.count())
                .select_from(MediaFile)
                .where(
                    MediaFile.submission_chain_id.isnot(None),
                    MediaFile.replacement_lifecycle == REPLACEMENT_LIFECYCLE_ACTIVE,
                    MediaFile.replaces_media_id == root_id,
                )
            )
            self.assertEqual(active_count, 1)
        finally:
            db.close()

    @patch.object(settings, "replacement_upload_enabled", True)
    def test_attach_failure_cleans_orphan_media(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
        finally:
            db.close()

        from app.crud.submission_chain import ReplacementUploadError

        with patch.object(settings, "replacement_upload_enabled", True):
            with patch(
                "app.crud.submission_chain.attach_replacement_media",
                side_effect=ReplacementUploadError("simulated", "Simulated attach failure", 500),
            ):
                resp = self._upload_replacement(member, root_id, seed="cleanup-test")
        self.assertEqual(resp.status_code, 500)

        db = SessionLocal()
        try:
            orphans = db.scalars(
                select(MediaFile.id).where(
                    MediaFile.uploaded_by == member.id,
                    MediaFile.replaces_media_id == root_id,
                )
            ).all()
            self.assertEqual(list(orphans), [])
        finally:
            db.close()

    def test_admin_remarks_required_for_reupload(self) -> None:
        admin = self._admin()
        member = self._member()
        db = SessionLocal()
        try:
            root = MediaFile(
                uploaded_by=member.id,
                file_name="remarks_test.jpg",
                file_type="photo",
                file_url="/uploads/remarks_test.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(root)
            db.commit()
            db.refresh(root)
            ai = eval_crud.create_ai_result(
                db,
                {
                    "media_id": root.id,
                    "ai_probability": 0.2,
                    "detection_result": "human",
                    "review_status": "pending_review",
                    "reviewed_by_admin": False,
                },
            )
            ai_id = ai.id
        finally:
            db.close()
        headers = {"Authorization": f"Bearer {_token(admin)}"}
        bad = self.client.patch(
            f"/api/admin/ai-detection/{ai_id}",
            headers=headers,
            json={"review_status": "reupload_requested", "admin_remarks": "short"},
        )
        self.assertEqual(bad.status_code, 422, bad.text)
        detail = _error_detail(bad)
        if isinstance(detail, dict):
            self.assertEqual(detail.get("code"), "admin_remarks_required")
        else:
            self.assertIn("admin_remarks_required", bad.text)

    def test_chain_history_auth(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            root_id = root.id
            other = db.query(User).filter(User.id != member.id).first()
        finally:
            db.close()

        ok = self.client.get(
            f"/api/evaluations/chains/{root_id}",
            headers={"Authorization": f"Bearer {_token(member)}"},
        )
        self.assertEqual(ok.status_code, 200)

        if other is not None:
            deny = self.client.get(
                f"/api/evaluations/chains/{root_id}",
                headers={"Authorization": f"Bearer {_token(other)}"},
            )
            self.assertEqual(deny.status_code, 404)

        member_headers = {"Authorization": f"Bearer {_token(member)}"}
        admin_only = self.client.get(
            f"/api/admin/media/{root_id}/submission-chain",
            headers=member_headers,
        )
        self.assertEqual(admin_only.status_code, 403)

        admin = self._admin()
        admin_ok = self.client.get(
            f"/api/admin/media/{root_id}/submission-chain",
            headers={"Authorization": f"Bearer {_token(admin)}"},
        )
        self.assertEqual(admin_ok.status_code, 200)

    def test_replacement_lifecycle_on_admin_verify_and_reject(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = _root_awaiting_reupload(db, member)
            rep = MediaFile(
                uploaded_by=member.id,
                file_name="lifecycle_rep.jpg",
                file_type="photo",
                file_url="/uploads/lifecycle_rep.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep)
            db.commit()
            db.refresh(rep)
            _, chain = chain_crud.validate_replacement_target(
                db, member_id=member.id, replaces_media_id=root.id
            )
            chain_crud.attach_replacement_media(
                db, chain=chain, replacement=rep, replaces_media_id=root.id
            )
            db.commit()
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
                admin_remarks="Replacement looks authentic.",
            )
            db.refresh(chain)
            db.refresh(rep)
            self.assertIsNone(chain.active_replacement_media_id)
            self.assertIsNone(chain.awaiting_replacement_media_id)
            self.assertEqual(rep.replacement_lifecycle, REPLACEMENT_LIFECYCLE_SUPERSEDED)

            root2 = _root_awaiting_reupload(db, member)
            rep2 = MediaFile(
                uploaded_by=member.id,
                file_name="lifecycle_rep2.jpg",
                file_type="photo",
                file_url="/uploads/lifecycle_rep2.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(rep2)
            db.commit()
            db.refresh(rep2)
            _, chain2 = chain_crud.validate_replacement_target(
                db, member_id=member.id, replaces_media_id=root2.id
            )
            chain_crud.attach_replacement_media(
                db, chain=chain2, replacement=rep2, replaces_media_id=root2.id
            )
            db.commit()
            ai_rep2 = eval_crud.create_ai_result(
                db,
                {
                    "media_id": rep2.id,
                    "ai_probability": 0.9,
                    "detection_result": "ai_generated",
                    "review_status": "pending_review",
                    "reviewed_by_admin": False,
                },
            )
            apply_ai_review(
                db,
                ai_rep2,
                review_status="confirmed_ai_generated",
                admin_remarks="Replacement still appears AI generated.",
            )
            db.refresh(chain2)
            db.refresh(rep2)
            self.assertIsNone(chain2.active_replacement_media_id)
            self.assertEqual(chain2.awaiting_replacement_media_id, root2.id)
            self.assertEqual(rep2.replacement_lifecycle, REPLACEMENT_LIFECYCLE_TERMINAL)
        finally:
            db.close()

    def test_chain_xp_pending_and_double_award_blocked(self) -> None:
        member = self._member()
        db = SessionLocal()
        try:
            root = MediaFile(
                uploaded_by=member.id,
                file_name="xp_http_root.jpg",
                file_type="photo",
                file_url="/uploads/xp_http_root.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(root)
            db.commit()
            db.refresh(root)
            chain = _ensure_chain(db, root)
            eval_crud.create_evaluation(
                db,
                {
                    "media_id": root.id,
                    "sharpness_score": 1.0,
                    "brightness_score": 1.0,
                    "contrast_score": 1.0,
                    "blur_score": 1.0,
                    "noise_score": 1.0,
                    "overall_score": 0.85,
                    "feedback": "ok",
                    "criteria_json": json.dumps(
                        {"xp_pending": True, "xp_points_preview": 33, "xp_eligible": True}
                    ),
                },
            )
            first = apply_chain_xp_award(db, media_id=root.id, member_id=member.id, points=33)
            db.commit()
            rep = MediaFile(
                uploaded_by=member.id,
                file_name="xp_http_rep.jpg",
                file_type="photo",
                file_url="/uploads/xp_http_rep.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
                submission_chain_id=chain.id,
                replaces_media_id=root.id,
                replacement_lifecycle=REPLACEMENT_LIFECYCLE_ACTIVE,
            )
            db.add(rep)
            db.commit()
            db.refresh(rep)
            eval_crud.create_evaluation(
                db,
                {
                    "media_id": rep.id,
                    "sharpness_score": 1.0,
                    "brightness_score": 1.0,
                    "contrast_score": 1.0,
                    "blur_score": 1.0,
                    "noise_score": 1.0,
                    "overall_score": 0.9,
                    "feedback": "ok",
                    "criteria_json": json.dumps(
                        {"xp_pending": True, "xp_points_preview": 50, "xp_eligible": True}
                    ),
                },
            )
            second = apply_chain_xp_award(db, media_id=rep.id, member_id=member.id, points=50)
            db.commit()
            db.refresh(chain)
            self.assertEqual(first, 33)
            self.assertEqual(second, 0)
            self.assertEqual(chain.xp_awarded_total, 33)
            self.assertTrue(chain.xp_award_locked)
        finally:
            db.close()
