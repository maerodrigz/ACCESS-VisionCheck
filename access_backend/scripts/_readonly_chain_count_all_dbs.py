"""Compare submission_chains count across local Postgres DBs (read-only)."""
from __future__ import annotations

import os

from sqlalchemy import create_engine, text
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

HOST = os.environ.get("DB_HOST", "localhost")
PORT = os.environ.get("DB_PORT", "5432")
USER = os.environ.get("DB_USERNAME", "postgres")
PASSWORD = os.environ.get("DB_PASSWORD", "")


def count_in(db_name: str) -> None:
    url = f"postgresql+psycopg://{USER}:{PASSWORD}@{HOST}:{PORT}/{db_name}"
    try:
        engine = create_engine(url)
        with engine.connect() as c:
            has = c.execute(
                text(
                    "SELECT EXISTS (SELECT 1 FROM information_schema.tables "
                    "WHERE table_schema='public' AND table_name='submission_chains')"
                )
            ).scalar()
            if not has:
                print(f"{db_name}: no submission_chains table")
                return
            n = c.execute(text("SELECT COUNT(*) FROM submission_chains")).scalar()
            print(f"{db_name}: submission_chains={n}")
        engine.dispose()
    except Exception as exc:
        print(f"{db_name}: error={exc}")


def main() -> None:
    for name in ("postgres", "access_waverep_test", "access_uat", "access"):
        count_in(name)


if __name__ == "__main__":
    main()
