"""Pytest hooks — route isolated DB tests to access_waverep_test only."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

_ISOLATED_DB = "access_waverep_test"


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
        # Default-flag tests expect production default; waverep env enables replacement in QA only.
        if os.environ.get("REPLACEMENT_UPLOAD_ENABLED", "").strip().lower() == "true":
            settings.replacement_upload_enabled = False
