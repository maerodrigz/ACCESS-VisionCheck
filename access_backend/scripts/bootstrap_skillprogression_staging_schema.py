"""
Initialize schema on access_skillprogression_staging only (Phase 1).

Requires: provision_skillprogression_staging.py and .env.skillprogression_staging

Usage:
  cd access_backend
  python scripts/bootstrap_skillprogression_staging_schema.py
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
STAGING_DB = "access_skillprogression_staging"
ENV_FILE = BACKEND / ".env.skillprogression_staging"


def _assert_staging_settings() -> None:
    os.environ["ACCESS_ENV_FILE"] = str(ENV_FILE.resolve())
    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(ENV_FILE)
    # Force reload settings
    from importlib import reload
    import app.config as config_mod

    reload(config_mod)
    from app.config import settings

    if settings.db_name != STAGING_DB:
        print(f"STOP: connected config DB_NAME={settings.db_name!r}, expected {STAGING_DB!r}")
        sys.exit(1)
    if settings.skill_progression_active_policy.strip().lower() not in ("v1", "legacy", "1"):
        print(f"STOP: staging policy must be v1, got {settings.skill_progression_active_policy!r}")
        sys.exit(1)
    if "RECREATE_DB" in os.environ and os.environ["RECREATE_DB"].lower() in ("1", "true", "yes"):
        print("STOP: RECREATE_DB must not be set for staging bootstrap")
        sys.exit(1)
    print(f"Verified staging target: db={settings.db_name} policy=v1 port={settings.api_port}")


def _run(cmd: list[str], extra_env: dict[str, str] | None = None) -> None:
    env = os.environ.copy()
    env["ACCESS_ENV_FILE"] = str(ENV_FILE.resolve())
    if extra_env:
        env.update(extra_env)
    print(">", " ".join(cmd))
    subprocess.run(cmd, cwd=BACKEND, env=env, check=True)


def main() -> int:
    if not ENV_FILE.is_file():
        print(f"Missing {ENV_FILE.name}. Run provision_skillprogression_staging.py first.")
        return 1

    _assert_staging_settings()

    _run([sys.executable, "create_tables.py"], {"SEED_DEMO_DATA": "true"})
    _run([sys.executable, "migrate_skill_progression_grandfather.py"])

    # Verify connect as staging role
    _assert_staging_settings()
    from sqlalchemy import inspect, text
    from app.database import engine

    insp = inspect(engine)
    tables = insp.get_table_names()
    print(f"Staging tables: {len(tables)}")
    with engine.connect() as conn:
        users = conn.execute(text("SELECT count(*) FROM users")).scalar()
        members = conn.execute(text(
            "SELECT count(*) FROM users u JOIN roles r ON r.id = u.role_id WHERE r.role_name = 'Member'"
        )).scalar()
    print(f"Staging users={users} members={members}")
    gf_cols = [
        c["name"]
        for c in insp.get_columns("member_rankings")
        if "grandfather" in c["name"]
    ]
    print(f"Grandfather columns: {gf_cols}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
