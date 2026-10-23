"""Member evaluation duplicate upload protection (SHA-256, HTTP 409)."""

from __future__ import annotations

import asyncio
import os
import re
import unittest
import uuid
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError

from app.crud import media as media_crud
from app.crud.media import EvaluationDuplicateUploadError
from app.services.media_file_hash import (
    EVALUATION_DUPLICATE_UPLOAD_MESSAGE,
    sha256_hex,
)


SAMPLE_BYTES = b"access-visioncheck-eval-bytes-v1"
SAMPLE_HASH = sha256_hex(SAMPLE_BYTES)
OTHER_BYTES = b"access-visioncheck-eval-bytes-v2"


def _mock_media_row(**overrides):
    from datetime import datetime, timezone

    base = {
        "id": 1,
        "uploaded_by": 1,
        "request_id": None,
        "file_name": "upload.jpg",
        "file_type": "photo",
        "file_url": "/uploads/images/x.jpg",
        "uploaded_at": datetime.now(timezone.utc),
        "evaluations": [],
        "ai_detection_results": [],
        "storage_removed_at": None,
    }
    base.update(overrides)
    return SimpleNamespace(**base)


def _resolved_database_url() -> str:
    from app.config import settings

    return (os.environ.get("DATABASE_URL") or settings.database_url or "").strip()


def _database_url_targets_waverep_test_only() -> bool:
    """True when the URL database name is exactly access_waverep_test."""
    url = _resolved_database_url().lower()
    match = re.search(r"/([^/?#]+)(?:\?|$)", url)
    return match is not None and match.group(1) == "access_waverep_test"


def _isolated_test_db_configured() -> bool:
    """Only allow DB-touching tests on the isolated WaveRep test database."""
    marker = os.environ.get("ACCESS_PYTEST_DB", "").strip()
    if marker != "access_waverep_test":
        return False
    return _database_url_targets_waverep_test_only()


def _assert_isolated_database_target() -> None:
    if not _isolated_test_db_configured():
        raise RuntimeError(
            "Refusing database access: set ACCESS_PYTEST_DB=access_waverep_test "
            "and DATABASE_URL must target database access_waverep_test only."
        )


class MediaFileHashTest(unittest.TestCase):
    def test_identical_bytes_same_hash_different_names_irrelevant(self) -> None:
        self.assertEqual(sha256_hex(SAMPLE_BYTES), sha256_hex(SAMPLE_BYTES))
        self.assertNotEqual(sha256_hex(SAMPLE_BYTES), sha256_hex(OTHER_BYTES))

    def test_duplicate_message_copy(self) -> None:
        self.assertIn("already been submitted", EVALUATION_DUPLICATE_UPLOAD_MESSAGE)


class CrudDuplicateTest(unittest.TestCase):
    def test_member_evaluation_hash_exists_ignores_date_and_archive(self) -> None:
        db = MagicMock()
        db.scalar.return_value = 1
        self.assertTrue(
            media_crud.member_evaluation_hash_exists(
                db, user_id=7, file_hash=SAMPLE_HASH
            )
        )
        query = db.scalar.call_args[0][0]
        compiled = str(query)
        self.assertIn("file_hash", compiled)
        self.assertIn("media_category", compiled)
        self.assertNotIn("archives", compiled.lower())

    def test_assert_duplicate_raises(self) -> None:
        db = MagicMock()
        db.scalar.return_value = 1
        with self.assertRaises(EvaluationDuplicateUploadError):
            media_crud.assert_member_evaluation_not_duplicate(
                db, user_id=1, file_hash=SAMPLE_HASH
            )

    def test_create_maps_unique_violation_to_duplicate_error(self) -> None:
        db = MagicMock()
        row = MagicMock(id=99)
        db.add = MagicMock()
        db.commit.side_effect = IntegrityError(
            "insert",
            {},
            Exception('duplicate key value violates unique constraint "uq_media_files_member_eval_file_hash"'),
        )
        db.rollback = MagicMock()
        with patch.object(media_crud, "MediaFile", return_value=row):
            with self.assertRaises(EvaluationDuplicateUploadError):
                media_crud.create(
                    db,
                    {
                        "uploaded_by": 1,
                        "file_hash": SAMPLE_HASH,
                        "media_category": "member_evaluation",
                        "file_name": "a.jpg",
                        "file_type": "photo",
                        "file_url": "/uploads/x.jpg",
                    },
                )
        db.rollback.assert_called_once()


class UploadRouteOrderTest(unittest.IsolatedAsyncioTestCase):
    async def _run_upload(
        self,
        *,
        content: bytes,
        request_id: int | None = None,
        file_name: str | None = None,
    ):
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "photo.jpg"
        upload.read = AsyncMock(return_value=content)

        user = SimpleNamespace(id=42)
        db = MagicMock()
        bg = MagicMock()

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                    ) as assert_dup:
                        with patch.object(
                            media_routes, "_member_evaluations_today", return_value=0
                        ) as count_today:
                            with patch.object(
                                media_routes, "evaluation_rules", return_value={"max_files_per_day": 5}
                            ):
                                with patch(
                                    "app.services.supabase_storage.is_supabase_storage_configured",
                                    return_value=False,
                                ):
                                    with patch(
                                        "app.services.firebase_storage.is_firebase_storage_configured",
                                        return_value=False,
                                    ):
                                        with patch.object(
                                            media_routes, "_ensure_upload_dir"
                                        ) as ensure_dir:
                                            tmp = MagicMock()
                                            tmp.__truediv__ = MagicMock(
                                                return_value=MagicMock(
                                                    write_bytes=MagicMock()
                                                )
                                            )
                                            ensure_dir.return_value = tmp
                                            with patch.object(
                                                media_routes.media_crud,
                                                "create",
                                                return_value=SimpleNamespace(id=1),
                                            ):
                                                with patch.object(
                                                    media_routes.media_crud,
                                                    "get",
                                                    return_value=_mock_media_row(),
                                                ):
                                                    with patch.object(
                                                        media_routes, "_media_out"
                                                    ):
                                                        with patch.object(
                                                            media_routes,
                                                            "stash_evaluation_upload",
                                                        ) as stash:
                                                            await media_routes.upload_media(
                                                                background_tasks=bg,
                                                                file=upload,
                                                                request_id=request_id,
                                                                file_name=file_name,
                                                                evaluation_metadata=None,
                                                                cloud_file_url=None,
                                                                db=db,
                                                                current_user=user,
                                                            )
                                                            return assert_dup, count_today, stash, bg

    async def test_duplicate_rejected_before_daily_limit(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "a.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)
        user = SimpleNamespace(id=5)
        db = MagicMock()

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                        side_effect=EvaluationDuplicateUploadError(),
                    ):
                        with patch.object(
                            media_routes, "_member_evaluations_today"
                        ) as count_today:
                            with self.assertRaises(HTTPException) as ctx:
                                await media_routes.upload_media(
                                    background_tasks=MagicMock(),
                                    file=upload,
                                    request_id=None,
                                    file_name="other-name.jpg",
                                    evaluation_metadata=None,
                                    cloud_file_url=None,
                                    db=db,
                                    current_user=user,
                                )
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail, EVALUATION_DUPLICATE_UPLOAD_MESSAGE)
        count_today.assert_not_called()

    async def test_duplicate_does_not_schedule_pipeline_or_xp_path(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "x.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True
                ):
                    with patch.object(
                        media_routes.media_crud,
                        "assert_member_evaluation_not_duplicate",
                        side_effect=EvaluationDuplicateUploadError(),
                    ):
                        with patch.object(
                            media_routes, "stash_evaluation_upload"
                        ) as stash:
                            with patch.object(
                                media_routes, "schedule_deferred_media_evaluation"
                            ) as schedule:
                                with self.assertRaises(HTTPException):
                                    await media_routes.upload_media(
                                        background_tasks=MagicMock(),
                                        file=upload,
                                        request_id=None,
                                        file_name=None,
                                        evaluation_metadata=None,
                                        cloud_file_url=None,
                                        db=MagicMock(),
                                        current_user=SimpleNamespace(id=1),
                                    )
        stash.assert_not_called()
        schedule.assert_not_called()

    async def test_different_files_pass_duplicate_gate(self) -> None:
        assert_dup, count_today, stash, bg = await self._run_upload(content=OTHER_BYTES)
        assert_dup.assert_called_once()
        hash_arg = assert_dup.call_args.kwargs["file_hash"]
        self.assertEqual(hash_arg, sha256_hex(OTHER_BYTES))
        count_today.assert_called_once()
        stash.assert_called_once()
        bg.add_task.assert_called_once()

    async def test_event_documentation_skips_duplicate_check(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "event.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)
        user = SimpleNamespace(id=3)
        db = MagicMock()

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.media_crud,
                    "assert_member_evaluation_not_duplicate",
                ) as assert_dup:
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
                                dest = MagicMock(write_bytes=MagicMock())
                                tmp.__truediv__ = MagicMock(return_value=dest)
                                ensure_dir.return_value = tmp
                                with patch.object(
                                    media_routes.media_crud,
                                    "create",
                                    return_value=SimpleNamespace(id=2),
                                ):
                                    with patch.object(
                                        media_routes.media_crud,
                                        "get",
                                        return_value=_mock_media_row(
                                            id=2, request_id=99
                                        ),
                                    ):
                                        with patch.object(media_routes, "_media_out"):
                                            with patch.object(
                                                media_routes, "stash_evaluation_upload"
                                            ) as stash:
                                                await media_routes.upload_media(
                                                    background_tasks=MagicMock(),
                                                    file=upload,
                                                    request_id=99,
                                                    file_name=None,
                                                    evaluation_metadata=None,
                                                    cloud_file_url=None,
                                                    db=db,
                                                    current_user=user,
                                                )
        assert_dup.assert_not_called()
        stash.assert_not_called()

    async def test_concurrent_race_cleans_storage_and_returns_409(self) -> None:
        from app.api.routes import media as media_routes

        upload = AsyncMock()
        upload.filename = "race.jpg"
        upload.read = AsyncMock(return_value=SAMPLE_BYTES)
        user = SimpleNamespace(id=8)

        with patch.object(media_routes, "_validate_upload_file"):
            with patch.object(media_routes, "is_video_extension", return_value=False):
                with patch.object(
                    media_routes.settings_crud, "is_ai_media_evaluation_enabled", return_value=True
                ):
                    with patch.object(
                        media_routes.media_crud, "assert_member_evaluation_not_duplicate"
                    ):
                        with patch.object(
                            media_routes, "_member_evaluations_today", return_value=0
                        ):
                            with patch.object(
                                media_routes, "evaluation_rules", return_value={"max_files_per_day": 5}
                            ):
                                with patch(
                                    "app.services.supabase_storage.is_supabase_storage_configured",
                                    return_value=False,
                                ):
                                    with patch(
                                        "app.services.firebase_storage.is_firebase_storage_configured",
                                        return_value=False,
                                    ):
                                        with patch.object(
                                            media_routes, "_ensure_upload_dir"
                                        ) as ensure_dir:
                                            tmp = MagicMock()
                                            tmp.__truediv__ = MagicMock(
                                                return_value=MagicMock(write_bytes=MagicMock())
                                            )
                                            ensure_dir.return_value = tmp
                                            with patch.object(
                                                media_routes.media_crud,
                                                "create",
                                                side_effect=EvaluationDuplicateUploadError(),
                                            ):
                                                with patch.object(
                                                    media_routes.media_crud,
                                                    "discard_stored_upload_blob",
                                                ) as discard:
                                                    with self.assertRaises(HTTPException) as ctx:
                                                        await media_routes.upload_media(
                                                            background_tasks=MagicMock(),
                                                            file=upload,
                                                            request_id=None,
                                                            file_name=None,
                                                            evaluation_metadata=None,
                                                            cloud_file_url=None,
                                                            db=MagicMock(),
                                                            current_user=user,
                                                        )
        self.assertEqual(ctx.exception.status_code, 409)
        discard.assert_called_once()


@pytest.mark.skipif(
    not _isolated_test_db_configured(),
    reason="Set ACCESS_PYTEST_DB=access_waverep_test and DATABASE_URL to access_waverep_test only",
)
class EvaluationDuplicateIntegrationTest(unittest.TestCase):
    """Optional Postgres integration (isolated DB only)."""

    db: object
    user_id: int

    @classmethod
    def setUpClass(cls) -> None:
        _assert_isolated_database_target()
        from app.database import SessionLocal

        cls.db = SessionLocal()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.db.close()

    def setUp(self) -> None:
        _assert_isolated_database_target()
        from sqlalchemy import select

        from app.core.security import hash_password
        from app.models.role import Role
        from app.models.user import User

        self._created_media_ids: list[int] = []
        self._created_user_id: int | None = None
        self.addCleanup(self._tear_down_integration_rows)

        role_id = self.db.scalar(
            select(Role.id).where(Role.role_name == "Member").limit(1)
        )
        self.assertIsNotNone(role_id, "Member role must exist in access_waverep_test")

        suffix = uuid.uuid4().hex[:16]
        user = User(
            fullname="Dup Upload Integration",
            email=f"dup-upload-{suffix}@access.test",
            password=hash_password("integration-test-only"),
            role_id=role_id,
            status="approved",
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        self._created_user_id = user.id
        self.user_id = user.id

    def _tear_down_integration_rows(self) -> None:
        _assert_isolated_database_target()
        from app.models.media_file import MediaFile
        from app.models.user import User

        db = self.db
        try:
            for media_id in self._created_media_ids:
                row = db.get(MediaFile, media_id)
                if row is not None:
                    db.delete(row)
            if self._created_user_id is not None:
                row = db.get(User, self._created_user_id)
                if row is not None:
                    db.delete(row)
            db.commit()
        except Exception:
            db.rollback()
            raise

    def test_same_hash_another_day_still_blocked(self) -> None:
        from datetime import datetime, timedelta, timezone

        from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
        from app.models.media_file import MediaFile

        _assert_isolated_database_target()
        file_hash = sha256_hex(b"integration-dup-bytes")
        old = MediaFile(
            uploaded_by=self.user_id,
            request_id=None,
            file_name="old.jpg",
            file_type="photo",
            file_url="/uploads/__test__/old.jpg",
            media_category=MEDIA_CATEGORY_EVALUATION,
            file_hash=file_hash,
            uploaded_at=datetime.now(timezone.utc) - timedelta(days=30),
        )
        self.db.add(old)
        self.db.commit()
        self.db.refresh(old)
        self._created_media_ids.append(old.id)
        self.assertTrue(
            media_crud.member_evaluation_hash_exists(
                self.db, user_id=self.user_id, file_hash=file_hash
            )
        )


if __name__ == "__main__":
    unittest.main()
