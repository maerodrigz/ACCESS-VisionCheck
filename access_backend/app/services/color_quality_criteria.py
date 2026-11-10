"""Heuristic Color Balance and Color Saturation rubric criteria (OpenCV).

Research/product presentation estimates only. Thresholds are documented heuristics,
not human-validated perceptual gates. Do not tune on locked NR/pilot sets.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

from app.services.opencv_quality import decode_image

# Heuristic constants (documented assumptions; experimental estimates).
_MIN_SIDE = 16
_MONO_SAT_MEAN = 0.07  # mean HSV S (0–1); below → treat as mono / N/A for cast
_EXTREME_LUMA_LO = 0.08
_EXTREME_LUMA_HI = 0.94
# LAB a*/b* deviation from neutral (channel centered at 128).
_CAST_MILD = 8.0
_CAST_STRONG = 16.0
_CAST_EXTREME = 28.0
# HSV saturation mean (0–1).
_SAT_LOW = 0.12
_SAT_HIGH = 0.55
_SAT_VERY_HIGH = 0.72
_SAT_P90_CLIP = 0.92

ESTIMATE_KIND = "heuristic_experimental"


def _na_criterion(name: str, explanation: str, suggestion: str = "") -> dict[str, Any]:
    return {
        "name": name,
        "score": None,
        "label": "N/A",
        "explanation": explanation,
        "suggestion": suggestion or "No action needed for this estimate.",
        "available": False,
        "estimate_kind": ESTIMATE_KIND,
        "high_is_good": True,
    }


def _scored_criterion(
    name: str,
    score: int,
    explanation: str,
    suggestion: str,
) -> dict[str, Any]:
    labels = {5: "Excellent", 4: "Good", 3: "Fair", 2: "Needs Improvement", 1: "Poor"}
    score = int(max(1, min(5, score)))
    return {
        "name": name,
        "score": score,
        "label": labels[score],
        "explanation": explanation,
        "suggestion": suggestion,
        "available": True,
        "estimate_kind": ESTIMATE_KIND,
        "high_is_good": True,
    }


def analyze_color_balance_criterion_bgr(bgr: np.ndarray) -> dict[str, Any]:
    """Color Balance: cast strength via LAB a*/b* + RGB imbalance (heuristic)."""
    name = "Color Balance"
    if cv2 is None:
        return _na_criterion(name, "Color balance estimate unavailable (OpenCV missing).")

    h, w = bgr.shape[:2]
    if h < _MIN_SIDE or w < _MIN_SIDE:
        return _na_criterion(name, "Image too small for a reliable color balance estimate.")

    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    a_dev = float(lab[:, :, 1].astype(np.float64).mean() - 128.0)
    b_dev = float(lab[:, :, 2].astype(np.float64).mean() - 128.0)
    luma = float(lab[:, :, 0].astype(np.float64).mean()) / 255.0

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    sat_mean = float(hsv[:, :, 1].astype(np.float64).mean()) / 255.0

    if sat_mean < _MONO_SAT_MEAN:
        return _na_criterion(
            name,
            "Low color variation or monochrome look. Color balance is not scored "
            "(not treated as poor quality).",
        )
    if luma < _EXTREME_LUMA_LO or luma > _EXTREME_LUMA_HI:
        return _na_criterion(
            name,
            "Very dark or bright exposure makes color cast estimation unreliable.",
        )

    cast_mag = float(np.hypot(a_dev, b_dev))
    bb, gg, rr = cv2.split(bgr.astype(np.float64))
    rg = float(rr.mean() - gg.mean())
    warmish = b_dev > 0 and rg > 0

    # Intentional warm light: soften extreme warm casts slightly (still heuristic).
    effective = cast_mag
    if warmish and luma >= 0.35:
        effective = cast_mag * 0.85

    if effective < _CAST_MILD:
        return _scored_criterion(
            name,
            5,
            "Color channels look reasonably neutral for documentation. "
            "Mild warm or cool lighting can still be intentional. (Heuristic estimate.)",
            "Maintain this white balance when natural colors matter.",
        )
    if effective < _CAST_STRONG:
        return _scored_criterion(
            name,
            4,
            "A mild color tint is present. This is often normal for indoor or sunset light. "
            "(Heuristic estimate.)",
            "Adjust white balance only if natural subject colors are required.",
        )
    if effective < _CAST_EXTREME:
        tip = "warm" if warmish else "cool/magenta-green"
        return _scored_criterion(
            name,
            3,
            f"Noticeable {tip} color cast detected. It may be intentional artistic lighting. "
            "(Heuristic estimate; not a validated aesthetic score.)",
            "Correct white balance in-camera or in editing if true-to-life color is needed.",
        )
    return _scored_criterion(
        name,
        2,
        "Strong color cast detected across the frame. Subject colors may look unnatural "
        "for documentation. (Heuristic estimate.)",
        "Set a custom white balance or correct the cast before submitting.",
    )


def analyze_color_saturation_criterion_bgr(bgr: np.ndarray) -> dict[str, Any]:
    """Color Saturation: HSV S distribution (heuristic). High sat is not always bad."""
    name = "Color Saturation"
    if cv2 is None:
        return _na_criterion(name, "Saturation estimate unavailable (OpenCV missing).")

    h, w = bgr.shape[:2]
    if h < _MIN_SIDE or w < _MIN_SIDE:
        return _na_criterion(name, "Image too small for a reliable saturation estimate.")

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    s = hsv[:, :, 1].astype(np.float64) / 255.0
    v = hsv[:, :, 2].astype(np.float64) / 255.0
    sat_mean = float(s.mean())
    sat_p90 = float(np.percentile(s, 90))
    chroma_pixels = float(np.mean(s > 0.05))

    if chroma_pixels < 0.05 or sat_mean < _MONO_SAT_MEAN:
        return _na_criterion(
            name,
            "Image appears grayscale or intentionally muted. Saturation is not scored "
            "as a defect.",
        )

    # Extreme oversaturation: high mean + very high p90 with bright pixels.
    bright_mask = v > 0.35
    if bright_mask.any():
        sat_bright_p90 = float(np.percentile(s[bright_mask], 90))
    else:
        sat_bright_p90 = sat_p90

    if sat_mean >= _SAT_VERY_HIGH and sat_bright_p90 >= _SAT_P90_CLIP:
        return _scored_criterion(
            name,
            2,
            "Colors look heavily oversaturated and may clip. This can hurt documentation "
            "realism. (Heuristic estimate.)",
            "Reduce saturation or vibrance before export if natural color is preferred.",
        )
    if sat_mean >= _SAT_HIGH and sat_p90 >= 0.85:
        return _scored_criterion(
            name,
            3,
            "Saturation is quite high. This may be intentional but can look unnatural. "
            "(Heuristic estimate.)",
            "Dial back saturation slightly if true-to-life color is needed.",
        )
    if sat_mean < _SAT_LOW:
        return _scored_criterion(
            name,
            3,
            "Colors look muted or washed out relative to typical documentation photos. "
            "(Heuristic estimate; artistic mute looks are not automatically wrong.)",
            "Increase vibrance slightly only if the scene should look more vivid.",
        )
    if _SAT_LOW <= sat_mean < _SAT_HIGH:
        return _scored_criterion(
            name,
            5,
            "Saturation looks within a typical range for documentation photos. "
            "(Heuristic estimate.)",
            "Maintain this color intensity for future submissions.",
        )
    return _scored_criterion(
        name,
        4,
        "Saturation is moderately elevated but still usable for documentation. "
        "(Heuristic estimate.)",
        "Keep saturation moderate unless the event look requires stronger color.",
    )


def analyze_color_criteria_bytes(content: bytes) -> tuple[dict[str, Any], dict[str, Any]]:
    bgr = decode_image(content) if content else None
    if bgr is None:
        return (
            _na_criterion("Color Balance", "Could not decode image for color balance."),
            _na_criterion("Color Saturation", "Could not decode image for saturation."),
        )
    return (
        analyze_color_balance_criterion_bgr(bgr),
        analyze_color_saturation_criterion_bgr(bgr),
    )


def analyze_color_criteria_from_frames(frame_bytes: list[bytes]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Pick a mid frame for video color criteria (stable, cheap)."""
    if not frame_bytes:
        return (
            _na_criterion("Color Balance", "No video frames for color balance."),
            _na_criterion("Color Saturation", "No video frames for saturation."),
        )
    mid = frame_bytes[len(frame_bytes) // 2]
    return analyze_color_criteria_bytes(mid)
