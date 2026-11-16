"""Read-only report: legacy admin integrity alerts with misleading AI-generated wording.

Does NOT delete, update, or rewrite notification rows.
Run against a chosen database (default uses app settings DATABASE_URL):

  cd access_backend
  python scripts/audit_legacy_ai_detection_alerts.py

Optional: ACCESS_PYTEST_DB=access_waverep_test for isolated DB (same as other scripts).
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select

from app.database import SessionLocal
from app.models.notification import Notification


def main() -> int:
    db = SessionLocal()
    try:
        rows = list(
            db.scalars(
                select(Notification)
                .where(
                    Notification.category == "ai_detection",
                    Notification.action_type == "review_media",
                )
                .order_by(Notification.created_at.desc())
                .limit(2000)
            )
        )
        legacy = []
        for n in rows:
            title = (n.title or "").strip().lower()
            msg = (n.message or "").lower()
            if title == "ai detection alert" or "ai-generated content detected" in msg:
                legacy.append(n)

        print(f"integrity_review_alerts_scanned={len(rows)}")
        print(f"legacy_misleading_ai_copy={len(legacy)}")
        print("id\tuser_id\tis_read\tmedia_id\tcreated_at\ttitle")
        for n in legacy[:200]:
            print(
                f"{n.id}\t{n.user_id}\t{n.is_read}\t{n.action_ref_id}\t"
                f"{n.created_at.isoformat() if n.created_at else ''}\t{n.title}"
            )
        if len(legacy) > 200:
            print(f"... truncated, {len(legacy) - 200} more")
        print("NOTE: read-only. No cleanup migration executed.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
