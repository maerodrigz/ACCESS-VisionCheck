"""Compare participation API vs build_skill_progression_snapshot for all approved staging members."""

from __future__ import annotations

import json
import os
import urllib.request
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:3011/api"
MEMBER_PW = "member123"


def _login(email: str) -> str:
    req = urllib.request.Request(
        f"{BASE}/auth/login",
        data=json.dumps({"email": email, "password": MEMBER_PW}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = json.loads(resp.read().decode())
    token = body.get("token") or body.get("access_token")
    if not token:
        raise RuntimeError(f"login failed for {email}")
    return token


def _participation(token: str) -> dict:
    req = urllib.request.Request(
        f"{BASE}/member/participation",
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def main() -> int:
    os.environ.setdefault("ACCESS_ENV_FILE", str(BACKEND / ".env.skillprogression_staging"))
    from app.env_bootstrap import bootstrap_environment

    bootstrap_environment(Path(os.environ["ACCESS_ENV_FILE"]))
    from app.database import SessionLocal
    from app.services.skill_progression import build_skill_progression_snapshot
    from sqlalchemy import text

    db = SessionLocal()
    try:
        rows = db.execute(
            text(
                """
                SELECT u.id, u.email, sl.level_name AS stored_label
                FROM users u
                JOIN roles r ON r.id = u.role_id AND r.role_name = 'Member'
                LEFT JOIN skill_levels sl ON sl.id = u.skill_level_id
                WHERE u.status = 'approved'
                ORDER BY u.id
                """
            )
        ).fetchall()
        print(f"approved_members={len(rows)}")
        any_fail = False
        for uid, email, stored in rows:
            snap = build_skill_progression_snapshot(db, int(uid))
            part = _participation(_login(email))
            checks = {
                "computed": part.get("skill_computed_tier") == snap.computed_tier_active,
                "effective": part.get("skill_effective_tier") == snap.effective_tier,
                "eligible": part.get("skill_eligible_evaluations_count")
                == snap.eligible_evaluation_count,
                "days": part.get("skill_eligible_distinct_upload_days")
                == snap.distinct_eligible_upload_days,
                "policy": part.get("skill_progression_policy_version") == "v2",
            }
            if not all(checks.values()):
                any_fail = True
            print(
                f"email={email} stored={stored or 'N/A'} "
                f"effective={snap.effective_tier} computed_v2={snap.computed_tier_active} "
                f"v1={snap.computed_tier_v1} floor={snap.grandfather_floor or '-'} "
                f"elig={snap.eligible_evaluation_count} days={snap.distinct_eligible_upload_days} "
                f"quality={snap.skill_score_pct:.1f} next_evals={part.get('skill_next_tier_required_evaluations')} "
                f"next_days={part.get('skill_next_tier_required_days')} "
                f"rem_evals={part.get('skill_remaining_eligible_evaluations')} "
                f"rem_days={part.get('skill_remaining_distinct_upload_days')} "
                f"match={all(checks.values())}"
            )
        return 1 if any_fail else 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
