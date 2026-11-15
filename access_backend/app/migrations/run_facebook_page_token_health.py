"""CLI: inspect | apply facebook_page_token_health migration."""

from __future__ import annotations

import json
import os
import sys

from sqlalchemy import create_engine

from app.config import settings
from app.migrations.facebook_page_token_health import (
    inspect_facebook_page_token_health,
    upgrade_facebook_page_token_health,
)
from app.migrations.isolated_test_database_url import isolated_test_database_url


def _engine_url() -> str:
    if os.environ.get("ACCESS_PYTEST_DB", "").strip() == "access_waverep_test":
        return isolated_test_database_url()
    return settings.database_url


def main(argv: list[str] | None = None) -> int:
    args = list(argv or sys.argv[1:])
    cmd = (args[0] if args else "inspect").strip().lower()
    engine = create_engine(_engine_url())
    if cmd == "inspect":
        info = inspect_facebook_page_token_health(engine)
        print(json.dumps(info, indent=2))
        print("RESULT: migration is not needed." if not info["migration_needed"] else "RESULT: migration needed.")
        return 0
    if cmd == "apply":
        before = inspect_facebook_page_token_health(engine)
        upgrade_facebook_page_token_health(engine)
        after = inspect_facebook_page_token_health(engine)
        print(json.dumps({"before": before, "after": after}, indent=2))
        print("RESULT: applied")
        return 0
    print("Usage: python -m app.migrations.run_facebook_page_token_health [inspect|apply]")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
