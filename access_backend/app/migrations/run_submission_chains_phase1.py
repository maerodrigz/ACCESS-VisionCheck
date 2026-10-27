"""
Apply or revert submission_chains Phase 1 migration (isolated/dev use).

  python -m app.migrations.run_submission_chains_phase1 upgrade
  python -m app.migrations.run_submission_chains_phase1 downgrade

Does not run automatically against production.
"""

from __future__ import annotations

import os
import sys

from dotenv import load_dotenv

load_dotenv()

# Manual runner: isolated test DB only (never default access / access_uat).
os.environ.setdefault("ACCESS_PYTEST_DB", "access_waverep_test")

from app.migrations.isolated_test_database_url import ISOLATED_TEST_DB, isolated_test_database_url
from sqlalchemy import create_engine, text

_waverep_url = (os.environ.get("DATABASE_URL") or "").strip()
if ISOLATED_TEST_DB not in _waverep_url.lower():
    _waverep_url = isolated_test_database_url()
os.environ["DATABASE_URL"] = _waverep_url

_engine = create_engine(_waverep_url, pool_pre_ping=True)
with _engine.connect() as _c:
    _db = _c.execute(text("SELECT current_database()")).scalar()
    if _db != "access_waverep_test":
        raise SystemExit(f"Refusing: current_database() is {_db!r}, not access_waverep_test")
print(f"Target database: {_db}")

engine = _engine
from app.migrations.submission_chains_phase1 import (
    MIGRATION_ID,
    downgrade_submission_chains_phase1,
    upgrade_submission_chains_phase1,
)


def main() -> None:
    cmd = (sys.argv[1] if len(sys.argv) > 1 else "upgrade").strip().lower()
    if cmd == "upgrade":
        print(f"Applying migration {MIGRATION_ID}...")
        upgrade_submission_chains_phase1(engine)
        print("Done.")
    elif cmd == "downgrade":
        print(f"Reverting migration {MIGRATION_ID}...")
        downgrade_submission_chains_phase1(engine)
        print("Done.")
    else:
        raise SystemExit("Usage: python -m app.migrations.run_submission_chains_phase1 [upgrade|downgrade]")


if __name__ == "__main__":
    main()
