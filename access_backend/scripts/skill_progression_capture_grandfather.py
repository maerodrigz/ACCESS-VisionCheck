"""
Capture v1 computed skill tiers into member_rankings grandfather floor (pre-v2 activation).

Default: dry-run only (no writes). Pass --apply to persist snapshots.

Staging --apply requires ACCESS_ENV_FILE -> .env.skillprogression_staging and passes
fail-closed guards (see app.services.skill_progression_capture_guard).

Usage:
  cd access_backend
  $env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
  python scripts/skill_progression_capture_grandfather.py
  python scripts/skill_progression_capture_grandfather.py --apply
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from sqlalchemy import select, text
from sqlalchemy.orm import Session, joinedload

from app.config import settings
from app.database import SessionLocal
from app.models.enums import RoleName, UserStatus
from app.models.role import Role
from app.models.user import User
from app.services.skill_progression import build_skill_progression_snapshot
from app.services.skill_progression_capture_guard import (
    CaptureApplySafetyError,
    assert_capture_apply_safe,
)
from app.services.skill_progression_policy import POLICY_V1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Capture grandfather skill tier snapshots (v1 computed tier only)."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write snapshots to member_rankings (default: dry-run report only).",
    )
    args = parser.parse_args()

    db: Session = SessionLocal()
    try:
        if args.apply:
            assert_capture_apply_safe(db)

        live = db.execute(
            text("SELECT current_database() AS db, current_user AS role")
        ).mappings().one()
        print(f"connected database={live['db']} user={live['role']}")

        members = db.scalars(
            select(User)
            .options(joinedload(User.skill_level), joinedload(User.member_ranking))
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
            .order_by(User.id)
        ).unique().all()

        missing_ranking = 0
        skipped_override = 0
        skipped_existing = 0
        would_write = 0
        for user in members:
            ranking = user.member_ranking
            if ranking is None:
                missing_ranking += 1
                print(f"user_id={user.id} skip=no_ranking_row")
                continue
            if ranking.skill_tier_grandfather_floor:
                skipped_existing += 1
                continue
            snap = build_skill_progression_snapshot(db, user.id)
            tier = snap.computed_tier_v1
            override_note = ""
            if ranking.competency_level_override:
                skipped_override += 1
                override_note = (
                    f" admin_override={ranking.competency_level_override!r}"
                    f" effective={snap.effective_tier!r}"
                )
            print(
                f"user_id={user.id} computed_v1={tier} -> floor={tier}{override_note}"
            )
            would_write += 1
            if args.apply:
                ranking.skill_tier_grandfather_floor = tier
                ranking.skill_tier_grandfather_captured_at = datetime.now(timezone.utc)
                ranking.skill_tier_grandfather_from_policy = POLICY_V1

        if args.apply and would_write:
            assert_capture_apply_safe(db)
            try:
                db.commit()
            except Exception:
                db.rollback()
                raise
        elif args.apply and not would_write:
            print("apply: no rows to write (already captured).")
        print(f"database={settings.db_name} members={len(members)} would_capture={would_write}")
        print(
            f"skipped_existing={skipped_existing} members_with_admin_override={skipped_override} "
            f"mode={'apply' if args.apply else 'dry_run'}"
        )
        if missing_ranking:
            print(f"warning: members_without_ranking_row={missing_ranking}")
        return 0
    except CaptureApplySafetyError as exc:
        db.rollback()
        print(f"SAFETY STOP: {exc}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
