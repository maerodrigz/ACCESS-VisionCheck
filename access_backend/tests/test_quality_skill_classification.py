"""Quality Skill Classification — pure ladder rules (no XP / progression side effects)."""

from __future__ import annotations

import pytest

from app.services.quality_skill_classification import (
    NOT_YET_CLASSIFIED,
    classify_from_scores,
    overall_score_to_five,
)


def _title(scores: list[float]) -> str:
    return classify_from_scores(scores, media_kind="photo", formula_version="v2").title


def test_not_yet_classified_under_three() -> None:
    assert _title([]) == NOT_YET_CLASSIFIED
    assert _title([4.8, 4.9]) == NOT_YET_CLASSIFIED


def test_all_five_classifications() -> None:
    assert _title([1.5, 1.2, 1.0]) == "Beginner"
    assert _title([2.5, 2.4, 2.1]) == "Developing"
    assert _title([3.5, 3.4, 3.2, 3.1, 3.0]) == "Proficient"
    assert _title([4.2] * 8) == "Advanced"
    assert _title([4.7] * 10) == "Expert"


def test_highest_eligible_requires_both_score_and_count() -> None:
    # Score is Expert-level but only 3 evals → Developing (not Expert).
    assert _title([4.9, 4.8, 4.7]) == "Developing"
    # Score Advanced with 8 evals → Advanced (not Expert).
    assert _title([4.4] * 8) == "Advanced"
    # Score Expert with 10 → Expert.
    assert _title([4.5] * 10) == "Expert"


@pytest.mark.parametrize(
    ("score", "expected"),
    [
        (1.99, "Beginner"),
        (2.00, "Developing"),
        (2.99, "Developing"),
        (3.00, "Proficient"),
        (3.99, "Proficient"),
        (4.00, "Advanced"),
        (4.49, "Advanced"),
        (4.50, "Expert"),
        (5.00, "Expert"),
    ],
)
def test_boundary_values_with_enough_evaluations(score: float, expected: str) -> None:
    count = 10
    assert _title([score] * count) == expected


def test_uses_latest_ten_only() -> None:
    # 12 scores newest-first: first 10 average to Developing band; older Expert ignored.
    window = [2.5] * 10 + [5.0, 5.0]
    result = classify_from_scores(window, media_kind="video", formula_version="v2")
    assert result.qualifying_evaluations == 10
    assert result.title == "Developing"


def test_unrounded_average_for_thresholds() -> None:
    # Mean is just under 4.50 → Advanced, not Expert.
    scores = [4.49] * 9 + [4.499]
    result = classify_from_scores(scores, media_kind="photo", formula_version="v2")
    assert result.average_score is not None
    assert result.average_score < 4.50
    assert result.title == "Advanced"


def test_progress_toward_next() -> None:
    result = classify_from_scores([3.2] * 5, media_kind="photo", formula_version="v2")
    assert result.title == "Proficient"
    assert result.next_title == "Advanced"
    assert result.evaluations_gap == 3
    assert result.score_gap is not None
    assert result.score_gap > 0


def test_overall_score_normalization() -> None:
    assert overall_score_to_five(0.8) == pytest.approx(4.0)
    assert overall_score_to_five(4.0) == pytest.approx(4.0)
    assert overall_score_to_five(0) is None
