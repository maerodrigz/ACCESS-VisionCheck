"""Baseline table counts for integration safety gate (read-only)."""
from __future__ import annotations

import os
import sys

from sqlalchemy import create_engine, text

from app.config import settings


def _count(conn, sql: str) -> int:
    return int(conn.execute(text(sql)).scalar() or 0)


def main() -> None:
    db_name = sys.argv[1] if len(sys.argv) > 1 else None
    if db_name:
        base = settings.database_url.rsplit("/", 1)[0]
        url = f"{base}/{db_name}"
    else:
        url = settings.database_url

    if os.environ.get("ACCESS_PYTEST_DB", "").strip():
        print("ERROR: unset ACCESS_PYTEST_DB before baseline on original DB")
        raise SystemExit(2)

    engine = create_engine(url, pool_pre_ping=True)
    with engine.connect() as conn:
        current = conn.execute(text("SELECT current_database()")).scalar()
        print(f"current_database={current}")

        tables = conn.execute(
            text(
                """
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
                ORDER BY table_name
                """
            )
        ).fetchall()
        names = {r[0] for r in tables}

        def line(label: str, table: str, extra: str = "") -> None:
            if table not in names:
                print(f"{label}=NA (no table {table})")
                return
            q = f"SELECT COUNT(*) FROM {table}" + (f" WHERE {extra}" if extra else "")
            print(f"{label}={_count(conn, q)}")

        line("users", "users")
        line("media_files", "media_files")
        line("media_files_member_evaluation", "media_files", "media_category = 'member_evaluation'")
        line("media_evaluations", "media_evaluations")
        line("ai_detection_results", "ai_detection_results")
        line("member_rankings", "member_rankings")
        line("submission_chains", "submission_chains")
        line("submission_chain_events", "submission_chain_events")

        if "media_files" in names:
            cols = {
                r[0]
                for r in conn.execute(
                    text(
                        """
                        SELECT column_name FROM information_schema.columns
                        WHERE table_schema = 'public' AND table_name = 'media_files'
                        """
                    )
                ).fetchall()
            }
            for col in (
                "submission_chain_id",
                "replaces_media_id",
                "replacement_lifecycle",
            ):
                print(f"schema_media_files_{col}={col in cols}")

    engine.dispose()


if __name__ == "__main__":
    main()
