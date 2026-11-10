"""AUTH_LOCKOUT_ENABLED — local UI toggle with production fail-safe."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from pydantic import ValidationError

from app.config import Settings
from app.services import security_policy


def test_settings_default_lockout_enabled():
    s = Settings(
        _env_file=None,
        APP_ENV="development",
        AUTH_LOCKOUT_ENABLED=True,
    )
    assert s.auth_lockout_enabled is True
    assert s.is_production is False


def test_settings_allows_disable_in_development():
    s = Settings(
        _env_file=None,
        APP_ENV="development",
        AUTH_LOCKOUT_ENABLED=False,
    )
    assert s.auth_lockout_enabled is False
    assert s.is_production is False


def test_settings_allows_disable_in_testing():
    s = Settings(
        _env_file=None,
        APP_ENV="testing",
        AUTH_LOCKOUT_ENABLED=False,
    )
    assert s.auth_lockout_enabled is False


def test_settings_refuses_disable_in_production():
    with pytest.raises(ValidationError) as exc:
        Settings(
            _env_file=None,
            APP_ENV="production",
            AUTH_LOCKOUT_ENABLED=False,
        )
    assert "AUTH_LOCKOUT_ENABLED=false" in str(exc.value)


def test_settings_refuses_disable_in_prod_alias():
    with pytest.raises(ValidationError):
        Settings(
            _env_file=None,
            APP_ENV="prod",
            AUTH_LOCKOUT_ENABLED=False,
        )


def test_settings_production_keeps_lockout_on():
    s = Settings(
        _env_file=None,
        APP_ENV="production",
        AUTH_LOCKOUT_ENABLED=True,
    )
    assert s.auth_lockout_enabled is True
    assert s.is_production is True


def test_is_auth_lockout_enforced_respects_flag(monkeypatch):
    from app import config as config_mod

    monkeypatch.setattr(config_mod.settings, "app_env", "development")
    monkeypatch.setattr(config_mod.settings, "auth_lockout_enabled", False)
    assert config_mod.settings.is_production is False
    assert security_policy.is_auth_lockout_enforced() is False

    monkeypatch.setattr(config_mod.settings, "auth_lockout_enabled", True)
    assert security_policy.is_auth_lockout_enforced() is True


def test_is_auth_lockout_enforced_always_on_in_production(monkeypatch):
    from app import config as config_mod

    monkeypatch.setattr(config_mod.settings, "app_env", "production")
    monkeypatch.setattr(config_mod.settings, "auth_lockout_enabled", False)
    assert config_mod.settings.is_production is True
    assert security_policy.is_auth_lockout_enforced() is True


def test_is_account_locked_ignored_when_disabled(monkeypatch):
    monkeypatch.setattr(security_policy, "is_auth_lockout_enforced", lambda: False)
    user = SimpleNamespace(
        locked_until=datetime.now(timezone.utc) + timedelta(minutes=30),
        failed_login_count=0,
    )
    assert security_policy.is_account_locked(user) is False
    # Existing lockout timestamp must remain untouched.
    assert user.locked_until is not None


def test_is_account_locked_enforced_when_enabled(monkeypatch):
    monkeypatch.setattr(security_policy, "is_auth_lockout_enforced", lambda: True)
    user = SimpleNamespace(
        locked_until=datetime.now(timezone.utc) + timedelta(minutes=30),
    )
    assert security_policy.is_account_locked(user) is True

    unlocked = SimpleNamespace(locked_until=None)
    assert security_policy.is_account_locked(unlocked) is False


def test_record_failed_login_does_not_lock_when_disabled(monkeypatch):
    monkeypatch.setattr(security_policy, "is_auth_lockout_enforced", lambda: False)
    monkeypatch.setattr(
        security_policy,
        "security_config",
        lambda _db: {"max_login_attempts": 5, "account_lockout_minutes": 30},
    )
    db = MagicMock()
    user = SimpleNamespace(id=42, failed_login_count=4, locked_until=None)

    security_policy.record_failed_login(db, user)

    assert user.failed_login_count == 5
    assert user.locked_until is None
    db.commit.assert_called_once()


def test_record_failed_login_locks_when_enabled(monkeypatch):
    monkeypatch.setattr(security_policy, "is_auth_lockout_enforced", lambda: True)
    monkeypatch.setattr(
        security_policy,
        "security_config",
        lambda _db: {"max_login_attempts": 5, "account_lockout_minutes": 30},
    )
    db = MagicMock()
    user = SimpleNamespace(id=7, failed_login_count=4, locked_until=None)

    security_policy.record_failed_login(db, user)

    assert user.failed_login_count == 0
    assert user.locked_until is not None
    assert user.locked_until > datetime.now(timezone.utc)
    db.commit.assert_called_once()


def test_record_failed_login_preserves_existing_lock_when_disabled(monkeypatch):
    monkeypatch.setattr(security_policy, "is_auth_lockout_enforced", lambda: False)
    monkeypatch.setattr(
        security_policy,
        "security_config",
        lambda _db: {"max_login_attempts": 5, "account_lockout_minutes": 30},
    )
    existing = datetime.now(timezone.utc) + timedelta(minutes=25)
    db = MagicMock()
    user = SimpleNamespace(id=9, failed_login_count=2, locked_until=existing)

    security_policy.record_failed_login(db, user)

    assert user.failed_login_count == 3
    assert user.locked_until == existing
