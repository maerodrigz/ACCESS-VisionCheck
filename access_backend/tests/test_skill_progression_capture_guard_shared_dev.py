"""Tests for shared-dev grandfather capture guards (isolated mocks only)."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from app.services.skill_progression_capture_guard_shared_dev import (
    SHARED_DEV_DATABASE_NAME,
    SharedDevCaptureSafetyError,
    assert_operator_apply_approved,
    assert_shared_dev_live_identity,
    assert_shared_dev_preflight,
    validate_backup_archive,
)
from app.services.skill_progression_capture_manifest import SharedDevCaptureManifest
from app.services.skill_progression_grandfather_capture_shared_dev import (
    apply_shared_dev_grandfather_capture,
    plan_shared_dev_capture,
)


def _manifest(tmp_path: Path) -> SharedDevCaptureManifest:
    backup = tmp_path / "backup.dump"
    backup.write_bytes(b"PGDMP" + b"\x00" * 2000)
    baseline = tmp_path / "baseline.json"
    baseline.write_text(
        json.dumps(
            {
                "member_77": {
                    "computed_tier_v1_policy": "Intermediate",
                    "effective_tier": "Intermediate",
                    "eligible_evaluation_count": 3,
                    "users_skill_level_id": 3,
                    "total_points": 208,
                }
            }
        ),
        encoding="utf-8",
    )
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "shared_development_mode": True,
                "backup_dump_path": str(backup),
                "baseline_json_path": str(baseline),
                "expected_database_role": "postgres",
                "expected": {
                    "approved_member_count": 1,
                    "would_capture_count": 1,
                    "target_user_id": 77,
                    "target_ranking_id": 62,
                    "computed_tier_v1": "Intermediate",
                    "admin_override_count": 0,
                    "users_skill_level_id": 3,
                    "total_points": 208,
                },
            }
        ),
        encoding="utf-8",
    )
    return SharedDevCaptureManifest.load(manifest_path)


def _identity_db(
    *,
    db_name: str = SHARED_DEV_DATABASE_NAME,
    role: str = "postgres",
    port: int = 5432,
    approved: int = 1,
    overrides: int = 0,
    ranking_row: dict | None = None,
    tier: str = "Intermediate",
) -> MagicMock:
    db = MagicMock()
    ranking_row = ranking_row or {
        "id": 62,
        "user_id": 77,
        "skill_tier_grandfather_floor": None,
        "skill_tier_grandfather_captured_at": None,
        "skill_tier_grandfather_from_policy": None,
        "competency_level_override": None,
        "total_points": 208,
    }

    def execute(stmt, params=None):
        sql = str(stmt)
        m = MagicMock()
        if "current_database()" in sql:
            m.mappings.return_value.one.return_value = {
                "db": db_name,
                "role": role,
                "host": "::1",
                "port": port,
            }
        elif "count(*) FROM users u JOIN roles" in sql:
            m.scalar.return_value = approved
        elif "competency_level_override" in sql and "count" in sql:
            m.scalar.return_value = overrides
        elif "FROM member_rankings WHERE id" in sql:
            m.mappings.return_value.one_or_none.return_value = ranking_row
        elif "skill_level_id FROM users" in sql:
            m.scalar.return_value = 3
        elif "UPDATE member_rankings" in sql:
            m.rowcount = 1
        else:
            m.scalar.return_value = None
            m.mappings.return_value.one_or_none.return_value = None
        return m

    db.execute.side_effect = execute
    return db


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
@patch("app.services.skill_progression_capture_guard_shared_dev.build_skill_progression_snapshot")
@patch("app.services.skill_progression_capture_guard_shared_dev.validate_backup_archive")
def test_preflight_accepts_valid_state(
    mock_backup, mock_snap, mock_env, mock_settings, mock_configured, tmp_path
) -> None:
    mock_env.return_value = None
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_configured.return_value = "v1"
    snap = MagicMock()
    snap.computed_tier_v1 = "Intermediate"
    snap.effective_tier = "Intermediate"
    snap.eligible_evaluation_count = 3
    mock_snap.return_value = snap

    manifest = _manifest(tmp_path)
    db = _identity_db()
    assert_shared_dev_preflight(db, manifest)


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
def test_rejects_staging_env_file(mock_env, mock_settings, mock_configured, tmp_path) -> None:
    from pathlib import Path

    mock_env.return_value = Path("/x/.env.skillprogression_staging")
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_configured.return_value = "v1"
    manifest = _manifest(tmp_path)
    db = _identity_db()
    with pytest.raises(SharedDevCaptureSafetyError, match="staging file"):
        assert_shared_dev_live_identity(db, manifest)


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
def test_rejects_wrong_database(mock_env, mock_settings, mock_configured, tmp_path) -> None:
    mock_env.return_value = None
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_configured.return_value = "v1"
    manifest = _manifest(tmp_path)
    db = _identity_db(db_name="access_skillprogression_staging")
    with pytest.raises(SharedDevCaptureSafetyError, match="forbidden"):
        assert_shared_dev_live_identity(db, manifest)


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
def test_rejects_v2_policy(mock_env, mock_settings, mock_configured, tmp_path) -> None:
    mock_env.return_value = None
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v2"
    mock_configured.return_value = "v2"
    manifest = _manifest(tmp_path)
    db = _identity_db()
    with pytest.raises(SharedDevCaptureSafetyError, match="v1"):
        assert_shared_dev_live_identity(db, manifest)


def test_operator_apply_approval_required() -> None:
    with patch.dict("os.environ", {}, clear=True):
        with pytest.raises(SharedDevCaptureSafetyError, match="GRANDFATHER"):
            assert_operator_apply_approved()


def test_invalid_backup_rejected(tmp_path) -> None:
    bad = tmp_path / "bad.dump"
    bad.write_bytes(b"NOTPG" + b"\x00" * 2000)
    baseline = tmp_path / "baseline.json"
    baseline.write_text(json.dumps({"member_77": {}}), encoding="utf-8")
    manifest_path = tmp_path / "m2.json"
    manifest_path.write_text(
        json.dumps(
            {
                "shared_development_mode": True,
                "backup_dump_path": str(bad),
                "baseline_json_path": str(baseline),
                "expected": {
                    "approved_member_count": 1,
                    "would_capture_count": 1,
                    "target_user_id": 77,
                    "target_ranking_id": 62,
                    "computed_tier_v1": "Intermediate",
                    "admin_override_count": 0,
                },
            }
        ),
        encoding="utf-8",
    )
    manifest = SharedDevCaptureManifest.load(manifest_path)
    with pytest.raises(SharedDevCaptureSafetyError, match="custom format"):
        validate_backup_archive(manifest)


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
@patch("app.services.skill_progression_capture_guard_shared_dev.build_skill_progression_snapshot")
@patch("app.services.skill_progression_capture_guard_shared_dev.validate_backup_archive")
def test_rejects_existing_grandfather_floor(
    mock_backup, mock_snap, mock_env, mock_settings, mock_configured, tmp_path
) -> None:
    mock_env.return_value = None
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_configured.return_value = "v1"
    snap = MagicMock()
    snap.computed_tier_v1 = "Intermediate"
    snap.effective_tier = "Intermediate"
    snap.eligible_evaluation_count = 3
    mock_snap.return_value = snap

    manifest = _manifest(tmp_path)
    db = _identity_db(
        ranking_row={
            "id": 62,
            "user_id": 77,
            "skill_tier_grandfather_floor": "Intermediate",
            "skill_tier_grandfather_captured_at": None,
            "skill_tier_grandfather_from_policy": None,
            "competency_level_override": None,
            "total_points": 208,
        }
    )
    with pytest.raises(SharedDevCaptureSafetyError, match="already set"):
        assert_shared_dev_preflight(db, manifest)


@patch("app.services.skill_progression_grandfather_capture_shared_dev.assert_operator_apply_approved")
@patch("app.services.skill_progression_grandfather_capture_shared_dev.assert_shared_dev_live_identity")
@patch("app.services.skill_progression_grandfather_capture_shared_dev.assert_shared_dev_preflight")
@patch("app.services.skill_progression_grandfather_capture_shared_dev.collect_target_row_state")
def test_apply_updates_exactly_one_row(
    mock_collect, mock_preflight, mock_identity, mock_approve, tmp_path
) -> None:
    mock_collect.return_value = {
        "ranking_id": 62,
        "user_id": 77,
        "computed_tier_v1": "Intermediate",
    }
    manifest = _manifest(tmp_path)
    db = MagicMock()
    db.begin.return_value.__enter__ = MagicMock(return_value=None)
    db.begin.return_value.__exit__ = MagicMock(return_value=False)

    locked = {
        "id": 62,
        "user_id": 77,
        "skill_tier_grandfather_floor": None,
        "skill_tier_grandfather_captured_at": None,
        "skill_tier_grandfather_from_policy": None,
    }

    def execute(stmt, params=None):
        sql = str(stmt)
        m = MagicMock()
        if "FOR UPDATE" in sql:
            m.mappings.return_value.one_or_none.return_value = locked
        elif "UPDATE member_rankings" in sql:
            m.rowcount = 1
        else:
            m.mappings.return_value.one_or_none.return_value = locked
        return m

    db.execute.side_effect = execute
    plan = apply_shared_dev_grandfather_capture(db, manifest)
    assert plan.target_ranking_id == 62
    assert plan.floor_after == "Intermediate"


@patch("app.services.skill_progression_capture_guard_shared_dev.configured_skill_progression_policy")
@patch("app.services.skill_progression_capture_guard_shared_dev.settings")
@patch("app.services.skill_progression_capture_guard_shared_dev.active_env_file_path")
@patch("app.services.skill_progression_capture_guard_shared_dev.build_skill_progression_snapshot")
@patch("app.services.skill_progression_capture_guard_shared_dev.validate_backup_archive")
def test_plan_dry_run_does_not_commit(
    mock_backup, mock_snap, mock_env, mock_settings, mock_configured, tmp_path
) -> None:
    mock_env.return_value = None
    mock_settings.db_name = SHARED_DEV_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_configured.return_value = "v1"
    snap = MagicMock()
    snap.computed_tier_v1 = "Intermediate"
    snap.effective_tier = "Intermediate"
    snap.eligible_evaluation_count = 3
    mock_snap.return_value = snap

    manifest = _manifest(tmp_path)
    db = _identity_db()
    plan = plan_shared_dev_capture(db, manifest, apply=False)
    assert plan.mode == "DRY-RUN"
    db.commit.assert_not_called()
