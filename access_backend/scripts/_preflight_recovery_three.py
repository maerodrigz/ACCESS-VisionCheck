"""Read-only preflight for recovery of media IDs 279, 280, 281 on postgres."""
from __future__ import annotations

import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from app.config import settings

TARGET = (279, 280, 281)


def main() -> None:
    url = make_url(settings.database_url)
    if url.database != "postgres":
        url = url.set(database="postgres")
    eng = create_engine(url)
    with eng.connect() as c:
        db = c.execute(text("SELECT current_database()")).scalar()
        print("database", db)
        for mid in TARGET:
            m = c.execute(
                text(
                    """
                    SELECT mf.id, mf.uploaded_by, mf.file_name, mf.file_url,
                           me.id AS eval_id
                    FROM media_files mf
                    LEFT JOIN media_evaluations me ON me.media_id = mf.id
                    WHERE mf.id = :id AND mf.media_category = 'member_evaluation'
                    """
                ),
                {"id": mid},
            ).first()
            print("media", m)
        from app.services.supabase_storage import read_supabase_ref_bytes

        for mid in TARGET:
            url = c.execute(
                text("SELECT file_url FROM media_files WHERE id = :id"),
                {"id": mid},
            ).scalar()
            if not url or not str(url).startswith("supabase-ref:"):
                print(f"read_{mid}", "skip_not_supabase_ref")
                continue
            b = read_supabase_ref_bytes(str(url), timeout=60.0)
            print(f"read_{mid}_bytes", len(b) if b else None)


if __name__ == "__main__":
    main()
