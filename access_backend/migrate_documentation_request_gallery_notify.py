"""
Add gallery upload notification state columns on documentation_requests.

Usage:
  cd access_backend
  python migrate_documentation_request_gallery_notify.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = (
    ("gallery_first_upload_notified", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("gallery_upload_notify_pending", "INTEGER NOT NULL DEFAULT 0"),
    ("gallery_upload_last_notify_at", "TIMESTAMP WITH TIME ZONE"),
)


def main() -> None:
    insp = inspect(engine)
    if "documentation_requests" not in insp.get_table_names():
        print("documentation_requests table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("documentation_requests")}

    with engine.begin() as conn:
        for name, ddl in NEW_COLUMNS:
            if name not in existing:
                conn.execute(
                    text(f"ALTER TABLE documentation_requests ADD COLUMN {name} {ddl}")
                )

    print("documentation_requests gallery notify columns OK.")


if __name__ == "__main__":
    main()
