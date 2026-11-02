"""Requeue deferred pipeline for practice media that has no evaluation row.

READ-ONLY by default. Set REQUEUE_CONFIRM=yes to schedule jobs.

Target explicit IDs (required for production recovery):
  REQUEUE_MEDIA_IDS=279,280,281

Optional:
  REQUEUE_DATABASE=postgres
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv
from sqlalchemy import bindparam, create_engine, text
from sqlalchemy.engine import make_url

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from app.config import settings

SQL_BY_IDS = text(
    """
    SELECT mf.id, mf.uploaded_by, mf.file_name, mf.uploaded_at::text,
           me.id AS eval_id
    FROM media_files mf
    LEFT JOIN media_evaluations me ON me.media_id = mf.id
    WHERE mf.media_category = 'member_evaluation'
      AND mf.id IN :ids
    ORDER BY mf.id
    """
).bindparams(bindparam("ids", expanding=True))


def main() -> None:
    dbname = os.getenv("REQUEUE_DATABASE", "postgres")
    ids_raw = (os.getenv("REQUEUE_MEDIA_IDS") or "").strip()
    if not ids_raw:
        raise SystemExit("REQUEUE_MEDIA_IDS is required (e.g. 279,280,281). Refusing broad requeue.")
    media_ids = [int(x.strip()) for x in ids_raw.split(",") if x.strip()]
    if not media_ids:
        raise SystemExit("REQUEUE_MEDIA_IDS parsed empty.")

    url = make_url(settings.database_url)
    if url.database != dbname:
        url = url.set(database=dbname)
    eng = create_engine(url)
    with eng.connect() as c:
        rows = c.execute(SQL_BY_IDS, {"ids": media_ids}).fetchall()
    found_ids = {int(r[0]) for r in rows}
    missing = [mid for mid in media_ids if mid not in found_ids]
    if missing:
        raise SystemExit(f"Media not found in {dbname}: {missing}")
    if len(rows) != len(media_ids):
        raise SystemExit(f"Expected {len(media_ids)} rows, got {len(rows)}.")

    print(f"database={dbname} target_ids={media_ids}")
    for row in rows:
        eval_id = row[4]
        status = "stuck_no_eval" if eval_id is None else f"HAS_EVAL_{eval_id}"
        print(f"  media_id={row[0]} member={row[1]} file={row[2]} uploaded={row[3]} status={status}")

    already = [int(r[0]) for r in rows if r[4] is not None]
    if already:
        raise SystemExit(f"Refusing requeue: evaluation already exists for media_ids={already}")

    if os.getenv("REQUEUE_CONFIRM", "").strip().lower() not in ("1", "true", "yes"):
        print("Dry run only. Set REQUEUE_CONFIRM=yes to schedule deferred pipeline jobs.")
        return

    from app.services.deferred_media_pipeline import run_deferred_media_pipeline_job

    for mid in media_ids:
        print(f"running pipeline media_id={mid} ...")
        run_deferred_media_pipeline_job(mid, evaluation_metadata=None)
        print(f"finished pipeline media_id={mid}")


if __name__ == "__main__":
    main()
