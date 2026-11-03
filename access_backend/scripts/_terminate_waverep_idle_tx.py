"""Terminate idle-in-transaction backends on access_waverep_test only."""
from __future__ import annotations

import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
os.environ.setdefault("ACCESS_PYTEST_DB", "access_waverep_test")
from app.migrations.isolated_test_database_url import isolated_test_database_url

engine = create_engine(isolated_test_database_url())
with engine.begin() as conn:
    db = conn.execute(text("SELECT current_database()")).scalar()
    if db != "access_waverep_test":
        sys.exit(f"Refusing: {db!r}")
    rows = conn.execute(
        text(
            """
            SELECT pid FROM pg_stat_activity
            WHERE datname = current_database()
              AND pid <> pg_backend_pid()
              AND state = 'idle in transaction'
            """
        )
    ).fetchall()
    for (pid,) in rows:
        conn.execute(text("SELECT pg_terminate_backend(:p)"), {"p": pid})
        print("terminated", pid)
engine.dispose()
