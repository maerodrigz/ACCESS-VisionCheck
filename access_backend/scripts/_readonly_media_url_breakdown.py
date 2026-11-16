"""Read-only: classify media_files.file_url patterns."""

from __future__ import annotations

import sys
from pathlib import Path

from sqlalchemy import create_engine, text

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()
from app.config import settings  # noqa: E402

engine = create_engine(settings.database_url)
with engine.connect() as c:
    print("--- http_url rows ---")
    for row in c.execute(
        text(
            "SELECT id, uploaded_by, media_category, LEFT(file_url, 100) "
            "FROM media_files WHERE file_url LIKE 'http%'"
        )
    ):
        print(row)
    print("--- orphan ---")
    for row in c.execute(
        text(
            "SELECT id, file_name, media_category, LEFT(file_url, 100) "
            "FROM media_files WHERE uploaded_by IS NULL"
        )
    ):
        print(row)
    print("--- supabase-ref paths (non-admin) ---")
    for row in c.execute(
        text(
            """
            SELECT mf.id, mf.uploaded_by, mf.file_url
            FROM media_files mf
            JOIN users u ON u.id = mf.uploaded_by
            JOIN roles r ON r.id = u.role_id
            WHERE r.role_name != 'Admin' AND mf.file_url LIKE 'supabase-ref:%'
            ORDER BY mf.id
            """
        )
    ):
        print(row[0], row[1], row[2][:90])
