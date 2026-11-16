"""Read-only inspect stuck member_evaluation media on postgres."""
from __future__ import annotations

import os
import sys
from pathlib import Path
from urllib.parse import urlparse, urlunparse

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv(Path(__file__).resolve().parents[1] / ".env")
base = os.getenv("DATABASE_URL")
u = urlparse(base)
eng = create_engine(urlunparse(u._replace(path="/postgres")))

ids = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else [279, 280, 281]
with eng.connect() as c:
    for mid in ids:
        row = c.execute(
            text(
                """
                SELECT id, uploaded_by, file_name, file_type, file_url,
                       LEFT(COALESCE(file_hash, ''), 12) AS hash_prefix,
                       uploaded_at::text
                FROM media_files WHERE id = :id
                """
            ),
            {"id": mid},
        ).first()
        print("\nmedia", row)
        ai = c.execute(
            text("SELECT id, review_status, detection_result FROM ai_detection_results WHERE media_id = :id"),
            {"id": mid},
        ).fetchall()
        print(" ai_rows", ai)
