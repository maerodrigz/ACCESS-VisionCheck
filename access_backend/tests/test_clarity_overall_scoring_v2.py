"""Option C: unified Clarity overall scoring (v2) without rewriting history."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.services.integrity_evaluation_policy import xp_award_points_from_payload
from app.services.media_evaluator import (
    SCORING_FORMULA_V1,
    SCORING_FORMULA_V2,
    _build_payload,
    compute_overall_score_from_criteria,
    scoring_formula_version_from_payload,
)
from app.services.member_score_release import release_member_evaluation_scores
from app.services.rule_based_quality_feedback import generate_rule_based_media_feedback, narrative_contains_measurements


def _c(name: str, score: int | None, *, available: bool = True) -> dict:
    return {
        "name": name,
        "score": score,
        "available": available and score is not None,
        "label": "Fair",
        "explanation": "",
        "suggestion": "",
    }


def _seven(**scores: int | None) -> list[dict]:
    names = [
        "Sharpness",
        "Blur",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
        "Color Balance",
        "Color Saturation",
    ]
    base = {n: 4 for n in names}
    base.update(scores)
    return [_c(n, base[n], available=base[n] is not None) for n in names]


def test_both_sharpness_and_blur_combine_into_one_clarity_factor() -> None:
    criteria = _seven(Sharpness=2, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    v1, _ = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V1)
    v2, meta = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V2)
    assert v1 == round((2 + 2 + 5 + 5 + 5 + 5 + 5) / 7, 2)
    assert meta["clarity_score"] == 2.0
    assert set(meta["clarity_inputs"]) == {"Sharpness", "Blur"}
    assert meta["overall_factor_count"] == 6
    assert v2 == round((2 + 5 + 5 + 5 + 5 + 5) / 6, 2)
    assert v2 > v1


def test_only_sharpness_available_as_clarity() -> None:
    criteria = _seven(Sharpness=3, Blur=None, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    overall, meta = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V2)
    assert meta["clarity_score"] == 3.0
    assert meta["clarity_inputs"] == ["Sharpness"]
    assert overall == round((3 + 5 + 5 + 5 + 5 + 5) / 6, 2)


def test_only_blur_available_as_clarity() -> None:
    criteria = _seven(Sharpness=None, Blur=1, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    overall, meta = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V2)
    assert meta["clarity_score"] == 1.0
    assert meta["clarity_inputs"] == ["Blur"]
    # Unlike excluding Blur entirely, poor Blur still pulls overall down.
    assert overall == round((1 + 5 + 5 + 5 + 5 + 5) / 6, 2)
    assert overall < 5.0


def test_both_clarity_unavailable_excludes_clarity() -> None:
    criteria = _seven(Sharpness=None, Blur=None, Brightness=4, Contrast=3, **{"Blocking Artifacts": 5, "Color Balance": 2, "Color Saturation": 4})
    overall, meta = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V2)
    assert meta["clarity_score"] is None
    assert meta["overall_factor_count"] == 5
    assert overall == round((4 + 3 + 5 + 2 + 4) / 5, 2)


def test_all_criteria_unavailable_no_score() -> None:
    criteria = [_c(n, None, available=False) for n in ("Sharpness", "Blur", "Brightness")]
    overall, meta = compute_overall_score_from_criteria(criteria, formula_version=SCORING_FORMULA_V2)
    assert overall == 0.0
    assert meta["overall_factor_count"] == 0


def test_quality_classification_boundaries_unchanged() -> None:
    # Construct factor means that sit on known thresholds under v2.
    # Clarity=5, five others=4 → (5+20)/6 = 4.166… → Good (<4.5)
    criteria = _seven(Sharpness=5, Blur=5, Brightness=4, Contrast=4, **{"Blocking Artifacts": 4, "Color Balance": 4, "Color Saturation": 4})
    payload = _build_payload(criteria, media_type="photo", quality_warnings=[], include_authenticity=False)
    assert payload["overall_score"] == round((5 + 4 + 4 + 4 + 4 + 4) / 6, 2)
    assert payload["quality_level"] == "Good"
    assert payload["recommendation"] == "Accepted"

    # Lift others so overall >= 4.5 Excellent
    criteria_hi = _seven(Sharpness=5, Blur=5, Brightness=5, Contrast=4, **{"Blocking Artifacts": 4, "Color Balance": 4, "Color Saturation": 5})
    payload_hi = _build_payload(criteria_hi, media_type="photo", quality_warnings=[], include_authenticity=False)
    assert payload_hi["overall_score"] >= 4.5
    assert payload_hi["quality_level"] == "Excellent"


def test_payload_persists_v2_and_seven_diagnostic_criteria() -> None:
    payload = _build_payload(
        _seven(Sharpness=2, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        media_type="photo",
        quality_warnings=[],
        include_authenticity=False,
    )
    assert payload["scoring_formula_version"] == SCORING_FORMULA_V2
    assert payload["analysis"]["scoring_formula_version"] == SCORING_FORMULA_V2
    assert payload["analysis"]["scoring_formula"] == "clarity_unified_v2"
    assert payload["analysis"]["clarity_score"] == 2.0
    names = [c["name"] for c in payload["criteria"]]
    assert names[:2] == ["Sharpness", "Blur"]
    assert len(names) == 7
    # XP preview uses legacy 0–1 overall derived from new overall.
    assert payload["legacy"]["overall_score"] == round(payload["overall_score"] / 5, 3)
    assert xp_award_points_from_payload({**payload, "xp_eligible": True, "xp_multiplier": 1.0}) == int(
        round(payload["legacy"]["overall_score"] * 100)
    )


def test_historical_payload_without_version_is_v1() -> None:
    legacy_payload = {
        "criteria": _seven(Sharpness=2, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        "overall_score": 4.14,
        "analysis": {"engine": "opencv"},
    }
    assert scoring_formula_version_from_payload(legacy_payload) == SCORING_FORMULA_V1
    # Recomputing with v1 reproduces the stored seven-mean style score.
    v1, _ = compute_overall_score_from_criteria(legacy_payload["criteria"], formula_version=SCORING_FORMULA_V1)
    assert v1 == 4.14


def test_admin_release_preserves_existing_overall_and_version() -> None:
    criteria = _seven(Sharpness=2, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    payload = _build_payload(criteria, media_type="photo", quality_warnings=[], include_authenticity=False)
    payload["member_scores_released"] = False
    payload["show_quality_feedback"] = False
    original_overall = payload["overall_score"]
    original_version = payload["scoring_formula_version"]

    import json

    ev = MagicMock()
    ev.criteria_json = json.dumps(payload)
    ev.feedback = "held"
    with patch("app.services.member_score_release.eval_crud.get_for_media", return_value=ev):
        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
            return_value={"explanation": "Great clarity work!"},
        ):
            assert release_member_evaluation_scores(MagicMock(), 9, member_first_name="Alex") is True
    data = json.loads(ev.criteria_json)
    assert data["overall_score"] == original_overall
    assert data["scoring_formula_version"] == original_version
    assert data["member_scores_released"] is True


def test_rule_based_feedback_still_combines_clarity_without_numbers() -> None:
    criteria = _seven(Sharpness=1, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    fb = generate_rule_based_media_feedback(criteria, overall_score=4.5, quality_level="Excellent")
    assert any(i.startswith("Clarity:") for i in fb["improvements"])
    blob = " ".join([fb["explanation"], *fb["strengths"], *fb["improvements"], *fb["tips"]])
    assert not narrative_contains_measurements(blob)
