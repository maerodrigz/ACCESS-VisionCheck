"""CLI: inspect | apply user presence timestamp columns."""

from __future__ import annotations

import json
import os
import sys

from sqlalchemy import create_engine

from app.config import settings
from app.migrations.isolated_test_database_url import isolated_test_database_url
from app.migrations.user_presence_timestamps import (
    inspect_user_presence_timestamps,
    upgrade_user_presence_timestamps,
)


def _engine_url() -> str:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() == "access_waverep_test":
        return isolated_test_database_url()
    return settings.database_url


def main(argv: list[str] | None = None) -> int:
    args = list(argv or sys.argv[1:])
    cmd = (args[0] if args else "inspect").strip().lower()
    engine = create_engine(_engine_url())
    if cmd == "inspect":
        info = inspect_user_presence_timestamps(engine)
        print(json.dumps(info, indent=2))
        print(
            "RESULT: migration is not needed."
            if not info["migration_needed"]
            else "RESULT: migration needed."
        )
        return 0
    if cmd == "apply":
        before = inspect_user_presence_timestamps(engine)
        upgrade_user_presence_timestamps(engine)
        after = inspect_user_presence_timestamps(engine)
        print(json.dumps({"before": before, "after": after}, indent=2))
        print("RESULT: applied")
        return 0
    print("Usage: python -m app.migrations.run_user_presence_timestamps [inspect|apply]")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
