"""Resolve skill progression for API, rankings, and recalc (policy v1 default)."""

from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.models.member_ranking import MemberRanking

_OVERRIDE_UNSET = object()
from app.services.skill_evaluation_eligibility import eligible_skill_evaluation_stats
from app.services.skill_progression_grandfather import v2_activation_blocked_reason
from app.services.skill_progression_policy import (
    POLICY_V1,
    POLICY_V2,
    apply_grandfather_floor_v2,
    computed_tier_for_policy,
    configured_skill_progression_policy,
    next_tier_progress_for_policy,
)
from app.services.skill_scoring import (
    competency_level_from_skill_score,
    effective_skill_level,
    media_quality_percent,
)


def active_skill_progression_policy() -> str:
    """Effective policy without DB (env only). Prefer [resolve_effective_skill_progression_policy] in requests."""
    return configured_skill_progression_policy()


def resolve_effective_skill_progression_policy(db: Session) -> tuple[str, str | None]:
    """Return (effective_policy, v2_blocked_reason).

    Effective v2 requires configured v2, a sealed activation, and complete
    protected-cohort grandfather floors. Otherwise fail closed to v1.
    """
    from app.services.skill_progression_policy import configured_skill_progression_policy as configured_now

    configured = configured_now()
    if configured != POLICY_V2:
        return configured, None
    blocked = v2_activation_blocked_reason(db)
    if blocked:
        return POLICY_V1, blocked
    return POLICY_V2, None


@dataclass(frozen=True)
class SkillProgressionSnapshot:
    policy_version: str
    configured_policy_version: str
    v2_activation_blocked_reason: str | None
    skill_score_pct: float
    eligible_evaluation_count: int
    distinct_eligible_upload_days: int
    computed_tier_v1: str
    computed_tier_v2_raw: str
    computed_tier_v2: str
    computed_tier_active: str
    effective_tier: str
    competency_recommended: str
    grandfather_floor: str | None
    next_tier_name: str | None
    next_tier_required_evaluations: int | None
    next_tier_required_days: int | None
    next_tier_required_score_pct: float | None
    remaining_eligible_evaluations: int
    remaining_distinct_upload_days: int
    remaining_score_points: int
    admin_override: str | None


def _normalize_competency_override(raw: str | None) -> str | None:
    if not raw or not str(raw).strip():
        return None
    label = str(raw).strip().lower()
    if label not in ("beginner", "intermediate", "advanced"):
        return None
    return label.capitalize()


def build_skill_progression_snapshot(
    db: Session,
    user_id: int,
    *,
    skill_score_pct: float | None = None,
    eligible_count: int | None = None,
    distinct_days: int | None = None,
    level_override: str | None | object = _OVERRIDE_UNSET,
) -> SkillProgressionSnapshot:
    from sqlalchemy import select

    eligible = eligible_skill_evaluation_stats(db, user_id)
    count = eligible_count if eligible_count is not None else eligible.count
    days = distinct_days if distinct_days is not None else eligible.distinct_upload_days
    score = (
        skill_score_pct
        if skill_score_pct is not None
        else media_quality_percent(eligible.average_score)
    )

    from app.services.skill_progression_policy import (
        configured_skill_progression_policy as configured_now,
    )

    configured = configured_now()
    policy, blocked_reason = resolve_effective_skill_progression_policy(db)
    computed_v1 = effective_skill_level(score, count)
    computed_v2_raw = computed_tier_for_policy(
        POLICY_V2,
        skill_score_pct=score,
        eligible_count=count,
        distinct_upload_days=days,
    )

    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user_id))
    grandfather = ranking.skill_tier_grandfather_floor if ranking else None
    computed_v2 = apply_grandfather_floor_v2(
        computed_v2=computed_v2_raw,
        grandfather_floor=grandfather,
        skill_score_pct=score,
    )

    if policy == POLICY_V2:
        computed_active = computed_v2
    else:
        computed_active = computed_v1

    override_raw = None
    if level_override is not _OVERRIDE_UNSET:
        override_raw = level_override
    elif ranking and ranking.competency_level_override:
        override_raw = ranking.competency_level_override

    override = _normalize_competency_override(
        str(override_raw) if override_raw else None
    )
    if override:
        effective = override
    else:
        effective = computed_active

    progress = next_tier_progress_for_policy(
        policy,
        skill_score_pct=score,
        eligible_count=count,
        distinct_upload_days=days,
        current_effective_tier=effective,
    )

    return SkillProgressionSnapshot(
        policy_version=policy,
        configured_policy_version=configured,
        v2_activation_blocked_reason=blocked_reason,
        skill_score_pct=round(score, 2),
        eligible_evaluation_count=count,
        distinct_eligible_upload_days=days,
        computed_tier_v1=computed_v1,
        computed_tier_v2_raw=computed_v2_raw,
        computed_tier_v2=computed_v2,
        computed_tier_active=computed_active,
        effective_tier=effective,
        competency_recommended=competency_level_from_skill_score(score),
        grandfather_floor=grandfather,
        next_tier_name=progress.next_tier_name,
        next_tier_required_evaluations=progress.required_eligible_evaluations,
        next_tier_required_days=progress.required_distinct_upload_days,
        next_tier_required_score_pct=progress.required_score_pct,
        remaining_eligible_evaluations=progress.remaining_eligible_evaluations,
        remaining_distinct_upload_days=progress.remaining_distinct_upload_days,
        remaining_score_points=progress.remaining_score_points,
        admin_override=override,
    )
