"""Read-only dry-run: stored vs quality-based computed skill tiers (no writes).

Usage (from access_backend):
  python scripts/skill_level_recalc_dry_run.py
  python scripts/skill_level_recalc_dry_run.py --user-id 77
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv

load_dotenv(_BACKEND / ".env")

from app.config import settings
from app.database import SessionLocal
from app.services.skill_level_recalc_batch import (
    audit_skill_eligibility,
    build_member_recalc_row,
    load_approved_members,
    print_summary,
    write_reports,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Skill tier batch recalculation dry-run (read-only).")
    parser.add_argument("--user-id", type=int, default=None, help="Limit report to one member id.")
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=None,
        help="Override output directory (default: backups/skill_recalc/dry_run_<ts>).",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        members = load_approved_members(db)
        if args.user_id is not None:
            members = [u for u in members if u.id == args.user_id]
            if not members:
                print(f"No approved member with user_id={args.user_id}")
                return 1

        rows = [build_member_recalc_row(db, u) for u in members]
        audit = audit_skill_eligibility(db, user_id=args.user_id)

        paths = write_reports(
            db_name=settings.db_name,
            members=rows,
            audit=audit,
            report_dir=args.report_dir,
            label="dry_run",
        )
        print_summary(paths["summary"])
        if audit.leak_count:
            print("WARNING: eligibility audit reported leaks; do not run apply until resolved.")
            return 2
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
