"""Fail-closed guards for grandfather snapshot --apply (staging only)."""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.env_bootstrap import active_env_file_path

STAGING_DATABASE_NAME = "access_skillprogression_staging"
STAGING_DATABASE_ROLE = "access_skillprogression_app"
STAGING_ENV_FILE_NAME = ".env.skillprogression_staging"
FORBIDDEN_APPLY_DATABASES = frozenset(
    {
        "postgres",
        "access_uat",
        "access_waverep_test",
    }
)
ALLOWED_DB_HOSTS = frozenset({"localhost", "127.0.0.1", "::1"})


class CaptureApplySafetyError(RuntimeError):
    """Raised when grandfather --apply would run outside approved staging."""


def _policy_is_v1(raw: str) -> bool:
    label = (raw or "v1").strip().lower()
    return label in ("v1", "legacy", "1")


def assert_capture_apply_safe(db: Session) -> None:
    """Verify live connection + config before grandfather snapshot writes."""
    env_path = active_env_file_path()
    if env_path is None:
        raise CaptureApplySafetyError(
            "ACCESS_ENV_FILE must point to .env.skillprogression_staging before --apply."
        )
    if env_path.name != STAGING_ENV_FILE_NAME:
        raise CaptureApplySafetyError(
            f"Expected env file {STAGING_ENV_FILE_NAME}, got {env_path.name}."
        )

    if settings.db_name != STAGING_DATABASE_NAME:
        raise CaptureApplySafetyError(
            f"Configured DB_NAME={settings.db_name!r}, expected {STAGING_DATABASE_NAME!r}."
        )
    if not _policy_is_v1(settings.skill_progression_active_policy):
        raise CaptureApplySafetyError(
            "SKILL_PROGRESSION_ACTIVE_POLICY must be v1 for grandfather capture --apply."
        )

    host = (settings.db_host or "").strip().lower()
    if host not in ALLOWED_DB_HOSTS:
        raise CaptureApplySafetyError(
            f"DB_HOST={settings.db_host!r} is not an allowed local staging host."
        )
    if settings.db_port != 5432:
        raise CaptureApplySafetyError(
            f"DB_PORT={settings.db_port} is not the approved staging port 5432."
        )

    row = db.execute(
        text(
            "SELECT current_database() AS db, current_user AS role, "
            "inet_server_port() AS port"
        )
    ).mappings().one()
    live_db = str(row["db"])
    live_role = str(row["role"])
    live_port = row["port"]

    if live_db in FORBIDDEN_APPLY_DATABASES:
        raise CaptureApplySafetyError(
            f"Refusing --apply on forbidden database {live_db!r}."
        )
    if live_db != STAGING_DATABASE_NAME:
        raise CaptureApplySafetyError(
            f"current_database()={live_db!r}, expected {STAGING_DATABASE_NAME!r}."
        )
    if live_role != STAGING_DATABASE_ROLE:
        raise CaptureApplySafetyError(
            f"current_user={live_role!r}, expected {STAGING_DATABASE_ROLE!r}."
        )
    if live_port is not None and int(live_port) != 5432:
        raise CaptureApplySafetyError(
            f"Connected PostgreSQL port {live_port}, expected 5432."
        )

    priv = db.execute(
        text(
            "SELECT rolsuper, rolcreatedb, rolcreaterole "
            "FROM pg_roles WHERE rolname = current_user"
        )
    ).mappings().one()
    if priv["rolsuper"] or priv["rolcreatedb"] or priv["rolcreaterole"]:
        raise CaptureApplySafetyError(
            "Staging capture role must not have SUPERUSER, CREATEDB, or CREATEROLE."
        )
