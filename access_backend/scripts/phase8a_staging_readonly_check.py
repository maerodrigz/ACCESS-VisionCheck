"""Phase 8A: read-only staging isolation check."""

from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))
os.environ["ACCESS_ENV_FILE"] = str(BACKEND / ".env.skillprogression_staging")

from app.env_bootstrap import bootstrap_environment

bootstrap_environment(Path(os.environ["ACCESS_ENV_FILE"]))

from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal


def main() -> int:
    db = SessionLocal()
    try:
        row = db.execute(
            text("SELECT current_database(), current_user, inet_server_port()"),
        ).one()
        gf = db.execute(
            text(
                "SELECT count(*) FROM member_rankings "
                "WHERE skill_tier_grandfather_floor IS NOT NULL "
                "AND trim(skill_tier_grandfather_floor) <> ''"
            ),
        ).scalar()
        print("staging_database", row[0])
        print("staging_role", row[1])
        print("staging_port", row[2])
        print("api_port", settings.api_port)
        print("policy", settings.skill_progression_active_policy)
        print("grandfather_floors", int(gf or 0))
        ok = (
            str(row[0]) == "access_skillprogression_staging"
            and settings.skill_progression_active_policy.strip().lower() == "v2"
            and settings.api_port == 3011
            and int(gf or 0) == 8
        )
        print("staging_isolation_ok", ok)
        return 0 if ok else 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
