"""Eligible practice evaluations for skill tier averages."""

import json

from app.services.member_score_release import apply_review_gate_to_payload
from app.services.skill_evaluation_eligibility import practice_evaluation_eligible_for_skill


def _criteria(**flags: object) -> str:
    base = {
        "overall_score": 4.0,
        "ai_detection": {"verdict": "authentic", "requires_review": False},
    }
    base.update(flags)
    return json.dumps(base)


def test_pending_review_excluded() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(member_scores_released=False),
        review_status="pending_review",
        overall_score=0.8,
    )


def test_verified_human_eligible_when_released() -> None:
    assert practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(member_scores_released=True),
        review_status="verified_human",
        overall_score=0.75,
    )


def test_confirmed_ai_excluded() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(),
        review_status="confirmed_ai_generated",
        overall_score=0.9,
    )


def test_rejected_excluded() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(member_scores_released=True),
        review_status="rejected",
        overall_score=0.8,
    )


def test_requires_review_gate_excluded() -> None:
    gated = apply_review_gate_to_payload(
        {
            "ai_detection": {"requires_review": True, "verdict": "suspicious"},
            "overall_score": 4.0,
        }
    )
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=json.dumps(gated),
        review_status=None,
        overall_score=0.8,
    )


def test_zero_score_excluded() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(member_scores_released=True),
        review_status="verified_human",
        overall_score=0.0,
    )


def test_ai_verdict_in_criteria_excluded() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json=_criteria(ai_detection={"verdict": "ai_generated"}),
        review_status="automated_low_ai_risk",
        overall_score=0.7,
    )
