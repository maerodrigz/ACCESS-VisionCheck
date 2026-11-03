"""
Set legacy daily practice evaluation cap from 5 to 3 on the system_settings row.

Only updates when the stored value is still the previous default (5).
Admins who chose a custom limit are left unchanged.

Usage:
  cd access_backend
  python migrate_max_evaluation_daily_limit_to_3.py
"""

from sqlalchemy import text

from app.database import engine


def main() -> None:
    with engine.begin() as conn:
        result = conn.execute(
            text(
                """
                UPDATE system_settings
                SET max_evaluation_uploads_per_day = 3
                WHERE id = 1 AND max_evaluation_uploads_per_day = 5
                """
            )
        )
        updated = result.rowcount
    print(f"max_evaluation_uploads_per_day: updated {updated} row(s) from 5 to 3.")


if __name__ == "__main__":
    main()
