"""Regression: Gemini photo feedback N/A handling, prompt rules, release retry."""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest

from app.services import gemini_service
from app.services.gemini_service import (
    build_media_evaluation_prompt,
    gemini_configuration_status,
    generate_media_evaluation_feedback,
    is_valid_gemini_feedback,
)
from app.services.member_score_release import release_member_evaluation_scores


def _photo_eval(**overrides):
    base = {
        "media_type": "photo",
        "overall_score": 3.5,
        "overall_percent": 70,
        "quality_level": "Good",
        "recommendation": "Accepted with Suggestions",
        "scoring_engine": "musiq-paq2piq+opencv",
        "scoring_model": "musiq",
        "criteria": [
            {"name": "Sharpness", "score": 4, "label": "Good", "available": True},
            {"name": "Blur", "score": 4, "label": "Good", "available": True},
            {"name": "Brightness", "score": 3, "label": "Fair", "available": True},
            {"name": "Contrast", "score": 3, "label": "Fair", "available": True},
            {"name": "Blocking Artifacts", "score": 5, "label": "Excellent", "available": True},
            {"name": "Color Balance", "score": 2, "label": "Needs Improvement", "available": True},
            {"name": "Color Saturation", "score": 3, "label": "Fair", "available": True},
        ],
        "strengths": ["Sharpness", "Blur", "Blocking Artifacts"],
        "weaknesses": ["Color Balance"],
        "ai_detection": {"requires_review": False, "verdict": "authentic"},
        "member_scores_released": True,
        "show_quality_feedback": True,
    }
    base.update(overrides)
    return base


def test_null_na_criteria_not_treated_as_zero_weakness() -> None:
    evaluation = _photo_eval(
        criteria=[
            {"name": "Sharpness", "score": 4, "label": "Good", "available": True},
            {"name": "Blur", "score": None, "label": "N/A", "available": False},
            {"name": "Brightness", "score": None, "available": False},
            {"name": "Contrast", "available": False},
            {"name": "Color Balance", "score": 2, "label": "Needs Improvement", "available": True},
        ],
        weaknesses=["Blur", "Brightness", "Color Balance"],  # stale client list with N/A names
        strengths=["Sharpness", "Blur"],
    )
    weak = gemini_service._weaknesses(evaluation)
    strong = gemini_service._strengths(evaluation)
    lines = gemini_service._criterion_lines(evaluation)

    assert "Blur" not in weak
    assert "Brightness" not in weak
    assert "Contrast" not in weak
    assert "Color Balance" in weak
    assert "Blur" not in strong
    assert "Sharpness" in strong
    assert "Blur: N/A" in lines
    assert "None/5" not in lines
    assert ": 0/5" not in lines
    assert "Color Balance: 2/5" in lines


def test_missing_criteria_list_safe() -> None:
    evaluation = {"overall_score": 3, "quality_level": "Fair"}
    assert gemini_service._weaknesses(evaluation) == "none critical"
    assert gemini_service._strengths(evaluation) == "none highlighted"
    assert "no criteria provided" in gemini_service._criterion_lines(evaluation)


def test_prompt_engine_neutral_and_no_independent_inspection() -> None:
    prompt = build_media_evaluation_prompt(_photo_eval(), member_first_name="Alex")
    assert "EfficientNet" not in prompt
    assert "automated image quality assessment" in prompt
    assert "did NOT independently inspect" in prompt
    assert "NEVER make authenticity" in prompt
    assert "CLARITY CONSISTENCY" in prompt
    assert "double-count" in prompt.lower() or "one clarity" in prompt.lower()
    assert "MEMBER-FACING LANGUAGE" in prompt
    assert "must NOT include any numbers" in prompt


def test_sharpness_blur_consistency_note_agree() -> None:
    note = gemini_service._clarity_consistency_note(
        _photo_eval(
            criteria=[
                {"name": "Sharpness", "score": 4, "available": True},
                {"name": "Blur", "score": 4, "available": True},
            ]
        )
    )
    assert "agree" in note.lower()
    assert "double-count" in note.lower() or "one clarity" in note.lower()


def test_sharpness_blur_na_not_invented() -> None:
    note = gemini_service._clarity_consistency_note(
        _photo_eval(
            criteria=[
                {"name": "Sharpness", "score": None, "available": False, "label": "N/A"},
                {"name": "Blur", "score": 2, "available": True, "label": "Needs Improvement"},
            ]
        )
    )
    assert "Sharpness is N/A" in note
    assert "invent a sharpness defect" in note.lower() or "Do not invent a sharpness" in note


def test_opencv_fallback_payload_prompt_compatible() -> None:
    evaluation = _photo_eval(
        scoring_engine="opencv+color-heuristics",
        scoring_model="opencv",
        criteria=[
            {"name": "Sharpness", "score": 3, "available": True, "label": "Fair"},
            {"name": "Blur", "score": 3, "available": True, "label": "Fair"},
            {"name": "Brightness", "score": 4, "available": True, "label": "Good"},
            {"name": "Contrast", "score": 4, "available": True, "label": "Good"},
            {"name": "Blocking Artifacts", "score": None, "available": False, "label": "N/A"},
            {"name": "Color Balance", "score": 3, "available": True, "label": "Fair"},
            {"name": "Color Saturation", "score": 3, "available": True, "label": "Fair"},
        ],
        weaknesses=[],
        strengths=["Brightness", "Contrast"],
    )
    prompt = build_media_evaluation_prompt(evaluation)
    assert "Blocking Artifacts: N/A" in prompt
    assert "EfficientNet" not in prompt
    assert "Brightness" in gemini_service._strengths(evaluation)
    assert "Blocking Artifacts" not in gemini_service._weaknesses(evaluation)


def test_empty_and_invalid_gemini_response_returns_none() -> None:
    with patch("app.services.gemini_service._gemini_generate", return_value=None):
        assert generate_media_evaluation_feedback(_photo_eval()) is None
    with patch("app.services.gemini_service._gemini_generate", return_value=""):
        assert generate_media_evaluation_feedback(_photo_eval()) is None
    with patch("app.services.gemini_service._gemini_generate", return_value="not-json"):
        assert generate_media_evaluation_feedback(_photo_eval()) is None
    with patch(
        "app.services.gemini_service._gemini_generate",
        return_value='{"strengths": ["x"], "explanation": ""}',
    ):
        assert generate_media_evaluation_feedback(_photo_eval()) is None


def test_gemini_timeout_returns_none() -> None:
    with patch(
        "app.services.gemini_service._gemini_generate",
        side_effect=TimeoutError("timed out"),
    ):
        # generate catches inside _gemini_generate; simulate outer None path
        pass
    with patch("app.services.gemini_service.urllib.request.urlopen", side_effect=TimeoutError()):
        with patch.object(gemini_service.settings, "gemini_api_key", "test-key-not-real"):
            with patch.object(gemini_service.settings, "gemini_model", "gemini-2.5-flash"):
                assert generate_media_evaluation_feedback(_photo_eval()) is None


def test_successful_feedback_shape_flutter_compatible() -> None:
    raw = json.dumps(
        {
            "explanation": "Nice work on this photo!",
            "strengths": ["Sharp edges"],
            "improvements": ["Watch white balance"],
            "tips": ["Use daylight when possible"],
            "closing_message": "Keep practicing!",
        }
    )
    with patch("app.services.gemini_service._gemini_generate", return_value=raw):
        feedback = generate_media_evaluation_feedback(_photo_eval())
    assert is_valid_gemini_feedback(feedback)
    assert set(feedback.keys()) >= {
        "explanation",
        "strengths",
        "improvements",
        "tips",
        "closing_message",
    }
    assert isinstance(feedback["strengths"], list)
    assert isinstance(feedback["tips"], list)


def test_failed_release_remains_retryable_then_persists() -> None:
    payload = _photo_eval(member_scores_released=False, show_quality_feedback=False)
    # Simulate prior failed attempt that incorrectly stamped generated_at (legacy bug state).
    payload["gemini_generated_at"] = "2026-01-01T00:00:00+00:00"
    ev = MagicMock()
    ev.criteria_json = json.dumps(payload)
    ev.feedback = "held"

    with patch("app.services.member_score_release.eval_crud.get_for_media", return_value=ev):
        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
            return_value=None,
        ) as gen_fail:
            assert release_member_evaluation_scores(MagicMock(), 7, member_first_name="Alex") is True
            gen_fail.assert_called_once()
            data = json.loads(ev.criteria_json)
            assert data["member_scores_released"] is True
            assert not is_valid_gemini_feedback(data.get("gemini_feedback"))
            # Must not block retry solely because generated_at existed.
            assert data.get("gemini_feedback") in (None, {}) or not data.get("gemini_feedback")

        valid = {
            "explanation": "Alex, great clarity on this shot!",
            "strengths": ["Sharpness"],
            "improvements": ["Color Balance"],
            "tips": ["Correct white balance"],
            "closing_message": "Keep practicing!",
        }
        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
            return_value=valid,
        ) as gen_ok:
            assert release_member_evaluation_scores(MagicMock(), 7, member_first_name="Alex") is True
            gen_ok.assert_called_once()
            data = json.loads(ev.criteria_json)
            assert data["gemini_feedback"]["explanation"].startswith("Alex")
            assert data.get("gemini_generated_at")
            assert is_valid_gemini_feedback(data["gemini_feedback"])

        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
        ) as gen_again:
            assert release_member_evaluation_scores(MagicMock(), 7) is True
            gen_again.assert_not_called()


def test_release_does_not_stamp_generated_at_on_empty_feedback() -> None:
    payload = _photo_eval(member_scores_released=False)
    payload.pop("gemini_feedback", None)
    payload.pop("gemini_generated_at", None)
    ev = MagicMock()
    ev.criteria_json = json.dumps(payload)
    ev.feedback = "tech"

    with patch("app.services.member_score_release.eval_crud.get_for_media", return_value=ev):
        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
            return_value={"explanation": "   ", "tips": []},
        ):
            assert release_member_evaluation_scores(MagicMock(), 3) is True
            data = json.loads(ev.criteria_json)
            assert "gemini_generated_at" not in data or data.get("gemini_generated_at") is None
            assert not is_valid_gemini_feedback(data.get("gemini_feedback"))


def test_gemini_configuration_status_never_exposes_key() -> None:
    with patch.object(gemini_service.settings, "gemini_api_key", "super-secret-key-value"):
        with patch.object(gemini_service.settings, "gemini_model", "gemini-2.5-flash"):
            status = gemini_configuration_status()
    assert status["api_key_configured"] is True
    assert status["model"] == "gemini-2.5-flash"
    assert status["model_configured"] is True
    assert status["model_looks_supported"] is True
    assert status["ready"] is True
    blob = json.dumps(status)
    assert "super-secret-key-value" not in blob
    assert "api_key" not in status or "api_key_configured" in status


def test_is_valid_gemini_feedback_cases() -> None:
    assert is_valid_gemini_feedback(None) is False
    assert is_valid_gemini_feedback({}) is False
    assert is_valid_gemini_feedback({"explanation": ""}) is False
    assert is_valid_gemini_feedback({"explanation": "Nice shot!"}) is True
