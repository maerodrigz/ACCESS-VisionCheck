"""Production-safe database initialization rules (no live DB writes)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.config import Settings
from app.db_init_safety import (
    DEV_ADMIN_EMAIL,
    DEV_ADMIN_PASSWORD,
    ProductionDbInitError,
    assert_recreate_db_allowed,
    assert_reset_data_allowed,
    assert_sample_seed_allowed,
    recreate_db_requested,
    resolve_bootstrap_admin,
    seed_demo_data_enabled,
)

_STRONG_JWT = "unit-test-jwt-secret-not-for-production-use-01"
_STRONG_ADMIN_PASSWORD = "ProdAdmin!Bootstrap99"


def _prod_settings(**extra):
    base = dict(
        _env_file=None,
        APP_ENV="production",
        AUTH_LOCKOUT_ENABLED=True,
        JWT_SECRET=_STRONG_JWT,
        SMS_PROVIDER="textbee",
        EMAIL_ENABLED=True,
        DB_PASSWORD="unit-test-db-password",
        CORS_ORIGINS="https://admin.example.com",
        ALLOWED_HOSTS="api.example.com,127.0.0.1",
    )
    base.update(extra)
    return Settings(**base)


def test_recreate_db_allowed_in_development():
    assert_recreate_db_allowed(
        is_production=False,
        environ={"RECREATE_DB": "true"},
    )


def test_recreate_db_refused_in_production_before_sql():
    with pytest.raises(ProductionDbInitError, match="RECREATE_DB"):
        assert_recreate_db_allowed(
            is_production=True,
            environ={"RECREATE_DB": "true"},
        )


def test_recreate_db_noop_when_unset_in_production():
    assert_recreate_db_allowed(is_production=True, environ={})
    assert recreate_db_requested(environ={}) is False


def test_settings_refuse_recreate_db_in_production(monkeypatch):
    monkeypatch.setenv("RECREATE_DB", "true")
    with pytest.raises(ValidationError, match="RECREATE_DB"):
        _prod_settings()


def test_settings_allow_production_without_recreate(monkeypatch):
    monkeypatch.delenv("RECREATE_DB", raising=False)
    s = _prod_settings()
    assert s.is_production is True


def test_seed_demo_ignored_in_production_even_when_true():
    assert (
        seed_demo_data_enabled(
            is_production=True,
            environ={"SEED_DEMO_DATA": "true"},
        )
        is False
    )


def test_seed_demo_honored_in_development():
    assert (
        seed_demo_data_enabled(
            is_production=False,
            environ={"SEED_DEMO_DATA": "true"},
        )
        is True
    )
    assert (
        seed_demo_data_enabled(
            is_production=False,
            environ={},
        )
        is False
    )


def test_sample_seed_and_reset_refused_in_production():
    with pytest.raises(ProductionDbInitError, match="Sample"):
        assert_sample_seed_allowed(is_production=True)
    with pytest.raises(ProductionDbInitError, match="reset_data"):
        assert_reset_data_allowed(is_production=True)
    assert_sample_seed_allowed(is_production=False)
    assert_reset_data_allowed(is_production=False)


def test_production_bootstrap_requires_explicit_credentials():
    assert resolve_bootstrap_admin(is_production=True, environ={}) is None


def test_production_bootstrap_never_uses_hardcoded_dev_admin():
    with pytest.raises(ProductionDbInitError, match="development credentials"):
        resolve_bootstrap_admin(
            is_production=True,
            environ={
                "BOOTSTRAP_ADMIN_EMAIL": DEV_ADMIN_EMAIL,
                "BOOTSTRAP_ADMIN_PASSWORD": DEV_ADMIN_PASSWORD,
            },
        )


def test_production_bootstrap_rejects_weak_password():
    with pytest.raises(ProductionDbInitError, match="weak|12 characters"):
        resolve_bootstrap_admin(
            is_production=True,
            environ={
                "BOOTSTRAP_ADMIN_EMAIL": "ops@example.com",
                "BOOTSTRAP_ADMIN_PASSWORD": "short",
            },
        )


def test_production_bootstrap_from_env_does_not_expose_password_in_repr():
    creds = resolve_bootstrap_admin(
        is_production=True,
        environ={
            "BOOTSTRAP_ADMIN_EMAIL": "ops@example.com",
            "BOOTSTRAP_ADMIN_PASSWORD": _STRONG_ADMIN_PASSWORD,
            "BOOTSTRAP_ADMIN_NAME": "Ops Admin",
        },
    )
    assert creds is not None
    assert creds.email == "ops@example.com"
    assert creds.fullname == "Ops Admin"
    assert creds.password == _STRONG_ADMIN_PASSWORD
    assert creds.source == "environment"
    # Callers must never print password; dataclass repr still contains it — ensure
    # create_tables / manage paths use the explicit "(password not shown)" messaging instead.


def test_production_bootstrap_from_cli():
    creds = resolve_bootstrap_admin(
        is_production=True,
        environ={},
        cli_email="ops@example.com",
        cli_password=_STRONG_ADMIN_PASSWORD,
        cli_fullname="CLI Admin",
    )
    assert creds is not None
    assert creds.source == "cli"
    assert creds.email == "ops@example.com"


def test_development_keeps_hardcoded_admin_default():
    creds = resolve_bootstrap_admin(is_production=False, environ={})
    assert creds is not None
    assert creds.email == DEV_ADMIN_EMAIL
    assert creds.password == DEV_ADMIN_PASSWORD
    assert creds.source == "development_default"


def test_development_bootstrap_env_override():
    creds = resolve_bootstrap_admin(
        is_production=False,
        environ={
            "BOOTSTRAP_ADMIN_EMAIL": "dev-admin@example.com",
            "BOOTSTRAP_ADMIN_PASSWORD": "local-override-pass",
        },
    )
    assert creds is not None
    assert creds.email == "dev-admin@example.com"
    assert creds.source == "environment"


def test_seed_default_users_production_skips_without_bootstrap(capsys, monkeypatch):
    """create_tables.seed_default_users must not insert admin@access.edu in production."""
    from types import SimpleNamespace

    import create_tables as ct

    monkeypatch.setattr(ct, "settings", SimpleNamespace(is_production=True, app_env="production"))
    monkeypatch.delenv("BOOTSTRAP_ADMIN_EMAIL", raising=False)
    monkeypatch.delenv("BOOTSTRAP_ADMIN_PASSWORD", raising=False)

    calls: list[dict] = []

    def fake_seed_user(db, **kwargs):
        calls.append(kwargs)
        return True

    monkeypatch.setattr(ct, "_seed_user", fake_seed_user)
    ct.seed_default_users(db=object(), role_ids={"Admin": 1}, skill_ids={"Master": 6})
    assert calls == []
    out = capsys.readouterr().out
    assert "admin@access.edu" not in out
    assert "admin123" not in out
    assert "bootstrap_admin" in out


def test_seed_default_users_production_uses_bootstrap_env(capsys, monkeypatch):
    from types import SimpleNamespace

    import create_tables as ct

    monkeypatch.setattr(ct, "settings", SimpleNamespace(is_production=True, app_env="production"))
    monkeypatch.setenv("BOOTSTRAP_ADMIN_EMAIL", "ops@example.com")
    monkeypatch.setenv("BOOTSTRAP_ADMIN_PASSWORD", _STRONG_ADMIN_PASSWORD)

    calls: list[dict] = []

    def fake_seed_user(db, **kwargs):
        calls.append(kwargs)
        return True

    monkeypatch.setattr(ct, "_seed_user", fake_seed_user)
    ct.seed_default_users(db=object(), role_ids={"Admin": 1}, skill_ids={"Master": 6})
    assert len(calls) == 1
    assert calls[0]["email"] == "ops@example.com"
    assert calls[0]["password"] == _STRONG_ADMIN_PASSWORD
    out = capsys.readouterr().out
    assert "ops@example.com" in out
    assert _STRONG_ADMIN_PASSWORD not in out
    assert "admin123" not in out


def test_seed_default_users_development_still_seeds_dev_admin(capsys, monkeypatch):
    from types import SimpleNamespace

    import create_tables as ct

    monkeypatch.setattr(ct, "settings", SimpleNamespace(is_production=False, app_env="development"))
    monkeypatch.delenv("BOOTSTRAP_ADMIN_EMAIL", raising=False)
    monkeypatch.delenv("BOOTSTRAP_ADMIN_PASSWORD", raising=False)

    calls: list[dict] = []

    def fake_seed_user(db, **kwargs):
        calls.append(kwargs)
        return True

    monkeypatch.setattr(ct, "_seed_user", fake_seed_user)
    ct.seed_default_users(db=object(), role_ids={"Admin": 1}, skill_ids={"Master": 6})
    assert calls[0]["email"] == DEV_ADMIN_EMAIL
    assert calls[0]["password"] == DEV_ADMIN_PASSWORD
    out = capsys.readouterr().out
    assert DEV_ADMIN_EMAIL in out


def test_main_refuses_recreate_before_schema_drop(monkeypatch):
    from types import SimpleNamespace

    import create_tables as ct

    monkeypatch.setattr(
        ct,
        "settings",
        SimpleNamespace(
            is_production=True,
            app_env="production",
            database_url="postgresql+psycopg://u:secret@localhost/access",
            db_password="secret",
        ),
    )
    monkeypatch.setenv("RECREATE_DB", "true")

    called = {"recreate": False}

    def boom():
        called["recreate"] = True
        raise AssertionError("recreate_public_schema must not run in production")

    monkeypatch.setattr(ct, "recreate_public_schema", boom)

    with pytest.raises(SystemExit) as exc:
        ct.main()
    assert exc.value.code == 1
    assert called["recreate"] is False
