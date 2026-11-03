"""
Shared-development grandfather capture (maintenance CLI only).

Default: dry-run. --apply requires GRANDFATHER_SHARED_DEV_APPLY_APPROVED=1 and --manifest.

Does not use staging capture guards. Does not modify staging.

Usage:
  cd access_backend
  Remove-Item Env:ACCESS_ENV_FILE -ErrorAction SilentlyContinue
  python scripts/skill_progression_capture_shared_dev.py --manifest ..\\path\\manifest.json
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

from app.config import settings
from app.database import SessionLocal
from app.services.skill_progression_capture_guard_shared_dev import (
    SharedDevCaptureSafetyError,
    assert_operator_apply_approved,
)
from app.services.skill_progression_capture_manifest import SharedDevCaptureManifest
from app.services.skill_progression_grandfather_capture_shared_dev import (
    apply_shared_dev_grandfather_capture,
    plan_shared_dev_capture,
    verify_post_commit,
)


def _print_plan(plan, target_state: dict | None = None) -> None:
    print(f"mode={plan.mode}")
    print(f"target_database={settings.db_name}")
    print(f"active_policy={settings.skill_progression_active_policy}")
    print(f"api_port={settings.api_port}")
    print(f"target_user_id={plan.target_user_id}")
    print(f"target_ranking_id={plan.target_ranking_id}")
    print(f"computed_tier_v1={plan.computed_tier_v1}")
    print(f"grandfather_floor_before={plan.floor_before!r}")
    print(f"grandfather_floor_after={plan.floor_after!r}")
    print(f"grandfather_from_policy={plan.policy_label}")
    if target_state:
        print(f"eligible_evaluations={target_state.get('eligible_evaluation_count')}")
        print(f"users_skill_level_id={target_state.get('users_skill_level_id')}")
        print(f"total_points={target_state.get('total_points')}")


def main() -> int:
    import os

    if "ACCESS_ENV_FILE" in os.environ and Path(os.environ["ACCESS_ENV_FILE"]).name == (
        ".env.skillprogression_staging"
    ):
        print(
            "SAFETY STOP: Unset ACCESS_ENV_FILE before shared-dev capture.",
            file=sys.stderr,
        )
        return 1

    parser = argparse.ArgumentParser(
        description="Shared-dev grandfather capture (separate from staging CLI)."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        required=True,
        help="Operator manifest JSON (shared_development_mode, paths, expected counts).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Persist snapshot (requires operator approval env var).",
    )
    args = parser.parse_args()

    try:
        manifest = SharedDevCaptureManifest.load(args.manifest.resolve())
    except (ValueError, KeyError, OSError) as exc:
        print(f"SAFETY STOP: invalid manifest: {exc}", file=sys.stderr)
        return 1

    db = SessionLocal()
    try:
        if args.apply:
            assert_operator_apply_approved()
            plan = apply_shared_dev_grandfather_capture(db, manifest)
            verify_post_commit(db, manifest)
            _print_plan(plan)
            print("apply=committed rows=1")
            return 0

        from app.services.skill_progression_capture_guard_shared_dev import (
            assert_shared_dev_preflight,
        )

        target = assert_shared_dev_preflight(db, manifest, require_null_grandfather=True)
        plan = plan_shared_dev_capture(db, manifest, apply=False)
        _print_plan(plan, target)
        print("apply=skipped dry_run=complete")
        return 0
    except SharedDevCaptureSafetyError as exc:
        db.rollback()
        print(f"SAFETY STOP: {exc}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
