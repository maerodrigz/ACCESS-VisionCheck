"""
Inspect or apply the media_evaluations nullable-scores migration.

Default is inspect only (no DDL).

  python -m app.migrations.run_media_evaluations_nullable_scores inspect
  python -m app.migrations.run_media_evaluations_nullable_scores apply

Does not import or run create_tables.py.
"""

from __future__ import annotations

import json
import sys

from app.config import settings
from app.database import engine
from app.migrations.media_evaluations_nullable_scores import (
    MIGRATION_ID,
    inspect_media_evaluations_schema,
    upgrade_media_evaluations_nullable_scores,
)


def _print_inspect(payload: dict) -> None:
    masked = settings.database_url.replace(settings.db_password, "****")
    print(f"Migration: {MIGRATION_ID}")
    print(f"Configured URL: {masked}")
    print(json.dumps(payload, default=str, indent=2))
    if not payload.get("table_exists"):
        print("RESULT: media_evaluations is missing. Do not apply this ALTER.")
        return
    if payload.get("migration_needed"):
        print("RESULT: migration is needed (one or more score columns are still NOT NULL).")
    else:
        print("RESULT: migration is not needed (all six score columns are already nullable).")


def main() -> None:
    cmd = (sys.argv[1] if len(sys.argv) > 1 else "inspect").strip().lower()
    if cmd == "inspect":
        _print_inspect(inspect_media_evaluations_schema(engine))
        return
    if cmd == "apply":
        before = inspect_media_evaluations_schema(engine)
        _print_inspect(before)
        if not before.get("table_exists"):
            raise SystemExit("Refusing apply: media_evaluations does not exist.")
        if not before.get("migration_needed"):
            print("Apply skipped: schema already matches the target.")
            return
        print("Applying ALTER TABLE media_evaluations ... DROP NOT NULL (six score columns).")
        upgrade_media_evaluations_nullable_scores(engine)
        after = inspect_media_evaluations_schema(engine)
        print("After apply:")
        _print_inspect(after)
        return
    raise SystemExit(
        "Usage: python -m app.migrations.run_media_evaluations_nullable_scores [inspect|apply]"
    )


if __name__ == "__main__":
    main()
