#!/usr/bin/env python
"""
Reset ACCESS to a clean operational state (keep admin + real registered accounts).

Usage (from access_backend/):
  python scripts/reset_operational_data.py --dry-run
  set RESET_ACCESS_DATA=YES
  python scripts/reset_operational_data.py --confirm

Optional:
  set KEEP_USER_EMAILS=you@school.edu,other@school.edu
  python scripts/reset_operational_data.py --confirm --keep-demo-users
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
from app.services.reset_operational_data import build_reset_plan, reset_operational_data


def main() -> None:
    parser = argparse.ArgumentParser(description="Reset media, requests, notifications; keep legit users.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be removed (default if --confirm not set)",
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Actually delete data (requires RESET_ACCESS_DATA=YES in environment)",
    )
    parser.add_argument(
        "--keep-demo-users",
        action="store_true",
        help="Keep all accounts; only clear requests/media (no demo account removal)",
    )
    parser.add_argument(
        "--skip-upload-dir",
        action="store_true",
        help="Leave files in uploads/images and uploads/videos on disk",
    )
    args = parser.parse_args()

    dry_run = not args.confirm or args.dry_run
    if args.confirm and not dry_run:
        if os.environ.get("RESET_ACCESS_DATA", "").strip().upper() != "YES":
            print("Refusing to run: set RESET_ACCESS_DATA=YES in the environment to confirm.")
            print("Example (PowerShell):")
            print('  $env:RESET_ACCESS_DATA="YES"; python scripts/reset_operational_data.py --confirm')
            sys.exit(1)

    db = SessionLocal()
    try:
        if dry_run:
            plan = build_reset_plan(db, remove_demo_users=not args.keep_demo_users)
            print("DRY RUN — no changes made.\n")
        else:
            print("Resetting operational data...\n")
            plan = reset_operational_data(
                db,
                dry_run=False,
                remove_demo_users=not args.keep_demo_users,
                clear_upload_dir=not args.skip_upload_dir,
            )
            print("Done.\n")

        print("Current row counts (before reset when dry-run):")
        for key, value in sorted(plan.counts.items()):
            print(f"  {key}: {value}")

        print(f"\nLocal upload files to remove: {plan.upload_files_removed}")

        print(f"\nAccounts to keep ({len(plan.users_to_keep)}):")
        for line in plan.users_to_keep:
            print(f"  + {line}")

        if plan.users_to_delete:
            print(f"\nDemo accounts to remove ({len(plan.users_to_delete)}):")
            for line in plan.users_to_delete:
                print(f"  - {line}")
        else:
            print("\nNo demo accounts scheduled for removal.")

        if dry_run:
            print("\nTo apply, run:")
            print('  $env:RESET_ACCESS_DATA="YES"; python scripts/reset_operational_data.py --confirm')
    finally:
        db.close()


if __name__ == "__main__":
    main()
