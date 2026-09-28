"""
Add AI media evaluation columns to system_settings (safe to run multiple times).

Usage:
  cd access_backend
  python migrate_system_settings_ai_evaluation.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = {
    "enable_ai_media_evaluation": "BOOLEAN NOT NULL DEFAULT TRUE",
    "max_evaluation_uploads_per_day": "INTEGER NOT NULL DEFAULT 5",
}


def main() -> None:
    insp = inspect(engine)
    if "system_settings" not in insp.get_table_names():
        print("system_settings table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("system_settings")}

    with engine.begin() as conn:
        for col, typedef in NEW_COLUMNS.items():
            if col not in existing:
                conn.execute(text(f"ALTER TABLE system_settings ADD COLUMN {col} {typedef}"))

    print("system_settings AI evaluation columns OK.")


if __name__ == "__main__":
    main()
