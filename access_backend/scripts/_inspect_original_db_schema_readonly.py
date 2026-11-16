"""Read-only schema inspection for integration readiness (no writes)."""
from __future__ import annotations

from sqlalchemy import create_engine, inspect, text

from app.config import settings


def main() -> None:
    engine = create_engine(settings.database_url, pool_pre_ping=True)
    with engine.connect() as conn:
        db = conn.execute(text("SELECT current_database()")).scalar()
        print(f"current_database={db}")
        insp = inspect(conn)
        tables = set(insp.get_table_names())
        for name in (
            "submission_chains",
            "submission_chain_events",
            "media_files",
            "ai_detection_results",
        ):
            print(f"table_{name}={name in tables}")
        if "media_files" in tables:
            cols = {c["name"] for c in insp.get_columns("media_files")}
            for col in (
                "submission_chain_id",
                "replaces_media_id",
                "replacement_lifecycle",
            ):
                print(f"media_files_column_{col}={col in cols}")
        if "submission_chains" in tables:
            count = conn.execute(text("SELECT COUNT(*) FROM submission_chains")).scalar()
            print(f"submission_chains_row_count={count}")
        if "media_files" in tables:
            me = conn.execute(
                text(
                    "SELECT COUNT(*) FROM media_files "
                    "WHERE media_category = 'member_evaluation'"
                )
            ).scalar()
            print(f"member_evaluation_media_count={me}")
    engine.dispose()


if __name__ == "__main__":
    main()
