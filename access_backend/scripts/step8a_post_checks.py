"""Step 8A post-smoke: DB idempotency, admin alerts, restart verification helpers."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import httpx
from sqlalchemy import func, select, text

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.database import SessionLocal
from app.models.ai_detection_result import AiDetectionResult
from app.models.media_file import MediaFile
from app.models.notification import Notification
from app.models.media_evaluation import MediaEvaluation
from app.models.member_ranking import MemberRanking

API_BASE = os.environ.get("SMOKE_API_BASE", "http://127.0.0.1:3001/api")
MEDIA_IDS = (112, 113)


def db_snapshot() -> dict:
    db = SessionLocal()
    try:
        out: dict = {"media": {}}
        for mid in MEDIA_IDS:
            ev_count = db.scalar(
                select(func.count()).select_from(MediaEvaluation).where(MediaEvaluation.media_id == mid)
            )
            ai_count = db.scalar(
                select(func.count()).select_from(AiDetectionResult).where(AiDetectionResult.media_id == mid)
            )
            mf = db.get(MediaFile, mid)
            out["media"][mid] = {
                "media_evaluations": int(ev_count or 0),
                "ai_detection_results": int(ai_count or 0),
                "media_file_name": mf.file_name if mf else None,
            }
        alerts = db.execute(
            select(Notification.id, Notification.user_id, Notification.title, Notification.category, Notification.action_ref_id)
            .where(Notification.action_ref_id.in_(MEDIA_IDS))
            .order_by(Notification.id.desc())
        ).all()
        out["admin_alerts_by_media"] = {
            str(r.action_ref_id): {"id": r.id, "title": r.title, "category": r.category, "user_id": r.user_id}
            for r in alerts
        }
        rank = db.scalar(select(MemberRanking.total_points).where(MemberRanking.user_id == 2))
        out["member_2_ranking_points"] = int(rank) if rank is not None else None
        return out
    finally:
        db.close()


def poll_xp_for_member(email: str, password: str) -> int | None:
    with httpx.Client(timeout=30.0) as c:
        r = c.post(f"{API_BASE}/auth/login", json={"email": email, "password": password})
        if r.status_code != 200:
            return None
        token = r.json().get("access_token") or r.json().get("token")
        evs = c.get(
            f"{API_BASE}/evaluations?mine=true",
            headers={"Authorization": f"Bearer {token}"},
        )
        if evs.status_code != 200:
            return None
        for row in evs.json():
            if int(row.get("media_id") or 0) in MEDIA_IDS:
                crit = row.get("criteria_json")
                if isinstance(crit, str):
                    crit = json.loads(crit)
                print(
                    f"media {row.get('media_id')}: xp_eligible={crit.get('xp_eligible')} "
                    f"xp_pending={crit.get('xp_pending')} review={row.get('review_status')}"
                )
        rank = c.get(f"{API_BASE}/rankings/me", headers={"Authorization": f"Bearer {token}"})
        if rank.status_code == 200:
            body = rank.json()
            return int(body.get("points") or body.get("total_points") or 0)
    return None


def main() -> None:
    snap1 = db_snapshot()
    print("=== DB snapshot (before extra polls) ===")
    print(json.dumps(snap1, indent=2, default=str))

    email = os.environ.get("SMOKE_MEMBER_EMAIL", "member@access.edu")
    password = os.environ.get("SMOKE_MEMBER_PASSWORD", "member123")
    with httpx.Client(timeout=30.0) as c:
        r = c.post(f"{API_BASE}/auth/login", json={"email": email, "password": password})
        token = r.json().get("access_token")
        headers = {"Authorization": f"Bearer {token}"}
        for mid in MEDIA_IDS:
            for i in range(5):
                c.get(f"{API_BASE}/media/{mid}", headers=headers)
                time.sleep(0.5)

    snap2 = db_snapshot()
    print("\n=== DB snapshot (after 5x poll each) ===")
    print(json.dumps(snap2, indent=2, default=str))

    pts = poll_xp_for_member(email, password)
    print(f"\nrankings/me points: {pts}")

    idempotent = snap1 == snap2
    print(f"\nidempotent_row_counts: {idempotent}")


if __name__ == "__main__":
    main()
