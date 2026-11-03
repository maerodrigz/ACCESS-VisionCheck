"""Phase 3D: authenticated participation smoke against staging API (no secrets in output)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:3011/api"


def _post(path: str, body: dict) -> dict:
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def _get(path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"{BASE}{path}",
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

    cases = [
        ("member@access.edu", "member123"),
        ("carlos.m@student.ustp.edu.ph", "member123"),
    ]

    try:
        _post("/auth/login", {"email": cases[0][0], "password": cases[0][1]})
    except urllib.error.URLError as exc:
        print(f"FAIL: staging API not reachable at {BASE} ({exc})")
        return 1

    any_fail = False
    for email, password in cases:
        print(f"--- smoke email={email}")
        login = _post("/auth/login", {"email": email, "password": password})
        token = login.get("token") or login.get("access_token")
        if not token:
            print("FAIL: login response missing token")
            return 1

        part = _get("/member/participation", token)
        db = SessionLocal()
        try:
            uid = db.execute(
                text("SELECT id FROM users WHERE lower(email)=lower(:e)"),
                {"e": email},
            ).scalar()
            snap = build_skill_progression_snapshot(db, int(uid))
        finally:
            db.close()

        checks = [
            ("policy_version", part.get("skill_progression_policy_version") == "v2"),
            ("policy_configured", part.get("skill_progression_policy_configured") == "v2"),
            ("blocked_reason_null", part.get("skill_progression_v2_blocked_reason") in (None, "")),
            (
                "eligible_count",
                part.get("skill_eligible_evaluations_count") == snap.eligible_evaluation_count,
            ),
            (
                "distinct_days",
                part.get("skill_eligible_distinct_upload_days")
                == snap.distinct_eligible_upload_days,
            ),
            (
                "quality_avg",
                abs(float(part.get("skill_quality_average") or 0) - snap.skill_score_pct) < 0.05,
            ),
            ("computed_tier", part.get("skill_computed_tier") == snap.computed_tier_active),
            ("effective_tier", part.get("skill_effective_tier") == snap.effective_tier),
            ("daily_limit", part.get("daily_evaluation_limit") == 3),
        ]
        failed = [name for name, ok in checks if not ok]
        for name, ok in checks:
            print(f"  check {name}={'PASS' if ok else 'FAIL'}")
        print(
            f"  tiers api computed={part.get('skill_computed_tier')} effective={part.get('skill_effective_tier')} "
            f"expected computed={snap.computed_tier_active} effective={snap.effective_tier} "
            f"v1={snap.computed_tier_v1} grandfather={snap.grandfather_floor}"
        )
        if failed:
            print(f"  FAIL checks: {failed}")
            any_fail = True

    if any_fail:
        return 1
    print("PASS api smoke (all cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
