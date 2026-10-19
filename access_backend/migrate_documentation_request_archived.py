"""
Add archived_at on documentation_requests for admin archive workflow.

Usage:
  cd access_backend
  python migrate_documentation_request_archived.py
"""

from sqlalchemy import inspect, text

from app.database import engine


def main() -> None:
    insp = inspect(engine)
    if "documentation_requests" not in insp.get_table_names():
        print("documentation_requests table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("documentation_requests")}

    with engine.begin() as conn:
        if "archived_at" not in existing:
            conn.execute(
                text(
                    "ALTER TABLE documentation_requests "
                    "ADD COLUMN archived_at TIMESTAMP WITH TIME ZONE"
                )
            )
            conn.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_documentation_requests_archived_at "
                    "ON documentation_requests (archived_at)"
                )
            )

    print("documentation_requests archived_at column OK.")


if __name__ == "__main__":
    main()
