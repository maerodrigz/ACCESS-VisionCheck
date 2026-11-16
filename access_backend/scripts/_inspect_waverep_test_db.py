"""One-off inspect access_waverep_test (no secrets printed)."""
from __future__ import annotations

import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
from app.config import settings

url = (os.environ.get("DATABASE_URL") or settings.database_url or "").strip()
if os.environ.get("ACCESS_PYTEST_DB", "").strip() == "access_waverep_test":
    from app.migrations.isolated_test_database_url import isolated_test_database_url

    url = isolated_test_database_url()
if "access_waverep_test" not in url.lower():
    sys.exit("Refusing: must target access_waverep_test only")

engine = create_engine(url, pool_pre_ping=True)
with engine.connect() as conn:
    db = conn.execute(text("SELECT current_database()")).scalar()
    print("current_database:", db)
    cols = conn.execute(
        text(
            """
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'media_files'
              AND column_name IN ('submission_chain_id','replaces_media_id','replacement_lifecycle')
            ORDER BY 1
            """
        )
    ).fetchall()
    print("media_files chain cols:", [r[0] for r in cols])
    tables = conn.execute(
        text(
            """
            SELECT tablename FROM pg_tables
            WHERE schemaname = 'public' AND tablename LIKE 'submission%'
            ORDER BY 1
            """
        )
    ).fetchall()
    print("submission tables:", [r[0] for r in tables])
    idle = conn.execute(
        text(
            """
            SELECT pid, state, wait_event_type, wait_event,
                   pg_blocking_pids(pid) AS blockers,
                   left(query, 100) AS q
            FROM pg_stat_activity
            WHERE datname = current_database() AND pid <> pg_backend_pid()
            ORDER BY state, pid
            """
        )
    ).fetchall()
    print("other backends:", len(idle))
    for row in idle:
        print(" ", row)
engine.dispose()
