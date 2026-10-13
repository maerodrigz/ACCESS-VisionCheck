"""
Update system_settings notification preference columns (safe to run multiple times).

Usage:
  cd access_backend
  python migrate_system_settings_notifications.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = [
    "notify_new_documentation_request",
    "notify_request_approved",
    "notify_request_completed",
    "notify_request_gallery_uploads",
    "notify_request_rejected",
    "notify_new_documentation_assignment",
    "notify_evaluation_completed",
    "notify_new_announcement",
    "notify_system_alerts",
]

OLD_COLUMNS = [
    "notify_new_documentation_requests",
    "notify_media_integrity_alerts",
    "notify_requester_feedback",
    "notify_facebook_publishing_status",
    "notify_system_notifications",
]

LEGACY_MAP = {
    "notify_new_documentation_request": "notify_new_documentation_requests",
    "notify_system_alerts": "notify_system_notifications",
}


def main() -> None:
    insp = inspect(engine)
    if "system_settings" not in insp.get_table_names():
        print("system_settings table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("system_settings")}

    with engine.begin() as conn:
        for col in NEW_COLUMNS:
            if col not in existing:
                conn.execute(
                    text(
                        f"ALTER TABLE system_settings ADD COLUMN {col} "
                        "BOOLEAN NOT NULL DEFAULT TRUE"
                    )
                )

        for new_col, old_col in LEGACY_MAP.items():
            if old_col in existing and new_col in {*NEW_COLUMNS, *existing}:
                conn.execute(
                    text(
                        f"UPDATE system_settings SET {new_col} = "
                        f"COALESCE({old_col}, TRUE) WHERE id = 1"
                    )
                )

        for old_col in OLD_COLUMNS:
            if old_col in existing:
                conn.execute(text(f"ALTER TABLE system_settings DROP COLUMN IF EXISTS {old_col}"))

    print("system_settings notification columns OK.")


if __name__ == "__main__":
    main()
