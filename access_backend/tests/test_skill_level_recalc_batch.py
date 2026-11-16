"""Unit tests for skill batch recalc helpers (no database writes)."""

from app.services.skill_evaluation_eligibility import practice_evaluation_eligible_for_skill
from app.services.skill_level_recalc_batch import tiers_equal
from app.services.skill_scoring import effective_skill_level


def test_tiers_equal_case_insensitive() -> None:
    assert tiers_equal("Beginner", "beginner")
    assert not tiers_equal("Beginner", "Intermediate")


def test_effective_skill_level_eval_gates_match_batch_preview() -> None:
    assert effective_skill_level(95, 2) == "Beginner"
    assert effective_skill_level(95, 3) == "Intermediate"


def test_pending_review_excluded_from_skill_eligibility() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json='{"member_scores_released": false}',
        review_status="pending_review",
        overall_score=0.85,
    )


def test_confirmed_ai_excluded_from_skill_eligibility() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json="{}",
        review_status="confirmed_ai_generated",
        overall_score=0.9,
    )


def test_released_human_eligible() -> None:
    assert practice_evaluation_eligible_for_skill(
        criteria_json='{"member_scores_released": true}',
        review_status="verified_human",
        overall_score=0.72,
    )
