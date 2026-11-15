"""User-facing quality explanations must not leak research jargon."""

from __future__ import annotations

import numpy as np

from app.services.color_quality_criteria import (
    analyze_color_balance_criterion_bgr,
    analyze_color_saturation_criterion_bgr,
)
from app.services.video_temporal_quality_criteria import (
    analyze_flickering_from_frames,
    analyze_motion_stability_from_frames,
)


_BANNED = (
    "experimental heuristic",
    "heuristic estimate",
    "not a validated aesthetic score",
    "sparse sampling limits certainty",
)


def _assert_clean(text: str) -> None:
    lower = text.lower()
    for phrase in _BANNED:
        assert phrase not in lower, text


def _gray_png_bytes(value: int = 128, size: int = 64) -> bytes:
    import cv2

    img = np.full((size, size), value, dtype=np.uint8)
    ok, buf = cv2.imencode(".png", img)
    assert ok
    return bytes(buf)


def test_motion_and_flicker_explanations_are_member_friendly() -> None:
    frames = [_gray_png_bytes(120), _gray_png_bytes(122), _gray_png_bytes(121)]
    motion = analyze_motion_stability_from_frames(frames)
    flicker = analyze_flickering_from_frames(frames)
    for c in (motion, flicker):
        if c.get("available"):
            _assert_clean(str(c.get("explanation") or ""))
        assert c.get("estimate_kind") == "heuristic_experimental"


def test_color_explanations_are_member_friendly() -> None:
    bgr = np.zeros((96, 96, 3), dtype=np.uint8)
    bgr[:, :] = (40, 90, 200)
    bal = analyze_color_balance_criterion_bgr(bgr)
    sat = analyze_color_saturation_criterion_bgr(bgr)
    for c in (bal, sat):
        if c.get("available"):
            _assert_clean(str(c.get("explanation") or ""))
        assert c.get("estimate_kind") == "heuristic_experimental"


def test_strong_motion_copy_matches_product_tone() -> None:
    # Alternating geometric shift approximates unstable samples when OpenCV is present.
    frames = []
    for i in range(4):
        img = np.zeros((80, 80), dtype=np.uint8)
        img[:, :] = 40
        shift = 18 if i % 2 else 0
        img[10:50, 10 + shift : 50 + shift] = 220
        import cv2

        ok, buf = cv2.imencode(".png", img)
        assert ok
        frames.append(bytes(buf))
    motion = analyze_motion_stability_from_frames(frames)
    if motion.get("available") and int(motion.get("score") or 5) <= 2:
        expl = str(motion.get("explanation") or "").lower()
        assert "camera" in expl or "motion" in expl or "unstable" in expl
        _assert_clean(expl)
