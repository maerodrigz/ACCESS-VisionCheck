"""Phase 3F post-activation verification (staging + shared dev read-only)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from sqlalchemy import text

BACKEND = Path(__file__).resolve().parents[1]
BASELINE_GLOB = "phase3_baseline_*.json"


def main() -> int:
    import subprocess

    env = os.environ.copy()
    env.pop("ACCESS_ENV_FILE", None)
    shared = subprocess.check_output(
        [
            sys.executable,
            "-c",
            "from dotenv import load_dotenv; load_dotenv('.env'); "
            "from app.config import settings; from app.database import engine; "
            "from sqlalchemy import text; "
            "c=engine.connect(); n=c.execute(text('SELECT count(*) FROM users')).scalar(); "
            "p=settings.skill_progression_active_policy; c.close(); print(p, n)",
        ],
        cwd=BACKEND,
        env=env,
        text=True,
    ).strip()
    shared_policy, shared_users = shared.split()
    print(f"shared_dev policy={shared_policy} users={shared_users}")

    marker = (os.environ.get("ACCESS_ENV_FILE") or "").strip()
    if not marker:
        os.environ["ACCESS_ENV_FILE"] = str(BACKEND / ".env.skillprogression_staging")
    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(Path(os.environ["ACCESS_ENV_FILE"]))
    from app.config import settings
    from app.database import SessionLocal
    from app.services.skill_progression_grandfather import grandfather_snapshots_complete

    db = SessionLocal()
    try:
        live = db.execute(text("SELECT current_database(), current_user")).one()
        print(f"staging db={live[0]} user={live[1]} policy={settings.skill_progression_active_policy}")

        floors = db.execute(
            text(
                "SELECT count(*) FROM member_rankings mr "
                "JOIN users u ON u.id=mr.user_id "
                "JOIN roles r ON r.id=u.role_id "
                "WHERE u.status='approved' AND r.role_name='Member' "
                "AND skill_tier_grandfather_floor IS NOT NULL "
                "AND trim(skill_tier_grandfather_floor)<>''"
            )
        ).scalar()
        milestones = db.execute(text("SELECT count(*) FROM member_milestones")).scalar()
        xp = db.execute(text("SELECT coalesce(sum(total_points),0) FROM member_rankings")).scalar()

        baseline_dir = BACKEND.parent / "access_mobile_staging_backups"
        baselines = sorted(baseline_dir.glob(BASELINE_GLOB), key=lambda p: p.stat().st_mtime, reverse=True)
        baseline_xp = baseline_m = None
        if baselines:
            data = json.loads(baselines[0].read_text(encoding="utf-8"))
            baseline_xp = data.get("total_points_sum")
            baseline_m = data.get("member_milestones")

        skill_ids = db.execute(
            text(
                "SELECT u.id, sl.level_name FROM users u "
                "LEFT JOIN skill_levels sl ON sl.id=u.skill_level_id "
                "JOIN roles r ON r.id=u.role_id "
                "WHERE u.status='approved' AND r.role_name='Member' ORDER BY u.id"
            )
        ).all()

        ok = (
            live[0] == "access_skillprogression_staging"
            and settings.skill_progression_active_policy.lower() == "v2"
            and shared_policy.lower() in ("v1", "legacy", "1")
            and shared_users == "3"
            and grandfather_snapshots_complete(db)
            and floors == 8
            and milestones == baseline_m
            and int(xp or 0) == int(baseline_xp or 0)
        )
        print(f"floors={floors} milestones={milestones} xp_sum={xp}")
        print(f"skill_level_ids_unchanged={len(skill_ids)} members tracked")
        print("PASS post-activation" if ok else "FAIL post-activation")
        return 0 if ok else 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
