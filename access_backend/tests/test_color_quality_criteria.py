"""Functional checks for Color Balance / Color Saturation heuristics (not perceptual validation)."""

from __future__ import annotations

from io import BytesIO
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from app.services import media_evaluator
from app.services.color_quality_criteria import (
    analyze_color_balance_criterion_bgr,
    analyze_color_criteria_bytes,
    analyze_color_saturation_criterion_bgr,
)


def _png_bytes(rgb: np.ndarray) -> bytes:
    img = Image.fromarray(rgb.astype(np.uint8), mode="RGB")
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _bgr_from_rgb(rgb: np.ndarray) -> np.ndarray:
    return rgb[:, :, ::-1].copy()


def _stub_metrics() -> dict:
    return {
        "sharpness": 0.7,
        "blur": 0.2,
        "noise": 0.1,
        "brightness": 0.5,
        "contrast": 0.4,
        "blocking_artifacts": 0.1,
        "ringing_artifacts": 0.1,
        "width": 128,
        "height": 128,
    }


def test_daylight_neutral_scores_balance_and_saturation() -> None:
    rgb = np.zeros((96, 96, 3), dtype=np.uint8)
    rgb[:, :] = (120, 125, 118)
    rgb[20:70, 20:70] = (90, 140, 200)
    bal = analyze_color_balance_criterion_bgr(_bgr_from_rgb(rgb))
    sat = analyze_color_saturation_criterion_bgr(_bgr_from_rgb(rgb))
    assert bal["available"] is True
    assert sat["available"] is True
    assert 1 <= int(bal["score"]) <= 5
    assert 1 <= int(sat["score"]) <= 5
    assert "Heuristic" in bal["explanation"] or "heuristic" in bal["explanation"].lower()


def test_warm_sunset_does_not_crash_and_may_score() -> None:
    rgb = np.zeros((96, 96, 3), dtype=np.uint8)
    rgb[:, :] = (220, 120, 40)
    bal = analyze_color_balance_criterion_bgr(_bgr_from_rgb(rgb))
    assert bal["name"] == "Color Balance"
    assert bal.get("estimate_kind") == "heuristic_experimental"
    if bal["available"]:
        assert int(bal["score"]) >= 2


def test_low_light_may_be_na_or_scored() -> None:
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[:, :] = (8, 8, 10)
    bal, sat = analyze_color_criteria_bytes(_png_bytes(rgb))
    assert bal["name"] == "Color Balance"
    assert sat["name"] == "Color Saturation"
    # Extreme luma → N/A for balance is acceptable.
    if not bal["available"]:
        assert bal["score"] is None
        assert bal["label"] == "N/A"


def test_overexposed_may_be_na() -> None:
    rgb = np.full((64, 64, 3), 250, dtype=np.uint8)
    bal, _ = analyze_color_criteria_bytes(_png_bytes(rgb))
    assert bal["available"] is False


def test_oversaturated_scores_lower_or_mid() -> None:
    rgb = np.zeros((80, 80, 3), dtype=np.uint8)
    rgb[:, :] = (255, 0, 255)
    sat = analyze_color_saturation_criterion_bgr(_bgr_from_rgb(rgb))
    assert sat["available"] is True
    assert int(sat["score"]) <= 3


def test_desaturated_muted_scores_mid_or_na() -> None:
    rgb = np.zeros((80, 80, 3), dtype=np.uint8)
    rgb[:, :] = (110, 112, 108)
    sat = analyze_color_saturation_criterion_bgr(_bgr_from_rgb(rgb))
    if sat["available"]:
        assert int(sat["score"]) <= 4


def test_grayscale_balance_and_saturation_na() -> None:
    gray = np.linspace(30, 200, 64 * 64, dtype=np.uint8).reshape(64, 64)
    rgb = np.stack([gray, gray, gray], axis=-1)
    bal, sat = analyze_color_criteria_bytes(_png_bytes(rgb))
    assert bal["available"] is False
    assert sat["available"] is False


def test_blurry_image_still_returns_color_criteria() -> None:
    img = Image.new("RGB", (120, 120), (90, 140, 180))
    d = ImageDraw.Draw(img)
    d.rectangle((20, 20, 100, 100), fill=(200, 80, 40))
    img = img.filter(ImageFilter.GaussianBlur(radius=6))
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=85)
    bal, sat = analyze_color_criteria_bytes(buf.getvalue())
    assert bal["name"] == "Color Balance"
    assert sat["name"] == "Color Saturation"


def test_compressed_jpeg_functional() -> None:
    rgb = np.zeros((128, 128, 3), dtype=np.uint8)
    rgb[:, :] = (100, 130, 160)
    rgb[40:90, 40:90] = (180, 90, 50)
    img = Image.fromarray(rgb, mode="RGB")
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=15)
    bal, sat = analyze_color_criteria_bytes(buf.getvalue())
    assert "score" in bal and "score" in sat


def test_invalid_bytes_return_na() -> None:
    bal, sat = analyze_color_criteria_bytes(b"not-an-image")
    assert bal["available"] is False
    assert sat["available"] is False


def test_evaluate_photo_seven_criteria_order_no_noise_ringing() -> None:
    rgb = np.zeros((96, 96, 3), dtype=np.uint8)
    rgb[:, :] = (110, 130, 150)
    rgb[10:50, 10:50] = (200, 100, 60)
    content = _png_bytes(rgb)
    with patch.object(media_evaluator, "resolve_quality_engine_for_bytes", return_value=(_stub_metrics(), "opencv", True)):
        with patch.object(media_evaluator, "detect_ai_generated", return_value={"verdict": "authentic"}):
            with patch.object(media_evaluator, "apply_integrity_evaluation_policy", side_effect=lambda p: p):
                payload = media_evaluator.evaluate_photo(content, include_authenticity=True)
    assert payload is not None
    names = [c["name"] for c in payload["criteria"]]
    assert names == [
        "Sharpness",
        "Blur",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
        "Color Balance",
        "Color Saturation",
    ]
    assert "Noise" not in names
    assert "Ringing Artifacts" not in names
    assert payload["quality_disclaimer"]
    assert "artistic intent" in payload["quality_disclaimer"]
    assert payload["analysis"]["color_heuristics"] is True
    assert "ai_detection" in payload
    # legacy noise_score still stored from ENET/OpenCV noise metric
    assert payload["legacy"]["noise_score"] == 0.1


def test_evaluate_video_keeps_flicker_motion() -> None:
    frames = [_png_bytes(np.full((64, 64, 3), (100, 120, 140), dtype=np.uint8)) for _ in range(3)]
    with patch.object(media_evaluator, "extract_frames", return_value=frames):
        with patch.object(
            media_evaluator,
            "resolve_quality_engine_for_bytes",
            return_value=(_stub_metrics(), "opencv", True),
        ):
            with patch.object(
                media_evaluator,
                "detect_ai_generated_from_frames",
                return_value={"verdict": "authentic"},
            ):
                with patch.object(media_evaluator, "apply_integrity_evaluation_policy", side_effect=lambda p: p):
                    payload = media_evaluator.evaluate_video(b"fake", ext=".mp4", include_authenticity=True)
    assert payload is not None
    names = [c["name"] for c in payload["criteria"]]
    assert names[:7] == [
        "Sharpness",
        "Blur",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
        "Color Balance",
        "Color Saturation",
    ]
    assert "Flickering" in names
    assert "Motion Stability" in names
    assert len(names) == 9
