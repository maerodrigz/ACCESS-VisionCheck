"""Read-only schema inspection for facilitator reports. Do not mutate DB."""
from __future__ import annotations

import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from sqlalchemy import create_engine, inspect, text

from app.config import settings
from app.database import Base
import app.models  # noqa: F401 — register metadata


def _mask_url(url: str) -> str:
    return re.sub(r":([^:@/]+)@", ":****@", url)


def main() -> None:
    url = settings.database_url
    print(f"DATABASE_URL (masked): {_mask_url(url)}")
    print(f"API_PORT (settings): {settings.api_port}")

    engine = create_engine(url)
    insp = inspect(engine)

    with engine.connect() as conn:
        db_name = conn.execute(text("SELECT current_database()")).scalar()
        print(f"current_database(): {db_name}")

    table = "media_files"
    if not insp.has_table(table):
        print(f"ERROR: table {table} missing")
        return

    db_cols = {c["name"]: c for c in insp.get_columns(table)}
    print(f"\n{table}: {len(db_cols)} columns in DB")
    print(f"  file_hash present: {'file_hash' in db_cols}")

    model = Base.metadata.tables[table]
    model_cols = {c.name: c for c in model.columns}
    missing = sorted(set(model_cols) - set(db_cols))
    extra = sorted(set(db_cols) - set(model_cols))
    if missing:
        print(f"\nMissing vs SQLAlchemy model ({len(missing)}):")
        for name in missing:
            col = model_cols[name]
            print(f"  - {name}: {col.type} nullable={col.nullable}")
    if extra:
        print(f"\nExtra in DB only ({len(extra)}): {', '.join(extra)}")

    indexes = insp.get_indexes(table)
    index_names = {i["name"] for i in indexes}
    print(f"\nIndexes on {table}: {sorted(index_names)}")
    for want in ("ix_media_files_file_hash", "uq_media_files_member_eval_file_hash"):
        print(f"  {want}: {'yes' if want in index_names else 'NO'}")

    # Quick row counts (read-only)
    with engine.connect() as conn:
        n = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
        print(f"\nRow count {table}: {n}")


if __name__ == "__main__":
    main()
