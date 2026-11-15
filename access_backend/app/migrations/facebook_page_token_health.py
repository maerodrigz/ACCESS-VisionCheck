"""
Migration: facebook_page_token_health_20261115

Additive singleton table for safe Page-token verification metadata.
Never stores access tokens.

Apply only on approved environments:
  python -m app.migrations.run_facebook_page_token_health apply
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.migrations._migration_guard import (
    assert_allowed_migration_database,
    configure_migration_session,
    dispose_engine_pool,
)

MIGRATION_ID = "facebook_page_token_health_20261115"


def upgrade_facebook_page_token_health(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS facebook_page_token_health (
                    id INTEGER PRIMARY KEY,
                    connection_status VARCHAR(32) NOT NULL DEFAULT 'unknown',
                    page_id VARCHAR(64),
                    page_name VARCHAR(255),
                    last_verified_at TIMESTAMPTZ,
                    last_ok BOOLEAN,
                    last_error TEXT,
                    token_expires_at TIMESTAMPTZ,
                    expiry_visibility VARCHAR(16) NOT NULL DEFAULT 'unknown',
                    album_id VARCHAR(64),
                    album_name VARCHAR(255),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        )
        # Ensure singleton placeholder exists (no secrets).
        conn.execute(
            text(
                """
                INSERT INTO facebook_page_token_health (id, connection_status, expiry_visibility)
                VALUES (1, 'unknown', 'unknown')
                ON CONFLICT (id) DO NOTHING
                """
            )
        )


def inspect_facebook_page_token_health(engine: Engine) -> dict:
    dispose_engine_pool(engine)
    with engine.connect() as conn:
        configure_migration_session(conn)
        insp = inspect(conn)
        exists = insp.has_table("facebook_page_token_health")
        columns: list[str] = []
        if exists:
            columns = [c["name"] for c in insp.get_columns("facebook_page_token_health")]
        return {
            "migration_id": MIGRATION_ID,
            "table_exists": exists,
            "columns": columns,
            "migration_needed": not exists
            or not {"connection_status", "last_verified_at", "expiry_visibility"}.issubset(set(columns)),
        }
