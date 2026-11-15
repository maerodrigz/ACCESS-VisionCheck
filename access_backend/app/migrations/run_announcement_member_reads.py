"""
Inspect or apply announcement_member_reads migration.

  python -m app.migrations.run_announcement_member_reads inspect
  python -m app.migrations.run_announcement_member_reads apply

When ACCESS_PYTEST_DB=access_waverep_test, targets that isolated DB.
Otherwise uses the configured app database (local/dev).

Does not import create_tables.py. Production apply requires explicit approval.
"""

from __future__ import annotations

import os
import sys

from sqlalchemy import create_engine

from app.database import engine as app_engine
from app.migrations.announcement_member_reads import (
    inspect_announcement_member_reads,
    upgrade_announcement_member_reads,
)
from app.migrations.isolated_test_database_url import (
    ISOLATED_TEST_DB,
    isolated_test_database_url,
)


def _target_engine():
    marker = os.environ.get("ACCESS_PYTEST_DB", "").strip()
    if marker == ISOLATED_TEST_DB:
        return create_engine(isolated_test_database_url())
    return app_engine


def main(argv: list[str] | None = None) -> int:
    args = list(argv if argv is not None else sys.argv[1:])
    cmd = (args[0] if args else "inspect").strip().lower()
    engine = _target_engine()
    before = inspect_announcement_member_reads(engine)
    print(before)
    if before.get("migration_needed"):
        print("RESULT: migration is needed.")
    else:
        print("RESULT: migration is not needed.")

    if cmd == "inspect":
        return 0
    if cmd == "apply":
        if not before.get("migration_needed"):
            print("Nothing to apply.")
            return 0
        upgrade_announcement_member_reads(engine)
        after = inspect_announcement_member_reads(engine)
        print(after)
        print("RESULT: applied.")
        return 0
    print(
        "Usage: python -m app.migrations.run_announcement_member_reads [inspect|apply]"
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
