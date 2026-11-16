"""Read-only DB fingerprint for before/after dry-run comparison."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))
if "ACCESS_ENV_FILE" in os.environ:
    del os.environ["ACCESS_ENV_FILE"]

from app.env_bootstrap import bootstrap_environment

bootstrap_environment(BACKEND / ".env")

from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal


def fingerprint() -> dict:
    db = SessionLocal()
    try:
        ident = db.execute(
            text("SELECT current_database(), current_user"),
        ).one()
        counts = {
            "approved_members": db.execute(
                text(
                    "SELECT count(*) FROM users u JOIN roles r ON r.id = u.role_id "
                    "WHERE lower(r.role_name) = 'member' AND lower(u.status) = 'approved'"
                ),
            ).scalar(),
            "grandfather_floors": db.execute(
                text(
                    "SELECT count(*) FROM member_rankings "
                    "WHERE skill_tier_grandfather_floor IS NOT NULL "
                    "AND trim(skill_tier_grandfather_floor) <> ''"
                ),
            ).scalar(),
            "overrides": db.execute(
                text(
                    "SELECT count(*) FROM member_rankings "
                    "WHERE competency_level_override IS NOT NULL "
                    "AND trim(competency_level_override) <> ''"
                ),
            ).scalar(),
        }
        skills = db.execute(
            text(
                "SELECT u.id, u.skill_level_id, mr.total_points "
                "FROM users u LEFT JOIN member_rankings mr ON mr.user_id = u.id "
                "WHERE u.id IN (SELECT u2.id FROM users u2 JOIN roles r ON r.id = u2.role_id "
                "WHERE lower(r.role_name) = 'member')"
            ),
        ).fetchall()
        return {
            "database": str(ident[0]),
            "role": str(ident[1]),
            "policy": settings.skill_progression_active_policy,
            "counts": {k: int(v or 0) for k, v in counts.items()},
            "members": [
                {"user_id": r[0], "skill_level_id": r[1], "total_points": int(r[2] or 0)}
                for r in skills
            ],
        }
    finally:
        db.close()


def main() -> int:
    label = sys.argv[1] if len(sys.argv) > 1 else "snapshot"
    fp = fingerprint()
    out = BACKEND.parent / "access_mobile_staging_backups" / f"phase8a_fingerprint_{label}.json"
    out.write_text(json.dumps(fp, indent=2), encoding="utf-8")
    print(label, json.dumps(fp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
