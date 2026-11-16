"""
Draft cohort capture for Skill Progression v2 (earned v1 floors + cohort rows).

Default: dry-run only (no writes).
Does not seal activation or flip SKILL_PROGRESSION_ACTIVE_POLICY.

Usage:
  cd access_backend
  python scripts/skill_progression_cohort_capture.py
  python scripts/skill_progression_cohort_capture.py --apply --confirm-write-cohort
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from app.database import SessionLocal
from app.services.skill_progression_v2_activation import (
    SkillV2ActivationError,
    apply_cohort_capture,
    assert_write_guards_for_operator_apply,
    plan_cohort_capture,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture draft grandfather cohort (v1 floors).")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--confirm-write-cohort",
        action="store_true",
        help="Required with --apply to acknowledge ranking floor + cohort writes.",
    )
    parser.add_argument(
        "--allow-shared-dev",
        action="store_true",
        help="Explicit override for DB_NAME=postgres (still requires policy v1).",
    )
    parser.add_argument("--notes", default=None)
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.apply:
            if not args.confirm_write_cohort:
                print(
                    "SAFETY STOP: --apply requires --confirm-write-cohort",
                    file=sys.stderr,
                )
                return 1
            assert_write_guards_for_operator_apply(allow_shared_dev=args.allow_shared_dev)
            plan = apply_cohort_capture(db, notes=args.notes)
            db.commit()
        else:
            plan = plan_cohort_capture(db)

        print(f"mode={plan.mode} activation_id={plan.activation_id}")
        print(
            f"candidates={len(plan.candidates)} would_write_floors={plan.would_write_floors} "
            f"would_add_cohort_rows={plan.would_add_cohort_rows} "
            f"skipped_matching={plan.skipped_existing_matching}"
        )
        for c in plan.candidates:
            print(
                f"  user_id={c.user_id} name={c.fullname!r} "
                f"computed_v1={c.computed_tier_v1} existing_floor={c.existing_floor!r} "
                f"override={c.admin_override!r} in_draft={c.already_in_draft}"
            )
        if not args.apply:
            print("dry-run only; pass --apply --confirm-write-cohort to write.")
        return 0
    except SkillV2ActivationError as exc:
        db.rollback()
        print(f"SAFETY STOP: {exc}", file=sys.stderr)
        return 1
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
