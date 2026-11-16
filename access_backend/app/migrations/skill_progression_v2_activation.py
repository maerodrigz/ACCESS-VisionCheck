"""
Migration: skill_progression_v2_activation_20261111

Additive schema for v2 activation seal + protected cohort membership.
Does NOT assign existing members to the cohort or activate v2.
Reversible via downgrade_skill_progression_v2_activation().
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.migrations._migration_guard import (
    assert_allowed_migration_database,
    configure_migration_session,
    dispose_engine_pool,
)

MIGRATION_ID = "skill_progression_v2_activation_20261111"


def upgrade_skill_progression_v2_activation(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)

        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS skill_progression_v2_activation (
                    id BIGSERIAL PRIMARY KEY,
                    status VARCHAR(20) NOT NULL DEFAULT 'draft',
                    cohort_member_count INTEGER NOT NULL DEFAULT 0,
                    notes TEXT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    created_by_user_id BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
                    sealed_at TIMESTAMPTZ NULL,
                    sealed_by_user_id BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
                    revoked_at TIMESTAMPTZ NULL,
                    revoked_by_user_id BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
                    revoke_reason TEXT NULL
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_skill_progression_v2_activation_status "
                "ON skill_progression_v2_activation (status)"
            )
        )
        conn.execute(
            text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS uq_skill_progression_v2_one_sealed
                ON skill_progression_v2_activation (status)
                WHERE status = 'sealed'
                """
            )
        )

        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS skill_progression_v2_cohort_members (
                    id BIGSERIAL PRIMARY KEY,
                    activation_id BIGINT NOT NULL
                        REFERENCES skill_progression_v2_activation(id) ON DELETE CASCADE,
                    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    ranking_id BIGINT NOT NULL
                        REFERENCES member_rankings(id) ON DELETE CASCADE,
                    floor_at_capture VARCHAR(40) NOT NULL,
                    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    captured_by_user_id BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
                    CONSTRAINT uq_skill_v2_cohort_activation_user
                        UNIQUE (activation_id, user_id)
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_skill_v2_cohort_activation_id "
                "ON skill_progression_v2_cohort_members (activation_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_skill_v2_cohort_user_id "
                "ON skill_progression_v2_cohort_members (user_id)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_skill_v2_cohort_ranking_id "
                "ON skill_progression_v2_cohort_members (ranking_id)"
            )
        )

        # Schema-only: never auto-enroll existing approved members.


def downgrade_skill_progression_v2_activation(engine: Engine) -> None:
    dispose_engine_pool(engine)
    with engine.begin() as conn:
        configure_migration_session(conn)
        assert_allowed_migration_database(conn)
        conn.execute(text("DROP TABLE IF EXISTS skill_progression_v2_cohort_members CASCADE"))
        conn.execute(text("DROP TABLE IF EXISTS skill_progression_v2_activation CASCADE"))


def skill_progression_v2_activation_tables_exist(engine: Engine) -> bool:
    insp = inspect(engine)
    names = set(insp.get_table_names())
    return (
        "skill_progression_v2_activation" in names
        and "skill_progression_v2_cohort_members" in names
    )
