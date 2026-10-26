"""Compare all SQLAlchemy columns to live PostgreSQL (read-only)."""
from __future__ import annotations

import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from sqlalchemy import create_engine, inspect

from app.config import settings
from app.database import Base
import app.models  # noqa: F401


def pg_type(col) -> str:
    t = str(col.type)
    return t.upper()


def main() -> None:
    engine = create_engine(settings.database_url)
    insp = inspect(engine)
    any_missing = False
    for table_name, table in sorted(Base.metadata.tables.items()):
        if not insp.has_table(table_name):
            print(f"MISSING TABLE: {table_name}")
            any_missing = True
            continue
        db_cols = {c["name"] for c in insp.get_columns(table_name)}
        for col in table.columns:
            if col.name not in db_cols:
                any_missing = True
                print(
                    f"MISSING COLUMN: {table_name}.{col.name} "
                    f"({pg_type(col)} nullable={col.nullable})"
                )
    if not any_missing:
        print("All model columns present in PostgreSQL (public schema).")


if __name__ == "__main__":
    main()
