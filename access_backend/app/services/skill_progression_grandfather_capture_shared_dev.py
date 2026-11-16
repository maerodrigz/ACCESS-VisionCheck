"""Transactional shared-dev grandfather capture (maintenance CLI only)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.services.skill_progression_capture_guard_shared_dev import (
    SharedDevCaptureSafetyError,
    assert_operator_apply_approved,
    assert_shared_dev_live_identity,
    assert_shared_dev_preflight,
    collect_target_row_state,
)
from app.services.skill_progression_capture_manifest import SharedDevCaptureManifest
from app.services.skill_progression_policy import POLICY_V1


@dataclass(frozen=True)
class SharedDevCapturePlan:
    mode: str
    target_user_id: int
    target_ranking_id: int
    computed_tier_v1: str
    floor_before: str | None
    floor_after: str
    policy_label: str


def plan_shared_dev_capture(
    db: Session,
    manifest: SharedDevCaptureManifest,
    *,
    apply: bool,
) -> SharedDevCapturePlan:
    target = assert_shared_dev_preflight(db, manifest, require_null_grandfather=True)
    mode = "APPLY" if apply else "DRY-RUN"
    return SharedDevCapturePlan(
        mode=mode,
        target_user_id=target["user_id"],
        target_ranking_id=target["ranking_id"],
        computed_tier_v1=target["computed_tier_v1"],
        floor_before=target["grandfather_floor"],
        floor_after=target["computed_tier_v1"],
        policy_label=POLICY_V1,
    )


def apply_shared_dev_grandfather_capture(
    db: Session,
    manifest: SharedDevCaptureManifest,
) -> SharedDevCapturePlan:
    """Single-row transactional capture. Caller must not invoke on production without approval."""
    assert_operator_apply_approved()
    exp = manifest.expected
    captured_at = datetime.now(timezone.utc)

    with db.begin():
        assert_shared_dev_live_identity(db, manifest)
        assert_shared_dev_preflight(db, manifest, require_null_grandfather=True)

        locked = db.execute(
            text(
                "SELECT id, user_id, skill_tier_grandfather_floor, "
                "skill_tier_grandfather_captured_at, skill_tier_grandfather_from_policy "
                "FROM member_rankings "
                "WHERE id = :rid AND user_id = :uid "
                "FOR UPDATE"
            ),
            {"rid": exp.target_ranking_id, "uid": exp.target_user_id},
        ).mappings().one_or_none()
        if locked is None:
            raise SharedDevCaptureSafetyError("Target ranking row missing under lock.")

        if locked["skill_tier_grandfather_floor"] is not None and str(
            locked["skill_tier_grandfather_floor"]
        ).strip():
            raise SharedDevCaptureSafetyError("Grandfather floor set during lock (TOCTOU).")
        if locked["skill_tier_grandfather_captured_at"] is not None:
            raise SharedDevCaptureSafetyError("captured_at set during lock (TOCTOU).")
        if locked["skill_tier_grandfather_from_policy"] is not None and str(
            locked["skill_tier_grandfather_from_policy"]
        ).strip():
            raise SharedDevCaptureSafetyError("from_policy set during lock (TOCTOU).")

        target = collect_target_row_state(db, manifest)
        if target["computed_tier_v1"] != exp.computed_tier_v1:
            raise SharedDevCaptureSafetyError("Tier changed inside transaction.")

        result = db.execute(
            text(
                "UPDATE member_rankings SET "
                "skill_tier_grandfather_floor = :floor, "
                "skill_tier_grandfather_captured_at = :captured_at, "
                "skill_tier_grandfather_from_policy = :from_policy "
                "WHERE id = :rid AND user_id = :uid "
                "AND skill_tier_grandfather_floor IS NULL "
                "AND skill_tier_grandfather_captured_at IS NULL "
                "AND (skill_tier_grandfather_from_policy IS NULL "
                "     OR trim(skill_tier_grandfather_from_policy) = '')"
            ),
            {
                "floor": exp.computed_tier_v1,
                "captured_at": captured_at,
                "from_policy": POLICY_V1,
                "rid": exp.target_ranking_id,
                "uid": exp.target_user_id,
            },
        )
        if result.rowcount != 1:
            raise SharedDevCaptureSafetyError(
                f"Expected UPDATE rowcount 1, got {result.rowcount}."
            )

    plan = SharedDevCapturePlan(
        mode="APPLY",
        target_user_id=exp.target_user_id,
        target_ranking_id=exp.target_ranking_id,
        computed_tier_v1=exp.computed_tier_v1,
        floor_before=None,
        floor_after=exp.computed_tier_v1,
        policy_label=POLICY_V1,
    )
    return plan


def verify_post_commit(db: Session, manifest: SharedDevCaptureManifest) -> None:
    """Read-only verification after apply (future Phase 8F)."""
    exp = manifest.expected
    row = db.execute(
        text(
            "SELECT skill_tier_grandfather_floor, skill_tier_grandfather_from_policy "
            "FROM member_rankings WHERE id = :rid AND user_id = :uid"
        ),
        {"rid": exp.target_ranking_id, "uid": exp.target_user_id},
    ).mappings().one()
    floor = row["skill_tier_grandfather_floor"]
    if floor != exp.computed_tier_v1:
        raise SharedDevCaptureSafetyError(
            f"Post-commit floor={floor!r}, expected {exp.computed_tier_v1!r}."
        )
    if row["skill_tier_grandfather_from_policy"] != POLICY_V1:
        raise SharedDevCaptureSafetyError("Post-commit from_policy mismatch.")
