"""Read-only: practice uploads without evaluation rows (both postgres + waverep)."""
from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlparse, urlunparse

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv(Path(__file__).resolve().parents[1] / ".env")
base = os.getenv("DATABASE_URL")
if not base:
    raise SystemExit("DATABASE_URL missing")

u = urlparse(base)
SQL_STUCK = text(
    """
    SELECT mf.id, mf.uploaded_by, mf.file_name, mf.uploaded_at::text
    FROM media_files mf
    LEFT JOIN media_evaluations me ON me.media_id = mf.id
    WHERE mf.media_category = 'member_evaluation'
      AND me.id IS NULL
    ORDER BY mf.id DESC
    LIMIT 12
    """
)
SQL_COUNT = text(
    """
    SELECT COUNT(*)
    FROM media_files mf
    LEFT JOIN media_evaluations me ON me.media_id = mf.id
    WHERE mf.media_category = 'member_evaluation'
      AND me.id IS NULL
    """
)
SQL_RECENT = text(
    """
    SELECT mf.id, me.overall_score, me.evaluated_at::text,
           LENGTH(COALESCE(me.criteria_json, '')) AS crit_len
    FROM media_files mf
    JOIN media_evaluations me ON me.media_id = mf.id
    WHERE mf.media_category = 'member_evaluation'
    ORDER BY mf.id DESC
    LIMIT 8
    """
)

for dbname in ("postgres", "access_waverep_test"):
    eng = create_engine(urlunparse(u._replace(path=f"/{dbname}")))
    try:
        with eng.connect() as c:
            stuck = c.execute(SQL_COUNT).scalar()
            print(f"\n=== {dbname} === stuck_without_eval={stuck}")
            for row in c.execute(SQL_STUCK):
                print("  stuck", row)
            print(" recent_completed:")
            for row in c.execute(SQL_RECENT):
                print(" ", row)
    except Exception as exc:
        print(f"\n=== {dbname} === ERROR {exc}")
