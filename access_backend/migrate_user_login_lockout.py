"""
Add login lockout tracking columns to users (safe to run multiple times).

Usage:
  cd access_backend
  python migrate_user_login_lockout.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = {
    "failed_login_count": "INTEGER NOT NULL DEFAULT 0",
    "locked_until": "TIMESTAMP WITH TIME ZONE",
}


def main() -> None:
    insp = inspect(engine)
    if "users" not in insp.get_table_names():
        print("users table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("users")}

    with engine.begin() as conn:
        for col, typedef in NEW_COLUMNS.items():
            if col not in existing:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {col} {typedef}"))

    print("users login lockout columns OK.")


if __name__ == "__main__":
    main()
