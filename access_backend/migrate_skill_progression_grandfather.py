"""
Add grandfather snapshot columns to member_rankings (safe to run multiple times).

Does NOT capture snapshots or activate policy v2.

Usage:
  cd access_backend
  python migrate_skill_progression_grandfather.py
"""

from sqlalchemy import inspect, text

from app.database import engine

NEW_COLUMNS = {
    "skill_tier_grandfather_floor": "TEXT",
    "skill_tier_grandfather_captured_at": "TIMESTAMP WITH TIME ZONE",
    "skill_tier_grandfather_from_policy": "TEXT",
}


def main() -> None:
    insp = inspect(engine)
    if "member_rankings" not in insp.get_table_names():
        print("member_rankings table not found — run create_tables.py first.")
        return

    existing = {c["name"] for c in insp.get_columns("member_rankings")}

    with engine.begin() as conn:
        for col, typedef in NEW_COLUMNS.items():
            if col not in existing:
                conn.execute(text(f"ALTER TABLE member_rankings ADD COLUMN {col} {typedef}"))

    print("member_rankings skill progression grandfather columns OK.")


if __name__ == "__main__":
    main()
