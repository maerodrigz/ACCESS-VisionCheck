"""
Additive migration for Skill Progression v2 activation seal + cohort tables.

Does NOT capture snapshots, seal activation, or change policy.

By default refuses shared-dev (DB_NAME=postgres) and requires
ACCESS_PYTEST_DB=access_waverep_test (isolated) OR --allow-shared-dev for
explicit local operator override (still no auto cohort enrollment).

Usage:
  cd access_backend
  $env:ACCESS_PYTEST_DB = "access_waverep_test"
  python migrate_skill_progression_v2_activation.py
  python migrate_skill_progression_v2_activation.py --downgrade
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parent
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from app.config import settings
from app.database import engine
from app.migrations.skill_progression_v2_activation import (
    MIGRATION_ID,
    downgrade_skill_progression_v2_activation,
    skill_progression_v2_activation_tables_exist,
    upgrade_skill_progression_v2_activation,
)


def _assert_target_allowed(*, allow_shared_dev: bool) -> None:
    marker = os.environ.get("ACCESS_PYTEST_DB", "").strip()
    if marker == "access_waverep_test":
        if settings.db_name != "access_waverep_test":
            raise SystemExit(
                f"ACCESS_PYTEST_DB=access_waverep_test but DB_NAME={settings.db_name!r}"
            )
        return
    if settings.db_name == "postgres":
        if not allow_shared_dev:
            raise SystemExit(
                "STOP: refusing migration on shared-dev DB_NAME=postgres. "
                "Use ACCESS_PYTEST_DB=access_waverep_test for isolated tests, "
                "or pass --allow-shared-dev only with explicit operator approval."
            )
        return
    if settings.db_name in {"access_uat"}:
        raise SystemExit(f"STOP: refusing migration on {settings.db_name!r}.")
    # Other named DBs require explicit allow for safety.
    if not allow_shared_dev:
        raise SystemExit(
            f"STOP: DB_NAME={settings.db_name!r} is not the isolated test DB. "
            "Pass --allow-shared-dev only with approval."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=f"Migration {MIGRATION_ID}")
    parser.add_argument("--downgrade", action="store_true")
    parser.add_argument(
        "--allow-shared-dev",
        action="store_true",
        help="Explicit override to run against non-isolated local DB (no auto-cohort).",
    )
    args = parser.parse_args()
    _assert_target_allowed(allow_shared_dev=args.allow_shared_dev)

    if args.downgrade:
        downgrade_skill_progression_v2_activation(engine)
        print(f"{MIGRATION_ID} downgraded; tables_exist={skill_progression_v2_activation_tables_exist(engine)}")
        return 0

    upgrade_skill_progression_v2_activation(engine)
    print(
        f"{MIGRATION_ID} upgraded; tables_exist={skill_progression_v2_activation_tables_exist(engine)} "
        f"db={settings.db_name}"
    )
    print("NOTE: No members were enrolled in the grandfather cohort.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
