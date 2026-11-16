"""
Migration: media_evaluations_nullable_scores

Make quality score columns on media_evaluations nullable so failed
evaluations can be stored without inventing 0.5 placeholders.

Does not UPDATE/DELETE rows. Does not touch media_files, users, rankings,
XP, AI detection, or submission chains. Does not change scoring formulas.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import text
from sqlalchemy.engine import Engine

MIGRATION_ID = "media_evaluations_nullable_scores"
SCORE_COLUMNS = (
    "sharpness_score",
    "brightness_score",
    "contrast_score",
    "blur_score",
    "noise_score",
    "overall_score",
)

_NULLABILITY_SQL = text(
    """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'media_evaluations'
      AND column_name = ANY(:cols)
    ORDER BY column_name
    """
)


def inspect_media_evaluations_schema(engine: Engine) -> dict[str, Any]:
    """Read-only: current database, column nullability, and row counts."""
    with engine.connect() as conn:
        db_name = conn.execute(text("SELECT current_database()")).scalar()
        table_exists = conn.execute(
            text(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_name = 'media_evaluations'
                )
                """
            )
        ).scalar()
        columns: list[dict[str, Any]] = []
        counts: dict[str, Any] | None = None
        if table_exists:
            columns = [
                dict(row)
                for row in conn.execute(_NULLABILITY_SQL, {"cols": list(SCORE_COLUMNS)}).mappings()
            ]
            counts = dict(
                conn.execute(
                    text(
                        """
                        SELECT
                            COUNT(*) AS total_rows,
                            COUNT(sharpness_score) AS sharpness_not_null,
                            COUNT(brightness_score) AS brightness_not_null,
                            COUNT(contrast_score) AS contrast_not_null,
                            COUNT(blur_score) AS blur_not_null,
                            COUNT(noise_score) AS noise_not_null,
                            COUNT(overall_score) AS overall_not_null
                        FROM media_evaluations
                        """
                    )
                ).mappings().one()
            )
    needed = False
    if table_exists:
        by_name = {c["column_name"]: c["is_nullable"] for c in columns}
        needed = any(by_name.get(name) != "YES" for name in SCORE_COLUMNS) or len(columns) != len(
            SCORE_COLUMNS
        )
    return {
        "migration_id": MIGRATION_ID,
        "database": db_name,
        "table_exists": bool(table_exists),
        "columns": columns,
        "counts": counts,
        "migration_needed": needed,
    }


def upgrade_media_evaluations_nullable_scores(engine: Engine) -> None:
    """ALTER media_evaluations score columns to nullable. No row updates."""
    with engine.begin() as conn:
        exists = conn.execute(
            text(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_name = 'media_evaluations'
                )
                """
            )
        ).scalar()
        if not exists:
            raise RuntimeError("Table public.media_evaluations does not exist.")
        for column in SCORE_COLUMNS:
            conn.execute(text(f"ALTER TABLE media_evaluations ALTER COLUMN {column} DROP NOT NULL"))
