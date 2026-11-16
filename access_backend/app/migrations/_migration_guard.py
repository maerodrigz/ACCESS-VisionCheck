"""Safety guards for isolated test migrations."""

from __future__ import annotations

import os

from sqlalchemy import text
from sqlalchemy.engine import Connection

ISOLATED_TEST_DB = "access_waverep_test"


def dispose_engine_pool(engine) -> None:
    """Return pooled connections so DDL is not blocked by idle ORM sessions."""
    engine.dispose()


def configure_migration_session(conn: Connection) -> None:
    conn.execute(text("SET lock_timeout = '60s'"))
    conn.execute(text("SET statement_timeout = '300s'"))
    conn.execute(text("SET idle_in_transaction_session_timeout = '120s'"))


def assert_allowed_migration_database(conn: Connection) -> None:
    """When ACCESS_PYTEST_DB is set, refuse to migrate any other database."""
    marker = os.environ.get("ACCESS_PYTEST_DB", "").strip()
    if marker != ISOLATED_TEST_DB:
        return
    current = conn.execute(text("SELECT current_database()")).scalar()
    if current != ISOLATED_TEST_DB:
        raise RuntimeError(
            f"Migration blocked: current_database()={current!r}, "
            f"expected {ISOLATED_TEST_DB!r} (ACCESS_PYTEST_DB is set)."
        )
