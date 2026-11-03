"""Fail-closed guards for shared-development grandfather capture --apply only."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.env_bootstrap import active_env_file_path
from app.services.skill_progression import build_skill_progression_snapshot
from app.services.skill_progression_capture_manifest import SharedDevCaptureManifest
from app.services.skill_progression_policy import POLICY_V1, configured_skill_progression_policy

SHARED_DEV_DATABASE_NAME = "postgres"
STAGING_ENV_FILE_NAME = ".env.skillprogression_staging"
FORBIDDEN_DATABASES = frozenset(
    {
        "access_skillprogression_staging",
        "access_uat",
        "access_waverep_test",
    }
)
ALLOWED_DB_HOSTS = frozenset({"localhost", "127.0.0.1", "::1"})
APPLY_APPROVAL_ENV = "GRANDFATHER_SHARED_DEV_APPLY_APPROVED"


class SharedDevCaptureSafetyError(RuntimeError):
    """Raised when shared-dev grandfather capture preconditions fail."""


def _policy_is_v1(raw: str) -> bool:
    label = (raw or "v1").strip().lower()
    return label in ("v1", "legacy", "1")


def assert_operator_apply_approved() -> None:
    if os.environ.get(APPLY_APPROVAL_ENV) != "1":
        raise SharedDevCaptureSafetyError(
            f"Set {APPLY_APPROVAL_ENV}=1 in the operator shell to authorize --apply."
        )


def assert_shared_dev_env_file_safe() -> None:
    env_path = active_env_file_path()
    if env_path is not None and env_path.name == STAGING_ENV_FILE_NAME:
        raise SharedDevCaptureSafetyError(
            f"Unset ACCESS_ENV_FILE (staging file {STAGING_ENV_FILE_NAME} must not be loaded)."
        )


def validate_backup_archive(manifest: SharedDevCaptureManifest) -> None:
    path = manifest.backup_dump_path
    if not path.is_file():
        raise SharedDevCaptureSafetyError(f"Backup archive missing: {path}")
    size = path.stat().st_size
    if size < manifest.min_backup_bytes:
        raise SharedDevCaptureSafetyError(
            f"Backup archive too small ({size} bytes): {path}"
        )
    header = path.read_bytes()[:5]
    if header != b"PGDMP":
        raise SharedDevCaptureSafetyError(
            f"Backup is not PostgreSQL custom format (PGDMP): {path}"
        )
    pg_restore = _find_pg_restore()
    if pg_restore is None:
        return
    proc = subprocess.run(
        [pg_restore, "--list", str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise SharedDevCaptureSafetyError(
            f"pg_restore --list failed for backup archive (exit {proc.returncode})."
        )


def _find_pg_restore() -> str | None:
    for candidate in (
        Path(r"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe"),
        Path(r"C:\Program Files\PostgreSQL\17\bin\pg_restore.exe"),
        Path(r"C:\Program Files\PostgreSQL\16\bin\pg_restore.exe"),
    ):
        if candidate.is_file():
            return str(candidate)
    return None


def _live_identity(db: Session) -> dict:
    return dict(
        db.execute(
            text(
                "SELECT current_database() AS db, current_user AS role, "
                "inet_server_addr() AS host, inet_server_port() AS port"
            ),
        ).mappings().one()
    )


def assert_shared_dev_live_identity(
    db: Session,
    manifest: SharedDevCaptureManifest,
) -> dict:
    assert_shared_dev_env_file_safe()
    if settings.db_name != SHARED_DEV_DATABASE_NAME:
        raise SharedDevCaptureSafetyError(
            f"Configured DB_NAME={settings.db_name!r}, expected {SHARED_DEV_DATABASE_NAME!r}."
        )
    if not _policy_is_v1(settings.skill_progression_active_policy):
        raise SharedDevCaptureSafetyError(
            "SKILL_PROGRESSION_ACTIVE_POLICY must be v1 for shared-dev capture."
        )
    if configured_skill_progression_policy() != POLICY_V1:
        raise SharedDevCaptureSafetyError("Effective skill progression policy is not v1.")

    host = (settings.db_host or "").strip().lower()
    if host not in ALLOWED_DB_HOSTS:
        raise SharedDevCaptureSafetyError(
            f"DB_HOST={settings.db_host!r} is not an allowed local shared-dev host."
        )
    if settings.db_port != 5432:
        raise SharedDevCaptureSafetyError(
            f"DB_PORT={settings.db_port} is not the approved shared-dev port 5432."
        )

    row = _live_identity(db)
    live_db = str(row["db"])
    live_role = str(row["role"])
    live_port = row["port"]

    if live_db in FORBIDDEN_DATABASES:
        raise SharedDevCaptureSafetyError(
            f"Refusing shared-dev capture on forbidden database {live_db!r}."
        )
    if live_db != SHARED_DEV_DATABASE_NAME:
        raise SharedDevCaptureSafetyError(
            f"current_database()={live_db!r}, expected {SHARED_DEV_DATABASE_NAME!r}."
        )
    if live_role != manifest.expected_database_role:
        raise SharedDevCaptureSafetyError(
            f"current_user={live_role!r}, expected {manifest.expected_database_role!r}."
        )
    if live_port is not None and int(live_port) != 5432:
        raise SharedDevCaptureSafetyError(
            f"Connected PostgreSQL port {live_port}, expected 5432."
        )
    return row


def _approved_member_count(db: Session) -> int:
    return int(
        db.execute(
            text(
                "SELECT count(*) FROM users u JOIN roles r ON r.id = u.role_id "
                "WHERE lower(r.role_name) = 'member' AND lower(u.status) = 'approved'"
            ),
        ).scalar()
        or 0
    )


def _admin_override_count(db: Session) -> int:
    return int(
        db.execute(
            text(
                "SELECT count(*) FROM member_rankings "
                "WHERE competency_level_override IS NOT NULL "
                "AND trim(competency_level_override) <> ''"
            ),
        ).scalar()
        or 0
    )


def load_baseline_member_section(manifest: SharedDevCaptureManifest) -> dict:
    path = manifest.baseline_json_path
    if not path.is_file():
        raise SharedDevCaptureSafetyError(f"Baseline JSON missing: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    member = data.get("member_77") or data.get("target_member")
    if not isinstance(member, dict):
        raise SharedDevCaptureSafetyError("Baseline JSON missing member_77 section.")
    return member


def assert_baseline_matches_live(
    manifest: SharedDevCaptureManifest,
    live_member: dict,
) -> None:
    baseline = load_baseline_member_section(manifest)
    exp = manifest.expected
    pairs = [
        ("computed_tier_v1_policy", live_member["computed_tier_v1"], exp.computed_tier_v1),
        ("effective_tier", live_member.get("effective_tier"), baseline.get("effective_tier")),
        (
            "eligible_evaluation_count",
            live_member.get("eligible_evaluation_count"),
            baseline.get("eligible_evaluation_count"),
        ),
    ]
    if exp.users_skill_level_id is not None:
        pairs.append(
            (
                "users_skill_level_id",
                live_member.get("users_skill_level_id"),
                exp.users_skill_level_id,
            )
        )
    if exp.total_points is not None:
        pairs.append(
            ("total_points", live_member.get("total_points"), exp.total_points)
        )
    for label, live_val, expected in pairs:
        if expected is None:
            continue
        if live_val != expected:
            raise SharedDevCaptureSafetyError(
                f"Baseline/live mismatch for {label}: live={live_val!r} expected={expected!r}."
            )


def collect_target_row_state(db: Session, manifest: SharedDevCaptureManifest) -> dict:
    exp = manifest.expected
    row = db.execute(
        text(
            "SELECT id, user_id, skill_tier_grandfather_floor, "
            "skill_tier_grandfather_captured_at, skill_tier_grandfather_from_policy, "
            "competency_level_override, total_points "
            "FROM member_rankings WHERE id = :rid AND user_id = :uid"
        ),
        {"rid": exp.target_ranking_id, "uid": exp.target_user_id},
    ).mappings().one_or_none()
    if row is None:
        raise SharedDevCaptureSafetyError(
            f"Ranking row id={exp.target_ranking_id} user_id={exp.target_user_id} not found."
        )
    snap = build_skill_progression_snapshot(db, exp.target_user_id)
    skill_level_id = db.execute(
        text("SELECT skill_level_id FROM users WHERE id = :uid"),
        {"uid": exp.target_user_id},
    ).scalar()
    return {
        "ranking_id": int(row["id"]),
        "user_id": int(row["user_id"]),
        "grandfather_floor": row["skill_tier_grandfather_floor"],
        "grandfather_captured_at": row["skill_tier_grandfather_captured_at"],
        "grandfather_from_policy": row["skill_tier_grandfather_from_policy"],
        "competency_level_override": row["competency_level_override"],
        "total_points": int(row["total_points"] or 0),
        "computed_tier_v1": snap.computed_tier_v1,
        "effective_tier": snap.effective_tier,
        "eligible_evaluation_count": snap.eligible_evaluation_count,
        "users_skill_level_id": skill_level_id,
    }


def assert_shared_dev_preflight(
    db: Session,
    manifest: SharedDevCaptureManifest,
    *,
    require_null_grandfather: bool = True,
) -> dict:
    """Read-only checks; returns target row state dict for display."""
    if not manifest.shared_development_mode:
        raise SharedDevCaptureSafetyError("Manifest shared_development_mode must be true.")

    identity = assert_shared_dev_live_identity(db, manifest)
    validate_backup_archive(manifest)

    approved = _approved_member_count(db)
    overrides = _admin_override_count(db)
    exp = manifest.expected

    if approved != exp.approved_member_count:
        raise SharedDevCaptureSafetyError(
            f"Approved member count {approved}, expected {exp.approved_member_count}."
        )
    if overrides != exp.admin_override_count:
        raise SharedDevCaptureSafetyError(
            f"Admin override count {overrides}, expected {exp.admin_override_count}."
        )

    target = collect_target_row_state(db, manifest)
    if target["user_id"] != exp.target_user_id:
        raise SharedDevCaptureSafetyError("Target user_id mismatch.")
    if target["ranking_id"] != exp.target_ranking_id:
        raise SharedDevCaptureSafetyError("Target ranking id mismatch.")
    if target["computed_tier_v1"] != exp.computed_tier_v1:
        raise SharedDevCaptureSafetyError(
            f"computed_tier_v1={target['computed_tier_v1']!r}, "
            f"expected {exp.computed_tier_v1!r}."
        )
    if target["competency_level_override"]:
        raise SharedDevCaptureSafetyError(
            "Target member has competency_level_override; aborting."
        )

    floor = target["grandfather_floor"]
    if require_null_grandfather:
        if floor is not None and str(floor).strip():
            raise SharedDevCaptureSafetyError(
                "Grandfather floor already set; refusing to overwrite."
            )
        if target["grandfather_captured_at"] is not None:
            raise SharedDevCaptureSafetyError("grandfather_captured_at already set.")
        if target["grandfather_from_policy"] is not None and str(
            target["grandfather_from_policy"]
        ).strip():
            raise SharedDevCaptureSafetyError("grandfather_from_policy already set.")

    would_capture = 1 if require_null_grandfather and not (floor and str(floor).strip()) else 0
    if would_capture != exp.would_capture_count:
        raise SharedDevCaptureSafetyError(
            f"would_capture={would_capture}, expected {exp.would_capture_count}."
        )

    assert_baseline_matches_live(manifest, target)
    target["live_identity"] = identity
    return target
