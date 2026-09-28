"""Automatic member skill score and tier from measurable performance."""

from __future__ import annotations


def _pct(numerator: float, denominator: float, *, default: float = 0.0) -> float:
    if denominator <= 0:
        return default
    return min(100.0, max(0.0, (numerator / denominator) * 100.0))


def media_quality_percent(average_quality_score: float) -> float:
    """Normalize average quality to 0–100 (supports 0–1 or 0–100 input)."""
    if average_quality_score <= 0:
        return 0.0
    if average_quality_score <= 1.0:
        return round(average_quality_score * 100.0, 2)
    return round(min(100.0, average_quality_score), 2)


def approved_uploads_percent(approved_uploads: int, total_uploads: int) -> float:
    return round(_pct(float(approved_uploads), float(total_uploads)), 2)


def task_participation_percent(completed_tasks: int, assigned_tasks: int) -> float:
    return round(_pct(float(completed_tasks), float(assigned_tasks)), 2)


def ai_authenticity_percent(human_verified: int, total_checked: int) -> float:
    """No scans yet → 100 (no violation recorded)."""
    if total_checked <= 0:
        return 100.0
    return round(_pct(float(human_verified), float(total_checked)), 2)


# Skill level is driven only by evaluation quality and media integrity.
_MEDIA_QUALITY_WEIGHT = 0.70
_INTEGRITY_WEIGHT = 0.30

# Members need sustained evaluations before higher tiers unlock (not one lucky upload).
MIN_EVALUATIONS_FOR_INTERMEDIATE = 3
MIN_EVALUATIONS_FOR_ADVANCED = 6
MIN_EVALUATIONS_FOR_EXPERT = 10

_SKILL_TIER_ORDER = ("Beginner", "Intermediate", "Advanced", "Expert")


def compute_skill_score(
    *,
    media_quality_score: float,
    ai_authenticity_score: float,
) -> float:
    return round(
        media_quality_score * _MEDIA_QUALITY_WEIGHT
        + ai_authenticity_score * _INTEGRITY_WEIGHT,
        2,
    )


def skill_level_from_score(skill_score: float) -> str:
    if skill_score >= 90:
        return "Expert"
    if skill_score >= 75:
        return "Advanced"
    if skill_score >= 60:
        return "Intermediate"
    return "Beginner"


def _max_tier_for_evaluation_count(evaluation_count: int) -> str:
    if evaluation_count < MIN_EVALUATIONS_FOR_INTERMEDIATE:
        return "Beginner"
    if evaluation_count < MIN_EVALUATIONS_FOR_ADVANCED:
        return "Intermediate"
    if evaluation_count < MIN_EVALUATIONS_FOR_EXPERT:
        return "Advanced"
    return "Expert"


def effective_skill_level(skill_score: float, evaluation_count: int) -> str:
    """Apply score-based tier, capped by how many evaluations the member has completed."""
    computed = skill_level_from_score(skill_score)
    cap = _max_tier_for_evaluation_count(evaluation_count)
    if _SKILL_TIER_ORDER.index(computed) > _SKILL_TIER_ORDER.index(cap):
        return cap
    return computed


def competency_level_from_skill_score(skill_score: float) -> str:
    """Admin competency management tiers (Beginner / Intermediate / Advanced)."""
    if skill_score >= 75:
        return "Advanced"
    if skill_score >= 60:
        return "Intermediate"
    return "Beginner"


def build_skill_payload(
    *,
    average_quality_score: float,
    approved_uploads: int,
    total_uploads: int,
    completed_tasks: int,
    assigned_tasks: int,
    admin_evaluation_score: float,
    human_verified_uploads: int,
    total_checked_uploads: int,
) -> dict:
    media_q = media_quality_percent(average_quality_score)
    approved_q = approved_uploads_percent(approved_uploads, total_uploads)
    task_q = task_participation_percent(completed_tasks, assigned_tasks)
    admin_q = round(min(100.0, max(0.0, admin_evaluation_score)), 2)
    ai_q = ai_authenticity_percent(human_verified_uploads, total_checked_uploads)
    skill_score = compute_skill_score(
        media_quality_score=media_q,
        ai_authenticity_score=ai_q,
    )
    return {
        "average_quality_score": media_q,
        "approved_uploads": approved_uploads,
        "total_uploads": total_uploads,
        "completed_tasks": completed_tasks,
        "assigned_tasks": assigned_tasks,
        "admin_evaluation_score": admin_q,
        "ai_authenticity_score": ai_q,
        "media_quality_score": media_q,
        "approved_uploads_score": approved_q,
        "task_participation_score": task_q,
        "skill_score": skill_score,
        "skill_level": skill_level_from_score(skill_score),
    }
