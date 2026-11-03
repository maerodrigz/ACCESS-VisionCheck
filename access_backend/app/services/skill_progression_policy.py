"""Versioned member skill tier progression (quality + eligible count + distinct upload days)."""

from __future__ import annotations

from dataclasses import dataclass

from app.services.skill_scoring import (
    MIN_EVALUATIONS_FOR_ADVANCED,
    MIN_EVALUATIONS_FOR_EXPERT,
    MIN_EVALUATIONS_FOR_INTERMEDIATE,
    _SKILL_TIER_ORDER,
    effective_skill_level,
    skill_level_from_score,
)

POLICY_V1 = "v1"
POLICY_V2 = "v2"
DEFAULT_ACTIVE_POLICY = POLICY_V1


def configured_skill_progression_policy() -> str:
    from app.config import settings

    raw = (settings.skill_progression_active_policy or DEFAULT_ACTIVE_POLICY).strip().lower()
    if raw in (POLICY_V1, "legacy", "1"):
        return POLICY_V1
    if raw in (POLICY_V2, "balanced", "2"):
        return POLICY_V2
    return DEFAULT_ACTIVE_POLICY


@dataclass(frozen=True)
class TierRequirements:
    min_score_pct: float
    min_eligible_evaluations: int
    min_distinct_upload_days: int


V2_TIER_REQUIREMENTS: dict[str, TierRequirements] = {
    "Intermediate": TierRequirements(60.0, 3, 2),
    "Advanced": TierRequirements(75.0, 12, 10),
    "Expert": TierRequirements(90.0, 24, 24),
}


def tier_index(level: str | None) -> int:
    name = (level or "Beginner").strip()
    for i, label in enumerate(_SKILL_TIER_ORDER):
        if label.lower() == name.lower():
            return i
    if name.lower() == "novice":
        return 0
    return 0


def tier_name_at(index: int) -> str:
    return _SKILL_TIER_ORDER[max(0, min(index, len(_SKILL_TIER_ORDER) - 1))]


def min_tier_by_index(a: str, b: str) -> str:
    return tier_name_at(min(tier_index(a), tier_index(b)))


def max_tier_by_index(a: str, b: str) -> str:
    return tier_name_at(max(tier_index(a), tier_index(b)))


def balanced_skill_tier_v2(
    *,
    skill_score_pct: float,
    eligible_count: int,
    distinct_upload_days: int,
) -> str:
    """All three gates must be met for each tier (approved balanced progression)."""
    tier = "Beginner"
    for name in ("Intermediate", "Advanced", "Expert"):
        req = V2_TIER_REQUIREMENTS[name]
        if (
            skill_score_pct >= req.min_score_pct
            and eligible_count >= req.min_eligible_evaluations
            and distinct_upload_days >= req.min_distinct_upload_days
        ):
            tier = name
    return tier


def computed_tier_for_policy(
    policy_version: str,
    *,
    skill_score_pct: float,
    eligible_count: int,
    distinct_upload_days: int,
) -> str:
    if policy_version == POLICY_V2:
        return balanced_skill_tier_v2(
            skill_score_pct=skill_score_pct,
            eligible_count=eligible_count,
            distinct_upload_days=distinct_upload_days,
        )
    return effective_skill_level(skill_score_pct, eligible_count)


def apply_grandfather_floor_v2(
    *,
    computed_v2: str,
    grandfather_floor: str | None,
    skill_score_pct: float,
) -> str:
    """Prevent demotion below a captured tier when quality still supports that tier."""
    if not grandfather_floor or not str(grandfather_floor).strip():
        return computed_v2
    floor = str(grandfather_floor).strip()
    score_tier = skill_level_from_score(skill_score_pct)
    if tier_index(score_tier) < tier_index(floor):
        return computed_v2
    return max_tier_by_index(computed_v2, floor)


@dataclass(frozen=True)
class NextTierProgress:
    next_tier_name: str | None
    required_score_pct: float | None
    required_eligible_evaluations: int | None
    required_distinct_upload_days: int | None
    remaining_score_points: int
    remaining_eligible_evaluations: int
    remaining_distinct_upload_days: int


V1_TIER_EVAL_MINIMUMS: dict[str, int] = {
    "Intermediate": MIN_EVALUATIONS_FOR_INTERMEDIATE,
    "Advanced": MIN_EVALUATIONS_FOR_ADVANCED,
    "Expert": MIN_EVALUATIONS_FOR_EXPERT,
}


def next_tier_progress_v1(
    *,
    skill_score_pct: float,
    eligible_count: int,
    current_effective_tier: str,
) -> NextTierProgress:
    idx = tier_index(current_effective_tier)
    if idx >= len(_SKILL_TIER_ORDER) - 1:
        return NextTierProgress(
            next_tier_name=None,
            required_score_pct=None,
            required_eligible_evaluations=None,
            required_distinct_upload_days=None,
            remaining_score_points=0,
            remaining_eligible_evaluations=0,
            remaining_distinct_upload_days=0,
        )
    next_name = _SKILL_TIER_ORDER[idx + 1]
    req_evals = V1_TIER_EVAL_MINIMUMS[next_name]
    score_req = {"Intermediate": 60.0, "Advanced": 75.0, "Expert": 90.0}[next_name]
    remaining_score = max(0, int(score_req - skill_score_pct + 0.999))
    remaining_evals = max(0, req_evals - eligible_count)
    return NextTierProgress(
        next_tier_name=next_name,
        required_score_pct=score_req,
        required_eligible_evaluations=req_evals,
        required_distinct_upload_days=None,
        remaining_score_points=remaining_score,
        remaining_eligible_evaluations=remaining_evals,
        remaining_distinct_upload_days=0,
    )


def next_tier_progress_for_policy(
    policy_version: str,
    *,
    skill_score_pct: float,
    eligible_count: int,
    distinct_upload_days: int,
    current_effective_tier: str,
) -> NextTierProgress:
    if policy_version == POLICY_V2:
        return next_tier_progress_v2(
            skill_score_pct=skill_score_pct,
            eligible_count=eligible_count,
            distinct_upload_days=distinct_upload_days,
            current_effective_tier=current_effective_tier,
        )
    return next_tier_progress_v1(
        skill_score_pct=skill_score_pct,
        eligible_count=eligible_count,
        current_effective_tier=current_effective_tier,
    )


def next_tier_progress_v2(
    *,
    skill_score_pct: float,
    eligible_count: int,
    distinct_upload_days: int,
    current_effective_tier: str,
) -> NextTierProgress:
    idx = tier_index(current_effective_tier)
    if idx >= len(_SKILL_TIER_ORDER) - 1:
        return NextTierProgress(
            next_tier_name=None,
            required_score_pct=None,
            required_eligible_evaluations=None,
            required_distinct_upload_days=None,
            remaining_score_points=0,
            remaining_eligible_evaluations=0,
            remaining_distinct_upload_days=0,
        )
    next_name = _SKILL_TIER_ORDER[idx + 1]
    req = V2_TIER_REQUIREMENTS[next_name]
    remaining_score = max(0, int(req.min_score_pct - skill_score_pct + 0.999))
    remaining_evals = max(0, req.min_eligible_evaluations - eligible_count)
    remaining_days = max(0, req.min_distinct_upload_days - distinct_upload_days)
    return NextTierProgress(
        next_tier_name=next_name,
        required_score_pct=req.min_score_pct,
        required_eligible_evaluations=req.min_eligible_evaluations,
        required_distinct_upload_days=req.min_distinct_upload_days,
        remaining_score_points=remaining_score,
        remaining_eligible_evaluations=remaining_evals,
        remaining_distinct_upload_days=remaining_days,
    )
