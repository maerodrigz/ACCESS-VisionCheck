"""Regression tests for grandfather capture --apply safety guard."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.skill_progression_capture_guard import (
    STAGING_DATABASE_NAME,
    STAGING_DATABASE_ROLE,
    CaptureApplySafetyError,
    assert_capture_apply_safe,
)


def _mock_db(
    *,
    current_db: str = STAGING_DATABASE_NAME,
    current_user: str = STAGING_DATABASE_ROLE,
    port: int = 5432,
    superuser: bool = False,
) -> MagicMock:
    db = MagicMock()
    results = [
        MagicMock(
            mappings=MagicMock(
                return_value=MagicMock(
                    one=MagicMock(
                        return_value={
                            "db": current_db,
                            "role": current_user,
                            "port": port,
                        }
                    )
                )
            )
        ),
        MagicMock(
            mappings=MagicMock(
                return_value=MagicMock(
                    one=MagicMock(
                        return_value={
                            "rolsuper": superuser,
                            "rolcreatedb": False,
                            "rolcreaterole": False,
                        }
                    )
                )
            )
        ),
    ]
    db.execute.side_effect = results
    return db


@patch("app.services.skill_progression_capture_guard.active_env_file_path")
@patch("app.services.skill_progression_capture_guard.settings")
def test_apply_guard_accepts_staging(mock_settings, mock_env) -> None:
    from pathlib import Path

    mock_env.return_value = Path("/tmp/.env.skillprogression_staging")
    mock_settings.db_name = STAGING_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"
    mock_settings.db_username = STAGING_DATABASE_ROLE

    assert_capture_apply_safe(_mock_db())


@patch("app.services.skill_progression_capture_guard.active_env_file_path")
@patch("app.services.skill_progression_capture_guard.settings")
def test_apply_guard_rejects_postgres_database(mock_settings, mock_env) -> None:
    from pathlib import Path

    mock_env.return_value = Path("/tmp/.env.skillprogression_staging")
    mock_settings.db_name = STAGING_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"

    with pytest.raises(CaptureApplySafetyError, match="forbidden"):
        assert_capture_apply_safe(_mock_db(current_db="postgres"))


@patch("app.services.skill_progression_capture_guard.active_env_file_path")
@patch("app.services.skill_progression_capture_guard.settings")
def test_apply_guard_rejects_wrong_role(mock_settings, mock_env) -> None:
    from pathlib import Path

    mock_env.return_value = Path("/tmp/.env.skillprogression_staging")
    mock_settings.db_name = STAGING_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v1"

    with pytest.raises(CaptureApplySafetyError, match="current_user"):
        assert_capture_apply_safe(_mock_db(current_user="postgres"))


@patch("app.services.skill_progression_capture_guard.active_env_file_path")
def test_apply_guard_rejects_missing_env_file(mock_env) -> None:
    mock_env.return_value = None
    with pytest.raises(CaptureApplySafetyError, match="ACCESS_ENV_FILE"):
        assert_capture_apply_safe(_mock_db())


@patch("app.services.skill_progression_capture_guard.active_env_file_path")
@patch("app.services.skill_progression_capture_guard.settings")
def test_apply_guard_rejects_v2_policy(mock_settings, mock_env) -> None:
    from pathlib import Path

    mock_env.return_value = Path("/tmp/.env.skillprogression_staging")
    mock_settings.db_name = STAGING_DATABASE_NAME
    mock_settings.db_host = "localhost"
    mock_settings.db_port = 5432
    mock_settings.skill_progression_active_policy = "v2"

    with pytest.raises(CaptureApplySafetyError, match="v1"):
        assert_capture_apply_safe(_mock_db())
