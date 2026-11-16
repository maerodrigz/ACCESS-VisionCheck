"""Regression: deterministic rule-based photo quality feedback."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app.services.rule_based_quality_feedback import (
    PHOTO_QUALITY_METRICS,
    format_rule_based_ai_feedback,
    format_rule_based_improvement_suggestions,
    generate_rule_based_media_feedback,
    narrative_contains_measurements,
    sanitize_member_facing_feedback,
)
from app.services.media_evaluator import _build_payload


def _c(name: str, score: int | None, *, available: bool = True, explanation: str = "", suggestion: str = ""):
    return {
        "name": name,
        "score": score,
        "available": available,
        "label": "N/A" if not available or score is None else "Fair",
        "explanation": explanation,
        "suggestion": suggestion,
    }


def _seven(**overrides: int | None):
    base = {
        "Sharpness": 4,
        "Blur": 4,
        "Brightness": 3,
        "Contrast": 3,
        "Blocking Artifacts": 5,
        "Color Balance": 3,
        "Color Saturation": 3,
    }
    base.update(overrides)
    out = []
    for name in PHOTO_QUALITY_METRICS:
        val = base[name]
        if val is None:
            out.append(_c(name, None, available=False))
        else:
            out.append(_c(name, int(val)))
    return out


def test_each_of_seven_metrics_can_appear_in_strength_or_improvement() -> None:
    for name in PHOTO_QUALITY_METRICS:
        # Make this metric the unique top score so it is selected among strengths.
        high_scores = {n: 3 for n in PHOTO_QUALITY_METRICS}
        high_scores[name] = 5
        high = generate_rule_based_media_feedback(_seven(**high_scores))
        assert any(name in s for s in high["strengths"]), name

        if name in {"Sharpness", "Blur"}:
            continue
        low_scores = {n: 5 for n in PHOTO_QUALITY_METRICS}
        low_scores[name] = 1
        low = generate_rule_based_media_feedback(_seven(**low_scores))
        assert any(name in i for i in low["improvements"]), name
        assert low["tips"]


@pytest.mark.parametrize("score", [1, 3, 5])
def test_low_medium_high_brightness_guidance(score: int) -> None:
    fb = generate_rule_based_media_feedback(_seven(Brightness=score, **{n: 5 for n in PHOTO_QUALITY_METRICS if n != "Brightness"}))
    assert fb["explanation"]
    if score >= 4:
        assert any("Brightness" in s for s in fb["strengths"])
    if score <= 2:
        assert any("Brightness" in i for i in fb["improvements"])
        assert any("lighting" in t.lower() or "exposure" in t.lower() for t in fb["tips"])


def test_multiple_simultaneous_weaknesses_prioritized() -> None:
    fb = generate_rule_based_media_feedback(
        _seven(
            Sharpness=5,
            Blur=5,
            Brightness=1,
            Contrast=1,
            **{"Blocking Artifacts": 1, "Color Balance": 1, "Color Saturation": 5},
        )
    )
    assert len(fb["improvements"]) <= 3
    assert len(fb["tips"]) <= 3
    joined = " ".join(fb["improvements"])
    assert "Brightness" in joined or "Contrast" in joined or "Blocking" in joined or "Color Balance" in joined


def test_sharpness_blur_correlation_combined() -> None:
    fb = generate_rule_based_media_feedback(
        _seven(Sharpness=1, Blur=2, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5})
    )
    joined_i = " ".join(fb["improvements"]).lower()
    joined_t = " ".join(fb["tips"]).lower()
    assert "clarity" in joined_i
    assert joined_i.count("sharpness") + joined_i.count("blur") <= 1 or "sharpness/blur" in joined_i
    assert "steady" in joined_t or "focus" in joined_t
    # Single combined tip, not two duplicate clarity tips
    assert len([t for t in fb["tips"] if "softness and blur" in t.lower() or "focus" in t.lower()]) >= 1
    assert not any(s.startswith("Sharpness") for s in fb["strengths"])
    assert not any(s.startswith("Blur") for s in fb["strengths"])


def test_na_and_missing_criteria_ignored() -> None:
    criteria = [
        _c("Sharpness", 5),
        _c("Blur", None, available=False),
        _c("Brightness", 1, explanation="Scene is quite dark."),
        _c("Contrast", None, available=False),
        _c("Blocking Artifacts", 5),
        _c("Color Balance", None, available=False),
        _c("Color Saturation", 5),
    ]
    fb = generate_rule_based_media_feedback(criteria, quality_warnings=["Media is quite dark — more light would improve detail."])
    text = " ".join(fb["improvements"] + fb["tips"] + fb["strengths"]).lower()
    assert "blur" not in text or "clarity" not in " ".join(fb["improvements"]).lower()
    assert "Color Balance" not in " ".join(fb["improvements"])
    assert any("Brightness" in i for i in fb["improvements"])
    assert any("light" in t.lower() or "exposure" in t.lower() for t in fb["tips"])


def test_all_good_positive_with_maintenance_tips() -> None:
    fb = generate_rule_based_media_feedback(_seven(**{n: 5 for n in PHOTO_QUALITY_METRICS}))
    assert not fb["improvements"]
    assert fb["strengths"]
    assert "strong" in fb["explanation"].lower() or "great" in fb["explanation"].lower()
    assert len(fb["tips"]) >= 1
    assert all("compression" in t.lower() or "lighting" in t.lower() or "focus" in t.lower() or "export" in t.lower() for t in fb["tips"])


def test_insufficient_metrics() -> None:
    fb = generate_rule_based_media_feedback([_c("Sharpness", 4)])
    assert fb["insufficient_metrics"] is True
    assert "limited" in fb["explanation"].lower()
    assert fb["improvements"]


def test_brightness_directional_vs_neutral() -> None:
    under = generate_rule_based_media_feedback(
        [
            _c("Sharpness", 5),
            _c("Blur", 5),
            _c("Brightness", 2, explanation="Scene is quite dark."),
            _c("Contrast", 5),
            _c("Blocking Artifacts", 5),
            _c("Color Balance", 5),
            _c("Color Saturation", 5),
        ],
        quality_warnings=["Media is quite dark"],
    )
    neutral = generate_rule_based_media_feedback(
        [
            _c("Sharpness", 5),
            _c("Blur", 5),
            _c("Brightness", 2),
            _c("Contrast", 5),
            _c("Blocking Artifacts", 5),
            _c("Color Balance", 5),
            _c("Color Saturation", 5),
        ]
    )
    assert any("Add light" in t or "raise exposure" in t for t in under["tips"])
    assert any("without guessing" in t or "even light" in t for t in neutral["tips"])


def test_brightness_warning_only_underexposure() -> None:
    """Underexposure evidence only in quality_warnings (no criterion explanation)."""
    fb = generate_rule_based_media_feedback(
        _seven(Brightness=2, Sharpness=5, Blur=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        quality_warnings=["Media is quite dark — more light would improve detail."],
    )
    assert any("Add light" in t or "raise exposure" in t for t in fb["tips"])
    _assert_no_narrative_measurements(fb)


def test_brightness_missing_warnings_stays_neutral() -> None:
    fb = generate_rule_based_media_feedback(
        _seven(Brightness=2, Sharpness=5, Blur=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        quality_warnings=[],
    )
    assert any("without guessing" in t or "even light" in t for t in fb["tips"])
    assert not any("Add light" in t for t in fb["tips"])


def test_brightness_conflicting_directional_evidence_stays_neutral() -> None:
    fb = generate_rule_based_media_feedback(
        _seven(Brightness=2, Sharpness=5, Blur=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        quality_warnings=["Media is quite dark", "Media may be overexposed — highlights could be washed out."],
    )
    assert any("without guessing" in t or "even light" in t for t in fb["tips"])
    assert not any(t.startswith("Add light") for t in fb["tips"])
    assert not any(t.startswith("Reduce intense light") for t in fb["tips"])


def test_payload_includes_rule_based_and_keeps_api_fields() -> None:
    payload = _build_payload(
        _seven(Sharpness=2, Blur=2, **{"Color Balance": 1}),
        media_type="photo",
        quality_warnings=[],
        include_authenticity=False,
    )
    assert "overall_score" in payload
    assert "criteria" in payload
    assert "ai_feedback" in payload
    assert "improvement_suggestions" in payload
    assert isinstance(payload.get("rule_based_feedback"), dict)
    rb = payload["rule_based_feedback"]
    assert rb.get("source") == "rule_based"
    assert "explanation" in rb and "tips" in rb
    assert "Clarity" in " ".join(rb.get("improvements") or []) or "clarity" in (rb.get("explanation") or "").lower()


def test_gemini_unavailable_does_not_block_rule_based_payload() -> None:
    """Simulate Gemini failure path: evaluation payload still carries rule-based feedback."""
    with patch("app.services.gemini_service._gemini_generate", return_value=None):
        from app.services.gemini_service import generate_media_evaluation_feedback

        payload = _build_payload(
            _seven(**{"Color Balance": 2}),
            media_type="photo",
            quality_warnings=[],
            include_authenticity=False,
        )
        assert generate_media_evaluation_feedback(payload) is None
        assert payload["rule_based_feedback"]["tips"]
        assert payload["ai_feedback"]


def test_format_helpers_preserve_sections() -> None:
    fb = generate_rule_based_media_feedback(_seven(**{"Color Balance": 1, "Sharpness": 5, "Blur": 5}))
    flat = format_rule_based_ai_feedback(fb)
    tips = format_rule_based_improvement_suggestions(fb)
    assert "Strengths:" in flat or fb["strengths"]
    assert "Areas to improve:" in flat
    assert tips.startswith("•")


def test_backend_flutter_consistency_markers() -> None:
    """Shared wording markers that Flutter rule-based module must also emit."""
    clarity = generate_rule_based_media_feedback(_seven(Sharpness=1, Blur=1, Brightness=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}))
    assert any(i.startswith("Clarity:") for i in clarity["improvements"])
    assert any("softness and blur in one step" in t for t in clarity["tips"])
    limited = generate_rule_based_media_feedback([])
    assert "limited" in limited["explanation"].lower()


def _assert_no_narrative_measurements(fb: dict) -> None:
    chunks = [str(fb.get("explanation") or ""), str(fb.get("closing_message") or "")]
    for key in ("strengths", "improvements", "tips"):
        chunks.extend(str(x) for x in (fb.get(key) or []))
    for chunk in chunks:
        assert not narrative_contains_measurements(chunk), chunk
        assert "/5" not in chunk
        assert "%" not in chunk


def test_narratives_contain_no_numerical_measurements() -> None:
    profiles = [
        _seven(**{n: 5 for n in PHOTO_QUALITY_METRICS}),
        _seven(Sharpness=1, Blur=2, **{"Color Balance": 1}),
        _seven(Brightness=1, Sharpness=5, Blur=5, Contrast=5, **{"Blocking Artifacts": 5, "Color Balance": 5, "Color Saturation": 5}),
        [_c("Sharpness", 4)],
    ]
    for criteria in profiles:
        fb = generate_rule_based_media_feedback(criteria)
        _assert_no_narrative_measurements(fb)
        flat = format_rule_based_ai_feedback(fb)
        assert not narrative_contains_measurements(flat)
        assert "/5" not in flat


def test_metric_scores_still_present_on_payload_criteria() -> None:
    payload = _build_payload(
        _seven(Sharpness=2, Blur=4, Brightness=3),
        media_type="photo",
        quality_warnings=[],
        include_authenticity=False,
    )
    by_name = {c["name"]: c for c in payload["criteria"]}
    assert by_name["Sharpness"]["score"] == 2
    assert by_name["Blur"]["score"] == 4
    assert by_name["Brightness"]["score"] == 3
    assert payload["overall_score"] is not None
    _assert_no_narrative_measurements(payload["rule_based_feedback"])


def test_sanitize_strips_gemini_style_score_mentions() -> None:
    dirty = {
        "explanation": "Nice shot at 4/5 overall (80%)!",
        "strengths": ["Sharpness (5/5): crisp"],
        "improvements": ["Blur scored 2"],
        "tips": ["Raise exposure by 20%"],
        "closing_message": "Try again!",
    }
    clean = sanitize_member_facing_feedback(dirty)
    _assert_no_narrative_measurements(clean)
    assert "crisp" in clean["strengths"][0].lower() or "Sharpness" in clean["strengths"][0]
