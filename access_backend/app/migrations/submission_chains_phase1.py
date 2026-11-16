"""
Migration: submission_chains_phase1_20261027

Linked replacement upload — Phase 1 schema + backfill only.
Reversible via downgrade_submission_chains_phase1().
"""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.engine import Engine

from app.migrations._migration_guard import (
    assert_allowed_migration_database,
    configure_migration_session,
    dispose_engine_pool,
)

MIGRATION_ID = "submission_chains_phase1_20261027"


def upgrade_submission_chains_phase1(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS submission_chains (
                    id BIGSERIAL PRIMARY KEY,
                    root_media_id BIGINT NOT NULL REFERENCES media_files(id) ON DELETE RESTRICT,
                    member_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    active_replacement_media_id BIGINT NULL REFERENCES media_files(id) ON DELETE SET NULL,
                    awaiting_replacement_media_id BIGINT NULL REFERENCES media_files(id) ON DELETE SET NULL,
                    xp_awarded_total INTEGER NOT NULL DEFAULT 0,
                    xp_award_locked BOOLEAN NOT NULL DEFAULT FALSE,
                    xp_awarded_media_id BIGINT NULL REFERENCES media_files(id) ON DELETE SET NULL,
                    xp_awarded_at TIMESTAMPTZ NULL,
                    chain_resolved_at TIMESTAMPTZ NULL,
                    xp_reconciliation_status VARCHAR(40) NOT NULL DEFAULT 'pending',
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NULL DEFAULT NOW()
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_submission_chains_root_media_id "
                "ON submission_chains (root_media_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_submission_chains_member_id "
                "ON submission_chains (member_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_submission_chains_xp_reconciliation_status "
                "ON submission_chains (xp_reconciliation_status)"
            )
        )

        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS submission_chain_events (
                    id BIGSERIAL PRIMARY KEY,
                    chain_id BIGINT NOT NULL REFERENCES submission_chains(id) ON DELETE CASCADE,
                    media_id BIGINT NULL REFERENCES media_files(id) ON DELETE SET NULL,
                    event_type VARCHAR(64) NOT NULL,
                    payload TEXT NULL,
                    actor_user_id BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_submission_chain_events_chain_id "
                "ON submission_chain_events (chain_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_submission_chain_events_created_at "
                "ON submission_chain_events (created_at DESC)"
            )
        )

        conn.execute(
            text(
                "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS submission_chain_id BIGINT NULL"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS replaces_media_id BIGINT NULL"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS replacement_lifecycle VARCHAR(20) NULL"
            )
        )

        conn.execute(
            text(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint WHERE conname = 'fk_media_files_submission_chain_id'
                    ) THEN
                        ALTER TABLE media_files
                        ADD CONSTRAINT fk_media_files_submission_chain_id
                        FOREIGN KEY (submission_chain_id) REFERENCES submission_chains(id) ON DELETE SET NULL;
                    END IF;
                END $$;
                """
            )
        )
        conn.execute(
            text(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint WHERE conname = 'fk_media_files_replaces_media_id'
                    ) THEN
                        ALTER TABLE media_files
                        ADD CONSTRAINT fk_media_files_replaces_media_id
                        FOREIGN KEY (replaces_media_id) REFERENCES media_files(id) ON DELETE SET NULL;
                    END IF;
                END $$;
                """
            )
        )

        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_media_files_submission_chain_id "
                "ON media_files (submission_chain_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_media_files_replaces_media_id "
                "ON media_files (replaces_media_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_media_files_replacement_lifecycle "
                "ON media_files (replacement_lifecycle) "
                "WHERE replacement_lifecycle IS NOT NULL"
            )
        )

        conn.execute(
            text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS uq_submission_chain_one_active_replacement
                ON media_files (submission_chain_id)
                WHERE media_category = 'member_evaluation'
                  AND replacement_lifecycle = 'active'
                  AND submission_chain_id IS NOT NULL
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS uq_media_one_active_replacement_child
                ON media_files (replaces_media_id)
                WHERE replacement_lifecycle = 'active'
                  AND replaces_media_id IS NOT NULL
                """
            )
        )

        _backfill_member_evaluation_chains(conn)


def _backfill_member_evaluation_chains(conn) -> None:
    """One root chain per practice eval media; do not infer XP."""
    conn.execute(
        text(
            """
            INSERT INTO submission_chains (
                root_media_id,
                member_id,
                xp_awarded_total,
                xp_award_locked,
                xp_reconciliation_status,
                created_at,
                updated_at
            )
            SELECT
                m.id,
                m.uploaded_by,
                0,
                FALSE,
                'pending',
                NOW(),
                NOW()
            FROM media_files m
            WHERE m.media_category = 'member_evaluation'
              AND m.uploaded_by IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM submission_chains c WHERE c.root_media_id = m.id
              )
            """
        )
    )
    conn.execute(
        text(
            """
            UPDATE media_files m
            SET submission_chain_id = c.id
            FROM submission_chains c
            WHERE c.root_media_id = m.id
              AND m.media_category = 'member_evaluation'
              AND m.submission_chain_id IS NULL
            """
        )
    )


def downgrade_submission_chains_phase1(engine: Engine) -> None:
    """Remove Phase 1 schema (does not delete media or evaluation rows)."""
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(text("DROP INDEX IF EXISTS uq_media_one_active_replacement_child"))
        conn.execute(text("DROP INDEX IF EXISTS uq_submission_chain_one_active_replacement"))
        conn.execute(text("DROP INDEX IF EXISTS ix_media_files_replacement_lifecycle"))
        conn.execute(text("DROP INDEX IF EXISTS ix_media_files_replaces_media_id"))
        conn.execute(text("DROP INDEX IF EXISTS ix_media_files_submission_chain_id"))

        conn.execute(
            text(
                "ALTER TABLE media_files DROP CONSTRAINT IF EXISTS fk_media_files_replaces_media_id"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE media_files DROP CONSTRAINT IF EXISTS fk_media_files_submission_chain_id"
            )
        )
        conn.execute(text("ALTER TABLE media_files DROP COLUMN IF EXISTS replacement_lifecycle"))
        conn.execute(text("ALTER TABLE media_files DROP COLUMN IF EXISTS replaces_media_id"))
        conn.execute(text("ALTER TABLE media_files DROP COLUMN IF EXISTS submission_chain_id"))

        conn.execute(text("DROP INDEX IF EXISTS ix_submission_chain_events_created_at"))
        conn.execute(text("DROP INDEX IF EXISTS ix_submission_chain_events_chain_id"))
        conn.execute(text("DROP TABLE IF EXISTS submission_chain_events"))

        conn.execute(text("DROP INDEX IF EXISTS ix_submission_chains_xp_reconciliation_status"))
        conn.execute(text("DROP INDEX IF EXISTS ix_submission_chains_member_id"))
        conn.execute(text("DROP INDEX IF EXISTS uq_submission_chains_root_media_id"))
        conn.execute(text("DROP TABLE IF EXISTS submission_chains"))
