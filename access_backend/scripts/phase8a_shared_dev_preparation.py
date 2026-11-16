"""Phase 8A: read-only shared dev preparation (no --apply, no writes)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND.parent
OUTPUT_DIR = REPO_ROOT / "access_mobile_staging_backups"

sys.path.insert(0, str(BACKEND))
if "ACCESS_ENV_FILE" in os.environ:
    del os.environ["ACCESS_ENV_FILE"]

from app.env_bootstrap import bootstrap_environment

bootstrap_environment(BACKEND / ".env")

from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal
from app.services.skill_progression import build_skill_progression_snapshot

FORBIDDEN_DBS = frozenset(
    {"access_skillprogression_staging", "access_uat", "access_waverep_test"}
)


def _identity(db) -> dict:
    row = db.execute(
        text(
            "SELECT current_database() AS db, current_user AS role, "
            "inet_server_addr() AS host, inet_server_port() AS port"
        ),
    ).mappings().one()
    return dict(row)


def _counts(db) -> dict:
    approved = db.execute(
        text(
            "SELECT count(*) FROM users u JOIN roles r ON r.id = u.role_id "
            "WHERE lower(r.role_name) = 'member' AND lower(u.status) = 'approved'"
        ),
    ).scalar()
    gf = db.execute(
        text(
            "SELECT count(*) FROM member_rankings "
            "WHERE skill_tier_grandfather_floor IS NOT NULL "
            "AND trim(skill_tier_grandfather_floor) <> ''"
        ),
    ).scalar()
    overrides = db.execute(
        text(
            "SELECT count(*) FROM member_rankings "
            "WHERE competency_level_override IS NOT NULL "
            "AND trim(competency_level_override) <> ''"
        ),
    ).scalar()
    cols = db.execute(
        text(
            "SELECT count(*) FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = 'member_rankings' "
            "AND column_name IN ("
            "'skill_tier_grandfather_floor', "
            "'skill_tier_grandfather_captured_at', "
            "'skill_tier_grandfather_from_policy'"
            ")"
        ),
    ).scalar()
    return {
        "approved_members": int(approved or 0),
        "grandfather_floor_rows": int(gf or 0),
        "admin_competency_overrides": int(overrides or 0),
        "grandfather_column_count": int(cols or 0),
    }


def _member_baseline(db, user_id: int) -> dict:
    u = db.execute(
        text(
            "SELECT u.id, u.email, u.status, u.skill_level_id "
            "FROM users u WHERE u.id = :id"
        ),
        {"id": user_id},
    ).mappings().one_or_none()
    if not u:
        return {"error": f"user_id {user_id} not found"}
    snap = build_skill_progression_snapshot(db, user_id)
    mr = db.execute(
        text(
            "SELECT competency_level_override, skill_tier_grandfather_floor, "
            "total_points, rank_position "
            "FROM member_rankings WHERE user_id = :id"
        ),
        {"id": user_id},
    ).mappings().one_or_none()
    legacy = db.execute(
        text("SELECT level_name FROM skill_levels WHERE id = :sid"),
        {"sid": u["skill_level_id"]},
    ).scalar()
    milestone_count = None
    has_ms = db.execute(
        text(
            "SELECT exists (SELECT 1 FROM information_schema.tables "
            "WHERE table_schema='public' AND table_name='member_milestones')"
        ),
    ).scalar()
    if has_ms:
        milestone_count = db.execute(
            text("SELECT count(*) FROM member_milestones WHERE user_id = :id"),
            {"id": user_id},
        ).scalar()
    return {
        "user_id": user_id,
        "email": u["email"],
        "status": u["status"],
        "total_points": int((mr or {}).get("total_points") or 0),
        "rank_position": (mr or {}).get("rank_position"),
        "users_skill_level_id": u["skill_level_id"],
        "legacy_stored_skill_label": legacy,
        "computed_tier_v1_policy": snap.computed_tier_v1,
        "effective_tier": snap.effective_tier,
        "skill_score_pct": snap.skill_score_pct,
        "eligible_evaluation_count": snap.eligible_evaluation_count,
        "distinct_eligible_upload_days": snap.distinct_eligible_upload_days,
        "grandfather_floor": (mr or {}).get("skill_tier_grandfather_floor"),
        "competency_level_override": (mr or {}).get("competency_level_override"),
        "milestone_count": int(milestone_count or 0) if milestone_count is not None else None,
    }


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

    report: dict = {
        "phase": "8A",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "settings": {
            "db_name": settings.db_name,
            "db_host": settings.db_host,
            "db_port": settings.db_port,
            "api_port": settings.api_port,
            "skill_progression_active_policy": settings.skill_progression_active_policy,
        },
    }

    if settings.db_name != "postgres":
        print("FAIL: settings.db_name != postgres")
        return 1
    if settings.db_name in FORBIDDEN_DBS:
        print("FAIL: forbidden database name")
        return 1
    if settings.skill_progression_active_policy.strip().lower() not in ("v1", "legacy", "1"):
        print("FAIL: policy is not v1")
        return 1
    if settings.api_port != 3001:
        print("FAIL: api_port != 3001")
        return 1

    db = SessionLocal()
    try:
        ident = _identity(db)
        report["live_identity"] = {
            "current_database": str(ident["db"]),
            "current_user": str(ident["role"]),
            "inet_server_addr": str(ident["host"]),
            "inet_server_port": ident["port"],
        }
        if str(ident["db"]) != "postgres":
            print("FAIL: current_database() != postgres")
            return 1
        if int(ident["port"] or 0) != 5432:
            print("FAIL: inet_server_port != 5432")
            return 1

        report["counts"] = _counts(db)
        report["member_77"] = _member_baseline(db, 77)

        approved_rows = db.execute(
            text(
                "SELECT u.id FROM users u JOIN roles r ON r.id = u.role_id "
                "WHERE lower(r.role_name) = 'member' AND lower(u.status) = 'approved' "
                "ORDER BY u.id"
            ),
        ).fetchall()
        report["approved_member_ids"] = [int(r[0]) for r in approved_rows]
    finally:
        db.close()

    out_json = OUTPUT_DIR / f"phase8a_shared_dev_baseline_{ts}.json"
    out_json.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("baseline_json", out_json)
    print("identity_ok", report["live_identity"])
    print("counts", report["counts"])
    print("member_77_computed_v1", report["member_77"].get("computed_tier_v1_policy"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
