"""Overall quality labels follow the displayed 0–100 bands."""

from app.services.gemini_service import build_media_evaluation_prompt
from app.services.overall_quality_band import (
    overall_percent_from_five_point,
    overall_quality_label_from_five_point,
    overall_quality_label_from_percent,
)
from app.services.rule_based_quality_feedback import generate_rule_based_media_feedback


def test_overall_quality_label_boundaries() -> None:
    expected = {
        59: "Poor",
        60: "Fair",
        74: "Fair",
        75: "Good",
        80: "Good",
        89: "Good",
        90: "Excellent",
        100: "Excellent",
    }
    for percent, label in expected.items():
        assert overall_quality_label_from_percent(percent) == label


def test_five_point_score_of_4_is_80_and_good() -> None:
    assert overall_percent_from_five_point(4.0) == 80
    assert overall_quality_label_from_five_point(4.0) == "Good"


def test_feedback_overall_sentence_follows_score_not_stale_label() -> None:
    criteria = [
        {"name": "Sharpness", "score": 4, "available": True},
        {"name": "Blur", "score": 4, "available": True},
        {"name": "Brightness", "score": 4, "available": True},
        {"name": "Contrast", "score": 4, "available": True},
    ]
    feedback = generate_rule_based_media_feedback(
        criteria,
        media_type="photo",
        overall_score=4.0,
        quality_level="Fair",
    )
    explanation = feedback["explanation"].lower()
    assert "good" in explanation
    assert "fair" not in explanation

    video = generate_rule_based_media_feedback(
        criteria,
        media_type="video",
        overall_score=4.0,
        quality_level="Fair",
    )
    video_text = video["explanation"].lower()
    assert "good" in video_text
    assert "fair" not in video_text


def test_gemini_prompt_uses_score_band_not_stale_fair_label() -> None:
    prompt = build_media_evaluation_prompt(
        {
            "media_type": "photo",
            "overall_score": 4.0,
            "quality_level": "Fair",
            "criteria": [
                {"name": "Sharpness", "score": 4, "available": True, "label": "Good"},
                {"name": "Blur", "score": 4, "available": True, "label": "Good"},
            ],
        }
    )
    assert "Overall quality: Good (4.0/5, 80/100)" in prompt
    assert "Overall quality: Fair" not in prompt
