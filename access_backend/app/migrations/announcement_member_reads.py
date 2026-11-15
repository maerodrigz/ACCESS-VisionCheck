"""
Migration: announcement_member_reads_20261115

Additive table for per-member announcement first-open + 24h expiry.
Does not delete or alter existing announcements/notifications.

Apply only on approved environments:
  python -m app.migrations.run_announcement_member_reads apply
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.migrations._migration_guard import (
    assert_allowed_migration_database,
    configure_migration_session,
    dispose_engine_pool,
)

MIGRATION_ID = "announcement_member_reads_20261115"


def upgrade_announcement_member_reads(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS announcement_member_reads (
                    id BIGSERIAL PRIMARY KEY,
                    announcement_id INTEGER NOT NULL
                        REFERENCES announcements(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL
                        REFERENCES users(id) ON DELETE CASCADE,
                    first_read_at TIMESTAMPTZ NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    CONSTRAINT uq_announcement_member_reads_announcement_user
                        UNIQUE (announcement_id, user_id)
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_announcement_member_reads_announcement_id "
                "ON announcement_member_reads (announcement_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_announcement_member_reads_user_id "
                "ON announcement_member_reads (user_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_announcement_member_reads_expires_at "
                "ON announcement_member_reads (expires_at)"
            )
        )


def inspect_announcement_member_reads(engine: Engine) -> dict:
    dispose_engine_pool(engine)
    insp = inspect(engine)
    exists = insp.has_table("announcement_member_reads")
    columns: list[str] = []
    if exists:
        columns = [c["name"] for c in insp.get_columns("announcement_member_reads")]
    needed = not exists or not {
        "announcement_id",
        "user_id",
        "first_read_at",
        "expires_at",
    }.issubset(set(columns))
    return {
        "migration_id": MIGRATION_ID,
        "table_exists": exists,
        "columns": columns,
        "migration_needed": needed,
    }
