"""Post-migration read-only verification on postgres."""
from __future__ import annotations

import os
import sys

from sqlalchemy import create_engine, inspect, text

from app.config import settings

ALLOWED = "postgres"


def main() -> int:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip():
        print("ERROR: unset ACCESS_PYTEST_DB")
        return 2
    engine = create_engine(settings.database_url, pool_pre_ping=True)
    with engine.connect() as conn:
        db = conn.execute(text("SELECT current_database()")).scalar()
        print(f"current_database={db}")
        if db != ALLOWED:
            print("ERROR: wrong database")
            return 2

        insp = inspect(conn)
        tables = set(insp.get_table_names())
        for t in ("submission_chains", "submission_chain_events", "media_files"):
            print(f"table_{t}={t in tables}")

        cols = {c["name"] for c in insp.get_columns("media_files")}
        for col in ("submission_chain_id", "replaces_media_id", "replacement_lifecycle"):
            print(f"column_media_files_{col}={col in cols}")

        indexes = {idx["name"] for idx in insp.get_indexes("media_files")}
        for idx in (
            "ix_media_files_submission_chain_id",
            "ix_media_files_replaces_media_id",
            "uq_submission_chain_one_active_replacement",
        ):
            print(f"index_{idx}={idx in indexes or idx in str(insp.get_indexes('media_files'))}")

        # counts
        for label, sql in (
            ("users", "SELECT COUNT(*) FROM users"),
            ("media_files", "SELECT COUNT(*) FROM media_files"),
            (
                "media_files_member_evaluation",
                "SELECT COUNT(*) FROM media_files WHERE media_category = 'member_evaluation'",
            ),
            ("media_evaluations", "SELECT COUNT(*) FROM media_evaluations"),
            ("ai_detection_results", "SELECT COUNT(*) FROM ai_detection_results"),
            ("member_rankings", "SELECT COUNT(*) FROM member_rankings"),
            ("submission_chains", "SELECT COUNT(*) FROM submission_chains"),
            ("submission_chain_events", "SELECT COUNT(*) FROM submission_chain_events"),
        ):
            print(f"count_{label}={conn.execute(text(sql)).scalar()}")

        linked = conn.execute(
            text(
                """
                SELECT COUNT(*) FROM media_files
                WHERE media_category = 'member_evaluation'
                  AND uploaded_by IS NOT NULL
                  AND submission_chain_id IS NOT NULL
                """
            )
        ).scalar()
        eligible = conn.execute(
            text(
                """
                SELECT COUNT(*) FROM media_files
                WHERE media_category = 'member_evaluation'
                  AND uploaded_by IS NOT NULL
                """
            )
        ).scalar()
        print(f"member_eval_linked_to_chain={linked}/{eligible}")

        dup_active = conn.execute(
            text(
                """
                SELECT submission_chain_id, COUNT(*) AS n
                FROM media_files
                WHERE replacement_lifecycle = 'active'
                  AND submission_chain_id IS NOT NULL
                GROUP BY submission_chain_id
                HAVING COUNT(*) > 1
                """
            )
        ).fetchall()
        print(f"duplicate_active_replacement_chains={len(dup_active)}")

        xp_sum = conn.execute(text("SELECT COALESCE(SUM(total_points), 0) FROM member_rankings")).scalar()
        print(f"member_rankings_total_points_sum={xp_sum}")

        eval_score_checksum = conn.execute(
            text("SELECT COALESCE(SUM(overall_score::numeric), 0) FROM media_evaluations")
        ).scalar()
        print(f"media_evaluations_overall_score_sum={eval_score_checksum}")

        roots = conn.execute(
            text(
                """
                SELECT COUNT(*) FROM submission_chains sc
                JOIN media_files m ON m.id = sc.root_media_id
                WHERE m.media_category = 'member_evaluation'
                """
            )
        ).scalar()
        print(f"chains_with_member_eval_root={roots}")

    engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
