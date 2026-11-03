"""Phase 2 post-apply verification for grandfather snapshots on staging."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from sqlalchemy import text

BACKEND = Path(__file__).resolve().parents[1]


def main() -> int:
    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(Path(os.environ["ACCESS_ENV_FILE"]))
    from app.config import settings
    from app.database import SessionLocal
    from app.services.skill_progression_grandfather import (
        grandfather_snapshots_complete,
        members_missing_grandfather_snapshot,
    )

    db = SessionLocal()
    try:
        live = db.execute(
            text("SELECT current_database(), current_user")
        ).one()
        print(f"current_database={live[0]} current_user={live[1]}")
        print(f"policy={settings.skill_progression_active_policy}")

        rows = db.execute(
            text(
                """
                SELECT mr.user_id, mr.skill_tier_grandfather_floor,
                       mr.skill_tier_grandfather_from_policy,
                       mr.skill_tier_grandfather_captured_at IS NOT NULL AS has_ts
                FROM member_rankings mr
                JOIN users u ON u.id = mr.user_id
                JOIN roles r ON r.id = u.role_id
                WHERE u.status = 'approved' AND r.role_name = 'Member'
                ORDER BY mr.user_id
                """
            )
        ).all()
        print(f"approved_member_rankings={len(rows)}")
        missing = [r for r in rows if not r[1] or not str(r[1]).strip()]
        print(f"missing_floor={len(missing)}")
        for r in rows:
            print(f"  user_id={r[0]} floor={r[1]} from_policy={r[2]} has_ts={r[3]}")

        print(f"grandfather_snapshots_complete={grandfather_snapshots_complete(db)}")
        print(f"missing_ids={members_missing_grandfather_snapshot(db)}")

        snap = db.execute(
            text(
                "SELECT count(*) FROM member_milestones"
            )
        ).scalar()
        pts = db.execute(text("SELECT sum(total_points) FROM member_rankings")).scalar()
        print(f"member_milestones={snap} total_points_sum={pts}")
        return 0 if not missing and grandfather_snapshots_complete(db) else 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
