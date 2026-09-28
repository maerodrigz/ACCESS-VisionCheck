"""
Add security configuration columns to system_settings (safe to run multiple times).

Usage:
  cd access_backend
  python migrate_system_settings_security.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = {
    "max_login_attempts": "INTEGER NOT NULL DEFAULT 5",
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

    print("system_settings security columns OK.")


if __name__ == "__main__":
    main()
