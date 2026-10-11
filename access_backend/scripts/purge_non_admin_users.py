#!/usr/bin/env python
"""
Remove all member and organization accounts; keep Admin (+ optional KEEP_USER_EMAILS).

  python scripts/purge_non_admin_users.py --dry-run
  $env:RESET_ACCESS_DATA="YES"; python scripts/purge_non_admin_users.py --confirm
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from app.database import SessionLocal
from app.services.reset_operational_data import build_non_admin_purge_plan, purge_non_admin_users


def main() -> None:
    parser = argparse.ArgumentParser(description="Delete non-Admin user accounts.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--confirm", action="store_true")
    args = parser.parse_args()

    dry_run = not args.confirm or args.dry_run
    if args.confirm and not dry_run:
        if os.environ.get("RESET_ACCESS_DATA", "").strip().upper() != "YES":
            print("Set RESET_ACCESS_DATA=YES to confirm.")
            sys.exit(1)

    db = SessionLocal()
    try:
        if dry_run:
            plan = build_non_admin_purge_plan(db)
            print("DRY RUN — no accounts deleted.\n")
        else:
            print("Removing non-Admin accounts...\n")
            plan = purge_non_admin_users(db, dry_run=False)
            print("Done.\n")

        print(f"Users remaining after purge: {plan.counts.get('users', '?')}")
        print(f"\nKeep ({len(plan.users_to_keep)}):")
        for line in plan.users_to_keep:
            print(f"  + {line}")
        if plan.users_to_delete:
            print(f"\nRemove ({len(plan.users_to_delete)}):")
            for line in plan.users_to_delete:
                print(f"  - {line}")
        if dry_run and plan.users_to_delete:
            print('\nTo apply: $env:RESET_ACCESS_DATA="YES"; python scripts/purge_non_admin_users.py --confirm')
    finally:
        db.close()


if __name__ == "__main__":
    main()
