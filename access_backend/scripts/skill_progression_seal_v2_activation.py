"""
Seal Skill Progression v2 activation after draft cohort capture.

Default: dry-run only.
Does not change SKILL_PROGRESSION_ACTIVE_POLICY (ops sets env separately after seal).

Rollback guidance:
  - Prefer set SKILL_PROGRESSION_ACTIVE_POLICY=v1 and restart API.
  - Optional: revoke seal via service helper (keeps floors/cohort for audit).

Usage:
  cd access_backend
  python scripts/skill_progression_seal_v2_activation.py
  python scripts/skill_progression_seal_v2_activation.py --apply --confirm-seal
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
    apply_seal,
    assert_write_guards_for_operator_apply,
    plan_seal,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Seal v2 activation after cohort capture.")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--confirm-seal",
        action="store_true",
        help="Required with --apply to acknowledge sealing the protected cohort.",
    )
    parser.add_argument("--allow-shared-dev", action="store_true")
    parser.add_argument("--notes", default=None)
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.apply:
            if not args.confirm_seal:
                print("SAFETY STOP: --apply requires --confirm-seal", file=sys.stderr)
                return 1
            assert_write_guards_for_operator_apply(allow_shared_dev=args.allow_shared_dev)
            plan = apply_seal(db, notes=args.notes)
            db.commit()
        else:
            plan = plan_seal(db)

        print(f"mode={plan.mode} activation_id={plan.activation_id} ready={plan.ready}")
        print(f"cohort_user_ids={list(plan.cohort_user_ids)}")
        print(f"approved_user_ids={list(plan.approved_user_ids)}")
        if plan.blocked_reason:
            print(f"blocked_reason={plan.blocked_reason}")
        if plan.missing_floors:
            print(f"missing_floors={list(plan.missing_floors)}")
        if plan.approved_not_in_cohort:
            print(f"approved_not_in_cohort={list(plan.approved_not_in_cohort)}")
        if not args.apply:
            print("dry-run only; pass --apply --confirm-seal to seal.")
            print(
                "After seal: set SKILL_PROGRESSION_ACTIVE_POLICY=v2 and restart API. "
                "Rollback: set policy v1 (and optionally revoke seal)."
            )
        return 0 if plan.ready or not args.apply else 1
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
