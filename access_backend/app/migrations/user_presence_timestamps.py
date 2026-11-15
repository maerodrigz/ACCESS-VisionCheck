"""
Migration: user_presence_timestamps_20261115

Adds users.last_seen_at and users.last_login_at (UTC, indexed).
Does not rewrite historical activity or fabricate presence.

Apply only on approved environments:
  python -m app.migrations.run_user_presence_timestamps apply
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.migrations._migration_guard import (
    assert_allowed_migration_database,
    configure_migration_session,
    dispose_engine_pool,
)

MIGRATION_ID = "user_presence_timestamps_20261115"


def upgrade_user_presence_timestamps(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(
            text(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_users_last_seen_at ON users (last_seen_at)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_users_last_login_at ON users (last_login_at)"
            )
        )
        # Best-effort backfill of last_login_at from login_history (no fabricated online).
        conn.execute(
            text(
                """
                UPDATE users u
                SET last_login_at = src.max_login
                FROM (
                    SELECT user_id, MAX(login_time) AS max_login
                    FROM login_history
                    GROUP BY user_id
                ) src
                WHERE u.id = src.user_id
                  AND u.last_login_at IS NULL
                """
            )
        )


def inspect_user_presence_timestamps(engine: Engine) -> dict:
    dispose_engine_pool(engine)
    with engine.connect() as conn:
        configure_migration_session(conn)
        insp = inspect(conn)
        cols = {c["name"] for c in insp.get_columns("users")} if insp.has_table("users") else set()
        needed = {"last_seen_at", "last_login_at"}
        return {
            "migration_id": MIGRATION_ID,
            "columns_present": sorted(needed & cols),
            "migration_needed": not needed.issubset(cols),
        }
