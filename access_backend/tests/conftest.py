"""Pytest hooks — route isolated DB tests to access_waverep_test only."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

_ISOLATED_DB = "access_waverep_test"

# Process-local only: never write .env. Prefer an already-strong JWT_SECRET; otherwise
# install a pytest-only value so Settings() can import when the local .env still has
# a documented insecure placeholder.
_PYTEST_JWT_SECRET = "pytest-access-visioncheck-jwt-secret-do-not-use-in-prod-01"


def _load_backend_dotenv_for_pytest() -> None:
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if env_path.is_file():
        load_dotenv(env_path, override=False)


def _ensure_strong_jwt_secret_for_pytest() -> None:
    _load_backend_dotenv_for_pytest()
    current = (os.environ.get("JWT_SECRET") or "").strip()
    # Inline check avoids importing app.core before env is ready.
    insecure = {
        "",
        "change_this_secret",
        "access_visioncheck_dev_secret",
        "secret",
        "jwt_secret",
        "your-secret-key",
        "dev-secret",
    }
    if len(current) < 32 or current.lower() in insecure:
        os.environ["JWT_SECRET"] = _PYTEST_JWT_SECRET


def _ensure_pytest_testclient_host_allowed() -> None:
    """Allow Starlette TestClient Host ``testserver`` under pytest only.

    TrustedHostMiddleware stays enabled. Production ALLOWED_HOSTS is unchanged.
    When no .env is present (isolated checkout-index snapshots), Settings defaults
    omit ``testserver`` and TestClient calls return HTTP 400 Invalid host header.
    """
    _load_backend_dotenv_for_pytest()
    current = (os.environ.get("ALLOWED_HOSTS") or "").strip()
    if current == "*":
        return
    parts = [h.strip() for h in current.split(",") if h.strip()]
    if not parts:
        # No env override: do not rely on production LAN Field defaults for pytest.
        parts = [
            "testserver",
            "localhost",
            "127.0.0.1",
            "localhost:3001",
            "127.0.0.1:3001",
        ]
    elif "testserver" not in {p.lower() for p in parts}:
        parts.append("testserver")
    os.environ["ALLOWED_HOSTS"] = ",".join(parts)


_ensure_strong_jwt_secret_for_pytest()
_ensure_pytest_testclient_host_allowed()


def _waverep_database_url() -> str | None:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() != _ISOLATED_DB:
        return None
    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    raw = (os.environ.get("DATABASE_URL") or "").strip().lower()
    if raw.endswith(f"/{_ISOLATED_DB}") or raw.endswith(f"/{_ISOLATED_DB}?") or f"/{_ISOLATED_DB}?" in raw:
        return (os.environ.get("DATABASE_URL") or "").strip()
    from app.migrations.isolated_test_database_url import isolated_test_database_url

    return isolated_test_database_url()


def _rebind_app_database(url: str) -> None:
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    import app.database as db_mod

    db_mod.engine.dispose()
    db_mod.engine = create_engine(url, pool_pre_ping=True)
    db_mod.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=db_mod.engine)


def pytest_configure(config) -> None:
    url = _waverep_database_url()
    if url:
        os.environ["DATABASE_URL"] = url
        _rebind_app_database(url)
        # TestClient uses host "testserver"; waverep .env may restrict ALLOWED_HOSTS.
        os.environ["ALLOWED_HOSTS"] = "*"
        from app.config import settings

        settings.allowed_hosts = "*"

    # Isolate feature flags that default OFF in Settings Field(...) from a developer
    # .env that enables them for local QA. Opt out with ACCESS_PYTEST_KEEP_FEATURE_FLAGS=1.
    # Does not change production defaults or deployed .env files.
    if os.environ.get("ACCESS_PYTEST_KEEP_FEATURE_FLAGS", "").strip() != "1":
        from app.config import settings as _settings

        _settings.replacement_upload_enabled = False
        _settings.waverep_enabled = False
