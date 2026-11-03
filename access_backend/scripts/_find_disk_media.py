from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parents[1] / ".env.waverep_test", override=True)
import os
from sqlalchemy import create_engine, text
from app.services.media_file_bytes import local_media_path

e = create_engine(os.environ["DATABASE_URL"])
with e.connect() as c:
    rows = c.execute(
        text(
            "SELECT id, file_url FROM media_files "
            "WHERE file_url LIKE '/uploads/%' ORDER BY id DESC LIMIT 20"
        )
    ).fetchall()
    for mid, url in rows:
        p = local_media_path(url)
        ok = p.is_file() if p else False
        print(mid, url, ok, p)
