"""Phase 1: submission chain schema, backfill, read metadata (isolated DB)."""

from __future__ import annotations

import os
import re
import unittest

import pytest
from sqlalchemy import inspect, text

from app.config import settings
from app.database import SessionLocal, engine
from app.migrations._migration_guard import dispose_engine_pool
from app.migrations.submission_chains_phase1 import (
    MIGRATION_ID,
    downgrade_submission_chains_phase1,
    upgrade_submission_chains_phase1,
)
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION, MEDIA_CATEGORY_EVENT
from app.models.media_file import MediaFile
from app.models.submission_chain import SubmissionChain
from app.models.submission_chain_constants import XP_RECONCILIATION_PENDING
from app.models.user import User
from app.services.submission_chain_read import chain_metadata_for_media


def _resolved_database_url() -> str:
    return (os.environ.get("DATABASE_URL") or settings.database_url or "").strip()


def _database_url_targets_waverep_test_only() -> bool:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() == "access_waverep_test":
        return True
    url = _resolved_database_url().lower()
    match = re.search(r"/([^/?#]+)(?:\?|$)", url)
    return match is not None and match.group(1) == "access_waverep_test"


def _isolated_test_db_configured() -> bool:
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


def _prepare_migration() -> None:
    dispose_engine_pool(engine)
    with engine.connect() as conn:
        from sqlalchemy import text

        db = conn.execute(text("SELECT current_database()")).scalar()
        if db != "access_waverep_test":
            raise RuntimeError(f"Refusing migration on database {db!r}")


class SubmissionChainsPhase1ConfigTest(unittest.TestCase):
    def test_migration_id(self) -> None:
        self.assertEqual(MIGRATION_ID, "submission_chains_phase1_20261027")

    def test_replacement_upload_disabled_by_default(self) -> None:
        self.assertFalse(settings.replacement_upload_enabled)


@pytest.mark.skipif(
    not _isolated_test_db_configured(),
    reason="Set ACCESS_PYTEST_DB=access_waverep_test and DATABASE_URL to access_waverep_test only",
)
class SubmissionChainsPhase1DbTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        _assert_isolated_database_target()
        _prepare_migration()
        upgrade_submission_chains_phase1(engine)

    @classmethod
    def tearDownClass(cls) -> None:
        # Do not downgrade on access_waverep_test: leaves QA API + admin UI broken
        # (missing submission_chain_id) while manual Phase 4/5 verification runs.
        pass

    def test_tables_and_partial_unique_indexes_exist(self) -> None:
        insp = inspect(engine)
        self.assertIn("submission_chains", insp.get_table_names())
        self.assertIn("submission_chain_events", insp.get_table_names())
        cols = {c["name"] for c in insp.get_columns("media_files")}
        self.assertIn("submission_chain_id", cols)
        self.assertIn("replaces_media_id", cols)
        self.assertIn("replacement_lifecycle", cols)

        with engine.connect() as conn:
            idx = conn.execute(
                text(
                    "SELECT indexname FROM pg_indexes "
                    "WHERE indexname = 'uq_submission_chain_one_active_replacement'"
                )
            ).fetchone()
            self.assertIsNotNone(idx)

    def test_backfill_creates_one_chain_per_member_evaluation(self) -> None:
        db = SessionLocal()
        try:
            user = db.query(User).first()
            if user is None:
                self.skipTest("No users in isolated DB")
            member_id = user.id
            eval_media = MediaFile(
                uploaded_by=member_id,
                file_name="phase1_eval_test.jpg",
                file_type="photo",
                file_url="/uploads/images/phase1_eval_test.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            event_media = MediaFile(
                uploaded_by=member_id,
                file_name="phase1_event_test.jpg",
                file_type="photo",
                file_url="/uploads/images/phase1_event_test.jpg",
                media_category=MEDIA_CATEGORY_EVENT,
            )
            db.add(eval_media)
            db.add(event_media)
            db.commit()
            db.refresh(eval_media)
            db.refresh(event_media)
            db.close()

            _prepare_migration()
            upgrade_submission_chains_phase1(engine)

            db = SessionLocal()
            eval_id = eval_media.id
            event_id = event_media.id
            eval_media = db.get(MediaFile, eval_id)
            event_media = db.get(MediaFile, event_id)
            assert eval_media is not None and event_media is not None

            self.assertIsNotNone(eval_media.submission_chain_id)
            chain = db.get(SubmissionChain, eval_media.submission_chain_id)
            self.assertIsNotNone(chain)
            assert chain is not None
            self.assertEqual(chain.root_media_id, eval_media.id)
            self.assertEqual(chain.member_id, member_id)
            self.assertEqual(chain.xp_awarded_total, 0)
            self.assertFalse(chain.xp_award_locked)
            self.assertEqual(chain.xp_reconciliation_status, XP_RECONCILIATION_PENDING)

            self.assertIsNone(event_media.submission_chain_id)

            meta = chain_metadata_for_media(db, eval_media)
            self.assertEqual(meta["chain_role"], "root")
            self.assertEqual(meta["chain_root_media_id"], eval_media.id)
            self.assertEqual(meta["xp_reconciliation_status"], XP_RECONCILIATION_PENDING)
        finally:
            db.close()

    def test_active_replacement_unique_constraint(self) -> None:
        db = SessionLocal()
        try:
            user = db.query(User).first()
            if user is None:
                self.skipTest("No users in isolated DB")
            member_id = user.id
            root = MediaFile(
                uploaded_by=member_id,
                file_name="root.jpg",
                file_type="photo",
                file_url="/uploads/images/root.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
            )
            db.add(root)
            db.commit()
            db.refresh(root)
            root_id = root.id
            db.close()

            _prepare_migration()
            upgrade_submission_chains_phase1(engine)

            db = SessionLocal()
            root = db.get(MediaFile, root_id)
            assert root is not None
            chain_id = root.submission_chain_id
            self.assertIsNotNone(chain_id)

            first = MediaFile(
                uploaded_by=member_id,
                file_name="rep1.jpg",
                file_type="photo",
                file_url="/uploads/images/rep1.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
                submission_chain_id=chain_id,
                replaces_media_id=root.id,
                replacement_lifecycle="active",
            )
            db.add(first)
            db.commit()

            second = MediaFile(
                uploaded_by=member_id,
                file_name="rep2.jpg",
                file_type="photo",
                file_url="/uploads/images/rep2.jpg",
                media_category=MEDIA_CATEGORY_EVALUATION,
                submission_chain_id=chain_id,
                replaces_media_id=root.id,
                replacement_lifecycle="active",
            )
            db.add(second)
            with self.assertRaises(Exception):
                db.commit()
            db.rollback()
        finally:
            db.close()

    def test_downgrade_removes_chain_schema(self) -> None:
        _prepare_migration()
        downgrade_submission_chains_phase1(engine)
        insp = inspect(engine)
        self.assertNotIn("submission_chains", insp.get_table_names())
        _prepare_migration()
        upgrade_submission_chains_phase1(engine)
