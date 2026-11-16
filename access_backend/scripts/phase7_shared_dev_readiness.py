"""Phase 7: read-only shared development rollout readiness (no writes)."""

from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))
os.environ.pop("ACCESS_ENV_FILE", None)
from app.env_bootstrap import bootstrap_environment

bootstrap_environment(BACKEND / ".env")
from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal


def main() -> int:
    db = SessionLocal()
    try:
        ident = db.execute(text("select current_database(), current_user")).one()
        print("database", ident[0])
        print("db_user", ident[1])
        print("api_port_env", settings.api_port)
        print("skill_progression_active_policy", settings.skill_progression_active_policy)

        approved = db.execute(
            text(
                "select count(*) from users u join roles r on r.id=u.role_id "
                "where lower(r.role_name)='member' and lower(u.status)='approved'"
            ),
        ).scalar()
        print("approved_members", approved)

        overrides = db.execute(
            text(
                "select count(*) from member_rankings "
                "where competency_level_override is not null "
                "and trim(competency_level_override) <> ''"
            ),
        ).scalar()
        print("admin_competency_overrides", overrides)

        gf_col = db.execute(
            text(
                "select exists (select 1 from information_schema.columns "
                "where table_schema='public' and table_name='member_rankings' "
                "and column_name='skill_tier_grandfather_floor')"
            ),
        ).scalar()
        print("grandfather_floor_column", bool(gf_col))
        if gf_col:
            captured = db.execute(
                text(
                    "select count(*) from member_rankings "
                    "where skill_tier_grandfather_floor is not null "
                    "and trim(skill_tier_grandfather_floor) <> ''"
                ),
            ).scalar()
            print("grandfather_floor_rows", captured)

        print(
            "grandfather_dry_run_note",
            "Run skill_progression_capture_grandfather.py (no --apply) on shared dev after schema bootstrap.",
        )
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
