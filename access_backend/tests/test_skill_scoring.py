"""Quality-only skill scoring and tier gates."""

from app.services.skill_scoring import (
    MIN_EVALUATIONS_FOR_ADVANCED,
    MIN_EVALUATIONS_FOR_EXPERT,
    MIN_EVALUATIONS_FOR_INTERMEDIATE,
    build_skill_payload,
    compute_skill_score,
    competency_level_from_skill_score,
    effective_skill_level,
    skill_level_from_score,
)


def test_compute_skill_score_is_quality_only() -> None:
    assert compute_skill_score(media_quality_score=80.0, ai_authenticity_score=0.0) == 80.0
    assert compute_skill_score(media_quality_score=65.5, ai_authenticity_score=100.0) == 65.5


def test_skill_level_thresholds() -> None:
    assert skill_level_from_score(59.9) == "Beginner"
    assert skill_level_from_score(60) == "Intermediate"
    assert skill_level_from_score(74.9) == "Intermediate"
    assert skill_level_from_score(75) == "Advanced"
    assert skill_level_from_score(89.9) == "Advanced"
    assert skill_level_from_score(90) == "Expert"


def test_effective_skill_level_evaluation_gates() -> None:
    assert effective_skill_level(95, 0) == "Beginner"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_INTERMEDIATE - 1) == "Beginner"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_INTERMEDIATE) == "Intermediate"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_ADVANCED - 1) == "Intermediate"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_ADVANCED) == "Advanced"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_EXPERT - 1) == "Advanced"
    assert effective_skill_level(95, MIN_EVALUATIONS_FOR_EXPERT) == "Expert"


def test_competency_recommended_three_band() -> None:
    assert competency_level_from_skill_score(59) == "Beginner"
    assert competency_level_from_skill_score(60) == "Intermediate"
    assert competency_level_from_skill_score(74) == "Intermediate"
    assert competency_level_from_skill_score(75) == "Advanced"
    assert competency_level_from_skill_score(95) == "Advanced"


def test_build_skill_payload_skill_score_matches_quality() -> None:
    payload = build_skill_payload(
        average_quality_score=0.72,
        approved_uploads=2,
        total_uploads=3,
        completed_tasks=1,
        assigned_tasks=2,
        admin_evaluation_score=0,
        human_verified_uploads=1,
        total_checked_uploads=2,
    )
    assert payload["media_quality_score"] == 72.0
    assert payload["skill_score"] == 72.0
    assert payload["ai_authenticity_score"] == 50.0
