"""
Apply submission_chains_phase1 forward migration to the original `postgres` database only.

DO NOT use for access_waverep_test / access_uat. Reuses upgrade_submission_chains_phase1().
"""
from __future__ import annotations

import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

BACKEND_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BACKEND_ROOT, ".env"))

ALLOWED_DB = "postgres"
FORBIDDEN = frozenset({"access_waverep_test", "access_uat", "access"})


def _refuse_qa_env() -> None:
    if os.environ.pop("ACCESS_PYTEST_DB", None):
        print("NOTE: cleared ACCESS_PYTEST_DB from environment")
    url = (os.environ.get("DATABASE_URL") or "").strip().lower()
    for name in FORBIDDEN:
        if name in url and ALLOWED_DB not in url.split("/")[-1].split("?")[0]:
            print(f"ERROR: DATABASE_URL appears to target forbidden DB ({name})")
            sys.exit(2)
    if url and f"/{ALLOWED_DB}" not in url and not url.rstrip("/").endswith(f"/{ALLOWED_DB}"):
        # Explicit non-postgres URL override
        if "postgres" not in url.split("/")[-1].split("?")[0]:
            print("ERROR: DATABASE_URL override must point at postgres for this runner")
            sys.exit(2)


def main() -> int:
    _refuse_qa_env()
    from app.config import settings

    if settings.replacement_upload_enabled:
        print("ERROR: REPLACEMENT_UPLOAD_ENABLED must be false before schema migration")
        return 2

    db_name = (settings.db_name or "").strip()
    if db_name != ALLOWED_DB:
        print(f"ERROR: settings.db_name={db_name!r}, expected {ALLOWED_DB!r}")
        return 2

    engine = create_engine(settings.database_url, pool_pre_ping=True)
    with engine.connect() as conn:
        current = conn.execute(text("SELECT current_database()")).scalar()
        if current != ALLOWED_DB:
            print(f"ERROR: current_database()={current!r}, expected {ALLOWED_DB!r}")
            return 2
        print(f"Target database: {current}")

    from app.migrations.submission_chains_phase1 import (
        MIGRATION_ID,
        upgrade_submission_chains_phase1,
    )

    print(f"Applying migration {MIGRATION_ID}...")
    upgrade_submission_chains_phase1(engine)
    print("Migration complete.")
    engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
