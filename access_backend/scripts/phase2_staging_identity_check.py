"""Phase 2 Step 1: verify staging DB identity before grandfather --apply."""

from __future__ import annotations

import sys
from pathlib import Path

from sqlalchemy import text

BACKEND = Path(__file__).resolve().parents[1]
STAGING_ENV = BACKEND / ".env.skillprogression_staging"


def main() -> int:
    import os

    env_marker = (os.environ.get("ACCESS_ENV_FILE") or "").strip()
    if not env_marker:
        print("FAIL: ACCESS_ENV_FILE not set")
        return 1
    resolved = Path(env_marker).resolve()
    if resolved.name != ".env.skillprogression_staging":
        print(f"FAIL: env file {resolved.name}")
        return 1

    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(resolved)

    from app.config import settings
    from app.database import SessionLocal

    print(f"env_file={resolved}")
    print(f"settings.db_name={settings.db_name}")
    print(f"settings.db_host={settings.db_host}")
    print(f"settings.db_port={settings.db_port}")
    print(f"settings.db_username={settings.db_username}")
    print(f"skill_progression_active_policy={settings.skill_progression_active_policy}")

    db = SessionLocal()
    try:
        row = db.execute(
            text(
                "SELECT current_database() AS db, current_user AS role, "
                "inet_server_port() AS port, version() AS version"
            )
        ).mappings().one()
        print(f"current_database={row['db']}")
        print(f"current_user={row['role']}")
        print(f"inet_server_port={row['port']}")

        priv = db.execute(
            text(
                "SELECT rolsuper, rolcreatedb, rolcreaterole FROM pg_roles "
                "WHERE rolname = current_user"
            )
        ).mappings().one()
        print(
            f"rolsuper={priv['rolsuper']} rolcreatedb={priv['rolcreatedb']} "
            f"rolcreaterole={priv['rolcreaterole']}"
        )

        for dbname in ("postgres", "access_uat", "access_waverep_test"):
            ok = db.execute(
                text(
                    "SELECT has_database_privilege(current_user, :n, 'CONNECT') AS c"
                ),
                {"n": dbname},
            ).scalar()
            print(f"has_connect_{dbname}={ok}")

        ok = (
            settings.db_name == "access_skillprogression_staging"
            and row["db"] == "access_skillprogression_staging"
            and row["role"] == "access_skillprogression_app"
            and settings.db_username == "access_skillprogression_app"
            and str(settings.skill_progression_active_policy).lower() in ("v1", "legacy", "1")
            and not priv["rolsuper"]
            and not priv["rolcreatedb"]
            and not priv["rolcreaterole"]
        )
        if not ok:
            print("FAIL: identity check")
            return 1
        print("PASS: staging identity verified")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
