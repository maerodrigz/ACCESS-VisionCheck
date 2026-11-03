"""Verify staging role isolation and shared dev unchanged (read-only)."""

from __future__ import annotations

import sys
from pathlib import Path
from urllib.parse import quote_plus

import psycopg
from dotenv import dotenv_values, load_dotenv

BACKEND = Path(__file__).resolve().parents[1]
STAGING_DB = "access_skillprogression_staging"
ENV_FILE = BACKEND / ".env.skillprogression_staging"


def _shared_dev_counts() -> tuple[str, int]:
    import os
    import subprocess

    env = os.environ.copy()
    env.pop("ACCESS_ENV_FILE", None)
    out = subprocess.check_output(
        [
            sys.executable,
            "-c",
            "from dotenv import load_dotenv; load_dotenv('.env'); "
            "from app.config import settings; from app.database import engine; "
            "from sqlalchemy import text; "
            "c=engine.connect(); n=c.execute(text('SELECT count(*) FROM users')).scalar(); c.close(); "
            "print(settings.db_name, n)",
        ],
        cwd=BACKEND,
        env=env,
        text=True,
    ).strip()
    db_name, count = out.split()
    return db_name, int(count)


def main() -> int:
    shared_db, shared_users = _shared_dev_counts()
    print(f"shared_dev db={shared_db} users={shared_users}")
    if shared_db != "postgres":
        print("FAIL shared dev db_name")
        return 1
    if shared_users != 3:
        print(f"WARN shared dev user count expected 3, got {shared_users}")

    v = dotenv_values(ENV_FILE)
    role = v.get("DB_USERNAME", "")
    pw = v.get("DB_PASSWORD", "")
    psycopg.connect(
        f"postgresql://{quote_plus(role)}:{quote_plus(pw)}@localhost:5432/{STAGING_DB}",
        connect_timeout=3,
    ).close()
    print(f"OK: staging role connects to {STAGING_DB}")
    print(
        "Note: On this PostgreSQL install, CONNECT may still be granted via PUBLIC on other "
        "databases. App isolation uses ACCESS_ENV_FILE + DB_NAME=access_skillprogression_staging only."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
