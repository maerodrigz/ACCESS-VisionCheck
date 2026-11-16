"""Read-only: inspect schema for a named PostgreSQL database (no writes)."""
from __future__ import annotations

import sys

from sqlalchemy import create_engine, inspect, text

from app.config import settings


def inspect_db(db_name: str) -> None:
    base = settings.database_url.rsplit("/", 1)[0]
    url = f"{base}/{db_name}"
    engine = create_engine(url, pool_pre_ping=True)
    with engine.connect() as conn:
        current = conn.execute(text("SELECT current_database()")).scalar()
        print(f"=== {current} ===")
        insp = inspect(conn)
        tables = set(insp.get_table_names())
        print(f"submission_chains={('submission_chains' in tables)}")
        if "media_files" in tables:
            cols = {c["name"] for c in insp.get_columns("media_files")}
            print(
                "media_chain_cols="
                f"{('submission_chain_id' in cols, 'replaces_media_id' in cols, 'replacement_lifecycle' in cols)}"
            )
            me = conn.execute(
                text(
                    "SELECT COUNT(*) FROM media_files "
                    "WHERE media_category = 'member_evaluation'"
                )
            ).scalar()
            print(f"member_evaluation_media={me}")
        else:
            print("media_files=missing")
    engine.dispose()


def main() -> None:
    names = sys.argv[1:] or ["postgres", "access", "access_uat"]
    for name in names:
        try:
            inspect_db(name)
        except Exception as exc:
            print(f"=== {name} === ERROR {exc.__class__.__name__}: {exc}")


if __name__ == "__main__":
    main()
