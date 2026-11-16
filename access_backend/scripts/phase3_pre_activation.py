"""Phase 3A/3B: pre-activation checks and baseline (staging only)."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import text

BACKEND = Path(__file__).resolve().parents[1]
STAGING_ENV = BACKEND / ".env.skillprogression_staging"
REPORT_DIR = BACKEND.parent / "access_mobile_staging_backups"
BACKUP_GLOB = "access_skillprogression_staging_*.dump"


def _load_staging() -> Path:
    marker = (os.environ.get("ACCESS_ENV_FILE") or "").strip()
    if not marker:
        print("FAIL: ACCESS_ENV_FILE not set")
        sys.exit(1)
    path = Path(marker).resolve()
    if path.name != ".env.skillprogression_staging":
        print(f"FAIL: wrong env file {path.name}")
        sys.exit(1)
    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(path)
    return path


def _shared_dev_policy() -> str:
    import subprocess

    env = os.environ.copy()
    env.pop("ACCESS_ENV_FILE", None)
    out = subprocess.check_output(
        [
            sys.executable,
            "-c",
            "from dotenv import load_dotenv; load_dotenv('.env'); "
            "from app.config import settings; print(settings.skill_progression_active_policy)",
        ],
        cwd=BACKEND,
        env=env,
        text=True,
    ).strip()
    return out


def main() -> int:
    env_path = _load_staging()
    from app.config import settings
    from app.database import SessionLocal
    from app.services.skill_progression import build_skill_progression_snapshot
    from app.services.skill_progression_grandfather import grandfather_snapshots_complete

    print(f"env_file={env_path}")
    print(f"settings.db_name={settings.db_name}")
    print(f"settings.api_port={settings.api_port}")
    print(f"staging_policy={settings.skill_progression_active_policy}")
    print(f"shared_dev_policy={_shared_dev_policy()}")

    if settings.db_name != "access_skillprogression_staging":
        print("FAIL db_name")
        return 1
    if settings.api_port != 3011:
        print("FAIL api_port")
        return 1
    if str(settings.skill_progression_active_policy).lower() not in ("v1", "legacy", "1"):
        print("FAIL staging must be v1 before activation")
        return 1
    if _shared_dev_policy().lower() not in ("v1", "legacy", "1"):
        print("FAIL shared dev must remain v1")
        return 1

    db = SessionLocal()
    try:
        live = db.execute(
            text(
                "SELECT current_database(), current_user, inet_server_port()"
            )
        ).one()
        priv = db.execute(
            text(
                "SELECT rolsuper, rolcreatedb, rolcreaterole FROM pg_roles "
                "WHERE rolname = current_user"
            )
        ).one()
        print(f"current_database={live[0]} current_user={live[1]} port={live[2]}")
        if live[0] != "access_skillprogression_staging" or live[1] != "access_skillprogression_app":
            print("FAIL live connection identity")
            return 1
        if priv[0] or priv[1] or priv[2]:
            print("FAIL role privileges")
            return 1

        if not grandfather_snapshots_complete(db):
            print("FAIL grandfather incomplete")
            return 1

        members = db.execute(
            text(
                """
                SELECT u.id, u.email, sl.level_name, mr.skill_tier_grandfather_floor,
                       mr.competency_level_override
                FROM users u
                JOIN roles r ON r.id = u.role_id
                LEFT JOIN skill_levels sl ON sl.id = u.skill_level_id
                LEFT JOIN member_rankings mr ON mr.user_id = u.id
                WHERE u.status = 'approved' AND r.role_name = 'Member'
                ORDER BY u.id
                """
            )
        ).all()

        baseline_members = []
        for row in members:
            uid = row[0]
            snap = build_skill_progression_snapshot(db, uid)
            baseline_members.append(
                {
                    "user_id": uid,
                    "email": row[1],
                    "skill_level_id_name": row[2],
                    "grandfather_floor": row[3],
                    "admin_override": row[4],
                    "computed_tier_v1": snap.computed_tier_v1,
                    "computed_tier_v2_raw": snap.computed_tier_v2_raw,
                    "computed_tier_active_v1_policy": snap.computed_tier_active,
                    "effective_tier_v1_policy": snap.effective_tier,
                    "eligible_count": snap.eligible_evaluation_count,
                    "distinct_days": snap.distinct_eligible_upload_days,
                    "quality_pct": snap.skill_score_pct,
                }
            )
            if row[3] and snap.computed_tier_v1 != row[3]:
                print(f"WARN floor mismatch user_id={uid}")

        milestones = db.execute(text("SELECT count(*) FROM member_milestones")).scalar()
        xp_sum = db.execute(text("SELECT coalesce(sum(total_points),0) FROM member_rankings")).scalar()

        backups = sorted(REPORT_DIR.glob(BACKUP_GLOB), key=lambda p: p.stat().st_mtime, reverse=True)
        backup_ok = bool(backups and backups[0].stat().st_size > 1024)

        report = {
            "captured_at": datetime.now(timezone.utc).isoformat(),
            "phase": "3B_baseline_pre_v2",
            "database": live[0],
            "policy": settings.skill_progression_active_policy,
            "approved_members": len(baseline_members),
            "grandfather_complete": True,
            "member_milestones": milestones,
            "total_points_sum": int(xp_sum or 0),
            "members": baseline_members,
            "backup_latest": str(backups[0]) if backups else None,
        }
        REPORT_DIR.mkdir(parents=True, exist_ok=True)
        out = REPORT_DIR / f"phase3_baseline_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"baseline_report={out}")
        print(f"backup_readable={backup_ok}")
        print(f"members={len(baseline_members)} milestones={milestones} xp_sum={xp_sum}")
        print("PASS pre-activation")
        return 0 if backup_ok and len(baseline_members) == 8 else 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
