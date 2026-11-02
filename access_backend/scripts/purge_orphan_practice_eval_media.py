"""Remove practice evaluation media with no uploader (orphaned after member delete).

Usage (original DB only — checks DB_NAME):
  cd access_backend
  python scripts/purge_orphan_practice_eval_media.py --dry-run
  python scripts/purge_orphan_practice_eval_media.py --apply
"""

from __future__ import annotations

import argparse
import sys

from sqlalchemy import func, select

from app.config import settings
from app.crud import media as media_crud
from app.database import SessionLocal
from app.models.ai_detection_result import AiDetectionResult
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile


def main() -> int:
    parser = argparse.ArgumentParser(description="Purge orphan practice evaluation media rows.")
    parser.add_argument("--apply", action="store_true", help="Delete rows (default is dry-run).")
    parser.add_argument("--dry-run", action="store_true", help="List counts only.")
    args = parser.parse_args()
    apply = args.apply and not args.dry_run

    db_name = (settings.db_name or "").strip()
    print(f"database={db_name}")
    if db_name.lower() in ("access_waverep_test", "access_uat"):
        print("Refusing to run on QA/UAT database.", file=sys.stderr)
        return 2

    with SessionLocal() as db:
        orphan_ids = list(
            db.scalars(
                select(MediaFile.id).where(
                    MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
                    MediaFile.uploaded_by.is_(None),
                )
            )
        )
        pending = db.scalar(
            select(func.count())
            .select_from(AiDetectionResult)
            .join(MediaFile, AiDetectionResult.media_id == MediaFile.id)
            .where(
                MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
                MediaFile.uploaded_by.is_(None),
                AiDetectionResult.review_status.in_(("pending_review", "needs_further_review")),
            )
        )
        print(f"orphan_practice_eval_media={len(orphan_ids)}")
        print(f"orphan_pending_integrity={int(pending or 0)}")
        if not apply:
            print("Dry run — pass --apply to delete.")
            return 0
        deleted, failed = media_crud.delete_orphan_practice_evaluations(db)
        print(f"deleted={deleted} failed={failed}")
        return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
