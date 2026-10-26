"""Phase 1: feedback-only color balance and composition insights."""

from __future__ import annotations

from unittest.mock import patch

import cv2
import numpy as np
import pytest

from app.services import media_evaluator
from app.services.supplementary_quality_insights import (
    analyze_color_balance_bgr,
    analyze_composition_framing_bgr,
    build_photo_supplementary_insights,
    build_video_supplementary_insights,
)


def _encode_png(bgr: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", bgr)
    assert ok
    return buf.tobytes()


def _flat_bgr(h: int, w: int, color: tuple[int, int, int]) -> np.ndarray:
    img = np.zeros((h, w, 3), dtype=np.uint8)
    img[:, :] = color
    return img


def test_color_balance_neutral_gray() -> None:
    bgr = _flat_bgr(128, 128, (120, 122, 118))
    out = analyze_color_balance_bgr(bgr)
    assert out["status"] in ("neutral", "inconclusive")


def test_color_balance_warm_cast() -> None:
    bgr = _flat_bgr(128, 128, (40, 120, 240))
    out = analyze_color_balance_bgr(bgr)
    assert out["status"] == "warm_cast"
    assert "warm" in out["feedback"].lower()


def test_color_balance_cool_cast() -> None:
    bgr = _flat_bgr(128, 128, (240, 130, 40))
    out = analyze_color_balance_bgr(bgr)
    assert out["status"] == "cool_cast"
    assert "cool" in out["feedback"].lower()


def test_color_balance_low_saturation_inconclusive() -> None:
    bgr = _flat_bgr(128, 128, (90, 92, 91))
    out = analyze_color_balance_bgr(bgr)
    assert out["status"] == "inconclusive"


def test_composition_centered_subject() -> None:
    bgr = _flat_bgr(200, 200, (180, 180, 180))
    y0, x0 = 70, 70
    noise = np.random.default_rng(0).integers(0, 255, (60, 60, 3), dtype=np.uint8)
    bgr[y0 : y0 + 60, x0 : x0 + 60] = noise
    out = analyze_composition_framing_bgr(bgr)
    assert out["status"] == "acceptable"
    assert "center" in out["feedback"].lower() or "acceptable" in out["headline"].lower()


def test_composition_edge_proximity() -> None:
    bgr = _flat_bgr(200, 200, (200, 200, 200))
    noise = np.random.default_rng(1).integers(0, 255, (80, 50, 3), dtype=np.uint8)
    bgr[60:140, 0:50] = noise
    out = analyze_composition_framing_bgr(bgr)
    assert out["status"] == "edge_proximity"
    assert "edge" in out["feedback"].lower()


def test_composition_uniform_inconclusive() -> None:
    bgr = _flat_bgr(128, 128, (100, 100, 100))
    out = analyze_composition_framing_bgr(bgr)
    assert out["status"] == "inconclusive"


def test_build_photo_insights_payload_shape() -> None:
    bgr = _flat_bgr(96, 96, (40, 120, 240))
    packed = build_photo_supplementary_insights(_encode_png(bgr))
    assert packed is not None
    assert packed["feedback_only"] is True
    assert "color_balance" in packed
    assert "composition_framing" in packed


def test_video_insights_aggregate_multiple_frames() -> None:
    warm = _encode_png(_flat_bgr(96, 96, (40, 120, 240)))
    warm2 = _encode_png(_flat_bgr(96, 96, (35, 115, 235)))
    packed = build_video_supplementary_insights([warm, warm2])
    assert packed is not None
    assert packed["media_type"] == "video"
    assert packed["frames_analyzed"] == 2
    assert packed["color_balance"]["status"] == "warm_cast"


def _stub_metrics() -> dict:
    return {
        "sharpness": 0.5,
        "blur": 0.2,
        "noise": 0.15,
        "brightness": 0.55,
        "contrast": 0.35,
        "blocking_artifacts": 0.1,
        "ringing_artifacts": 0.1,
        "width": 640,
        "height": 480,
    }


@pytest.mark.parametrize("include_auth", [True, False])
def test_evaluate_photo_adds_insights_without_changing_criteria(include_auth: bool) -> None:
    bgr = _flat_bgr(64, 64, (40, 120, 240))
    content = _encode_png(bgr)
    with patch.object(media_evaluator, "_analyze_image", return_value=_stub_metrics()):
        with patch.object(media_evaluator, "detect_ai_generated", return_value={"verdict": "authentic"}):
            with patch.object(media_evaluator, "apply_integrity_evaluation_policy", side_effect=lambda p: p):
                payload = media_evaluator.evaluate_photo(content, include_authenticity=include_auth)
    assert payload is not None
    assert len(payload["criteria"]) == 7
    before = round(sum(c["score"] for c in payload["criteria"]) / 7, 2)
    assert payload["overall_score"] == before
    assert "additional_quality_insights" in payload
    assert payload["additional_quality_insights"]["color_balance"]["status"] == "warm_cast"


def test_evaluate_photo_without_insights_field_when_decode_fails() -> None:
    with patch.object(media_evaluator, "_analyze_image", return_value=_stub_metrics()):
        with patch.object(media_evaluator, "detect_ai_generated", return_value={"verdict": "authentic"}):
            with patch.object(media_evaluator, "apply_integrity_evaluation_policy", side_effect=lambda p: p):
                with patch(
                    "app.services.supplementary_quality_insights.build_photo_supplementary_insights",
                    return_value=None,
                ):
                    payload = media_evaluator.evaluate_photo(b"not-an-image", include_authenticity=False)
    assert payload is not None
    assert "additional_quality_insights" not in payload


def test_evaluate_video_adds_insights_uses_quality_frames_only() -> None:
    frames = [
        _encode_png(_flat_bgr(80, 80, (40, 120, 240))),
        _encode_png(_flat_bgr(80, 80, (38, 118, 238))),
        _encode_png(_flat_bgr(80, 80, (36, 116, 236))),
    ]
    with patch.object(media_evaluator, "extract_frames", return_value=frames):
        with patch.object(media_evaluator, "_analyze_image", return_value=_stub_metrics()):
            with patch.object(
                media_evaluator,
                "detect_ai_generated_from_frames",
                return_value={"verdict": "authentic"},
            ):
                with patch.object(media_evaluator, "apply_integrity_evaluation_policy", side_effect=lambda p: p):
                    payload = media_evaluator.evaluate_video(b"fake", ext=".mp4", include_authenticity=True)
    assert payload is not None
    assert len(payload["criteria"]) == 9
    assert "additional_quality_insights" in payload
    assert payload["additional_quality_insights"]["frames_analyzed"] == 3
    assert payload["analysis"]["frames_analyzed"] == 3
