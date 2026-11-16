"""Manually invoked skill tier recalculation (writes users.skill_level_id only).

Default is dry-run. Apply requires explicit flags and environment confirmation.
Does NOT modify media evaluations, XP, AI results, or scoring code paths beyond
calling existing app.crud.user.recalculate_skill_level.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv

load_dotenv(_BACKEND / ".env")

from app.config import settings
from app.crud.user import get_by_id, recalculate_skill_level
from app.database import SessionLocal
from app.services.skill_level_recalc_batch import (
    audit_skill_eligibility,
    build_member_recalc_row,
    load_approved_members,
    print_summary,
    write_reports,
)

_CONFIRM_PHRASE = "I_UNDERSTAND_SKILL_RECALC_WRITE"
_PRODUCTION_DB_NAMES = frozenset({"postgres", "access", "access_production"})


def _refuse_production_unless_allowed(db_name: str) -> None:
    if db_name.lower() not in _PRODUCTION_DB_NAMES:
        return
    if os.environ.get("ALLOW_PRODUCTION_SKILL_RECALC", "").strip().upper() != "YES":
        raise SystemExit(
            f"Refusing apply on database {db_name!r}. "
            "Set ALLOW_PRODUCTION_SKILL_RECALC=YES only after backup and approval."
        )


def _validate_apply_guards(args: argparse.Namespace) -> None:
    if not args.apply:
        return
    if os.environ.get("SKILL_RECALC_CONFIRM", "").strip() != _CONFIRM_PHRASE:
        raise SystemExit(
            f"Apply mode requires environment variable SKILL_RECALC_CONFIRM={_CONFIRM_PHRASE}"
        )
    if args.confirm_db.strip().lower() != settings.db_name.strip().lower():
        raise SystemExit(
            f"--confirm-db must match active DB_NAME ({settings.db_name!r}); "
            f"got {args.confirm_db!r}"
        )
    if args.require_backup:
        manifest = Path(args.require_backup)
        if not manifest.is_file():
            raise SystemExit(f"Backup manifest not found: {manifest}")
    _refuse_production_unless_allowed(settings.db_name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Skill tier batch recalculation (dry-run by default).")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Persist recalculated tiers via recalculate_skill_level (requires confirmation).",
    )
    parser.add_argument(
        "--confirm-db",
        default="",
        help="Must equal DB_NAME when using --apply.",
    )
    parser.add_argument(
        "--require-backup",
        default="",
        help="Path to backup manifest.json from skill_level_recalc_backup.py (recommended).",
    )
    parser.add_argument("--user-id", type=int, default=None, help="Limit to one member.")
    parser.add_argument(
        "--skip-unchanged",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Skip users whose stored tier already matches effective tier (default: true).",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        pre_members = load_approved_members(db)
        if args.user_id is not None:
            pre_members = [u for u in pre_members if u.id == args.user_id]

        pre_rows = [build_member_recalc_row(db, u) for u in pre_members]
        pre_audit = audit_skill_eligibility(db, user_id=args.user_id)
        if pre_audit.leak_count:
            print("ERROR: eligibility audit leaks detected; aborting.")
            return 2

        pre_paths = write_reports(
            db_name=settings.db_name,
            members=pre_rows,
            audit=pre_audit,
            label="pre_apply" if args.apply else "dry_run",
        )
        print("=== Pre-run report ===")
        print_summary(pre_paths["summary"])

        if not args.apply:
            print("Dry-run only (no writes). Re-run with --apply after backup and approval.")
            return 0

        _validate_apply_guards(args)

        updated = 0
        skipped = 0
        errors: list[str] = []

        for user in pre_members:
            row = build_member_recalc_row(db, user)
            if args.skip_unchanged and not row.would_persist_change:
                skipped += 1
                continue
            try:
                fresh = get_by_id(db, user.id)
                if not fresh:
                    errors.append(f"user {user.id}: not found")
                    continue
                recalculate_skill_level(db, fresh)
                updated += 1
            except Exception as exc:  # noqa: BLE001 — batch job logs and continues
                errors.append(f"user {user.id}: {exc}")

        db.expire_all()
        post_members = load_approved_members(db)
        if args.user_id is not None:
            post_members = [u for u in post_members if u.id == args.user_id]
        post_rows = [build_member_recalc_row(db, u) for u in post_members]
        post_audit = audit_skill_eligibility(db, user_id=args.user_id)
        post_paths = write_reports(
            db_name=settings.db_name,
            members=post_rows,
            audit=post_audit,
            label="post_apply_verify",
        )

        remaining = sum(1 for r in post_rows if r.would_persist_change)
        print("=== Apply complete ===")
        print(f"updated={updated} skipped={skipped} errors={len(errors)}")
        print(f"remaining_mismatch={remaining}")
        print("=== Post-run verification ===")
        print_summary(post_paths["summary"])
        if errors:
            for line in errors[:20]:
                print(f"ERROR: {line}")
            return 3
        if remaining:
            print("WARNING: some stored tiers still differ from effective tier after apply.")
            return 4
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
