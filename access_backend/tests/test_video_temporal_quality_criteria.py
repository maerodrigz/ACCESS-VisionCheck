"""Focused tests for classical Motion Stability and Flickering heuristics."""

from __future__ import annotations

import time
from pathlib import Path

import cv2
import numpy as np
import pytest

from app.services import media_evaluator
from app.services.video_temporal_quality_criteria import (
    ESTIMATE_KIND,
    analyze_flickering_from_frames,
    analyze_motion_stability_from_frames,
    analyze_temporal_video_criteria,
)

VALIDATION_ASSETS = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "quality_validation"
    / "video_four_criteria_validation"
    / "assets"
)


def _encode_jpeg(bgr: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".jpg", bgr, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
    assert ok
    return buf.tobytes()


def _textured_still(w: int = 320, h: int = 180, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        t = y / max(h - 1, 1)
        img[y, :] = (int(200 - 30 * t), int(170 - 10 * t), int(130 + 20 * t))
    cv2.rectangle(img, (40, 40), (120, 140), (40, 80, 200), -1)
    cv2.rectangle(img, (140, 50), (220, 150), (60, 160, 70), -1)
    cv2.rectangle(img, (240, 45), (300, 145), (190, 110, 40), -1)
    noise = rng.integers(0, 20, (h, w, 3), dtype=np.uint8)
    return cv2.add(img, noise)


def _shift(bgr: np.ndarray, dx: int, dy: int) -> np.ndarray:
    h, w = bgr.shape[:2]
    m = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(bgr, m, (w, h), borderMode=cv2.BORDER_REFLECT)


def test_stable_vs_geometric_shake_motion():
    base = _textured_still()
    stable = [_encode_jpeg(base) for _ in range(4)]
    shake = [
        _encode_jpeg(_shift(base, 0, 0)),
        _encode_jpeg(_shift(base, 14, -9)),
        _encode_jpeg(_shift(base, -12, 11)),
        _encode_jpeg(_shift(base, 16, 8)),
    ]
    s = analyze_motion_stability_from_frames(stable)
    j = analyze_motion_stability_from_frames(shake)
    assert s["available"] is True and j["available"] is True
    assert s["estimate_kind"] == ESTIMATE_KIND
    assert int(s["score"]) > int(j["score"])
    assert int(s["score"]) >= 4
    assert int(j["score"]) <= 3


def test_smooth_pan_vs_erratic_motion():
    base = _textured_still(seed=1)
    pan = [_encode_jpeg(_shift(base, i * 6, 0)) for i in range(4)]
    erratic = [
        _encode_jpeg(_shift(base, 0, 0)),
        _encode_jpeg(_shift(base, 18, 10)),
        _encode_jpeg(_shift(base, -16, -12)),
        _encode_jpeg(_shift(base, 20, -14)),
    ]
    p = analyze_motion_stability_from_frames(pan)
    e = analyze_motion_stability_from_frames(erratic)
    assert p["available"] and e["available"]
    assert int(p["score"]) >= int(e["score"])
    assert int(p["score"]) >= 4
    assert int(e["score"]) <= 3


def test_constant_vs_extreme_alternating_brightness():
    base = _textured_still(seed=2)
    constant = [_encode_jpeg(base) for _ in range(4)]
    dark = np.clip(base.astype(np.float32) * 0.12, 0, 255).astype(np.uint8)
    bright = np.clip(base.astype(np.float32) * 1.6 + 50, 0, 255).astype(np.uint8)
    extreme = [_encode_jpeg(dark), _encode_jpeg(bright), _encode_jpeg(dark), _encode_jpeg(bright)]
    c = analyze_flickering_from_frames(constant)
    x = analyze_flickering_from_frames(extreme)
    assert c["available"] and x["available"]
    assert int(c["score"]) > int(x["score"])
    assert int(c["score"]) >= 4
    assert int(x["score"]) <= 2


def test_gradual_brightness_vs_oscillating():
    base = _textured_still(seed=3)
    gradual = []
    for i, scale in enumerate((0.55, 0.75, 0.95, 1.15)):
        frame = np.clip(base.astype(np.float32) * scale, 0, 255).astype(np.uint8)
        gradual.append(_encode_jpeg(frame))
    dark = np.clip(base.astype(np.float32) * 0.2, 0, 255).astype(np.uint8)
    bright = np.clip(base.astype(np.float32) * 1.5 + 30, 0, 255).astype(np.uint8)
    osc = [_encode_jpeg(dark), _encode_jpeg(bright), _encode_jpeg(dark), _encode_jpeg(bright)]
    g = analyze_flickering_from_frames(gradual)
    o = analyze_flickering_from_frames(osc)
    assert g["available"] and o["available"]
    assert int(g["score"]) > int(o["score"])
    assert int(g["score"]) >= 3


def test_insufficient_frames_and_low_texture_na():
    assert analyze_motion_stability_from_frames([])["available"] is False
    assert analyze_flickering_from_frames([_encode_jpeg(_textured_still())])["available"] is False

    flat = np.full((120, 200, 3), 128, dtype=np.uint8)
    frames = [_encode_jpeg(flat) for _ in range(4)]
    motion = analyze_motion_stability_from_frames(frames)
    assert motion["available"] is False
    assert motion["score"] is None
    assert motion["label"] == "N/A"


def test_determinism():
    base = _textured_still(seed=4)
    frames = [
        _encode_jpeg(_shift(base, 0, 0)),
        _encode_jpeg(_shift(base, 10, -6)),
        _encode_jpeg(_shift(base, -9, 7)),
        _encode_jpeg(_shift(base, 11, 5)),
    ]
    a = analyze_temporal_video_criteria(frames)
    b = analyze_temporal_video_criteria(frames)
    assert a[0]["score"] == b[0]["score"] and a[0]["available"] == b[0]["available"]
    assert a[1]["score"] == b[1]["score"] and a[1]["available"] == b[1]["available"]


def test_photo_and_color_path_unchanged(monkeypatch):
    """evaluate_photo still uses color heuristics; temporal module not required for photos."""
    from app.services.color_quality_criteria import analyze_color_criteria_bytes

    content = _encode_jpeg(_textured_still(seed=5))
    bal, sat = analyze_color_criteria_bytes(content)
    assert bal["name"] == "Color Balance"
    assert sat["name"] == "Color Saturation"
    assert bal["estimate_kind"] == "heuristic_experimental"

    stub = {
        "sharpness": 0.6,
        "blur": 0.3,
        "noise": 0.2,
        "brightness": 0.5,
        "contrast": 0.4,
        "blocking_artifacts": 0.2,
        "ringing_artifacts": 0.2,
        "width": 320,
        "height": 180,
    }
    monkeypatch.setattr(
        media_evaluator,
        "resolve_quality_engine_for_bytes",
        lambda _c: (stub, "opencv", True),
    )
    monkeypatch.setattr(media_evaluator, "detect_ai_generated", lambda *a, **k: {"verdict": "authentic"})
    monkeypatch.setattr(media_evaluator, "apply_integrity_evaluation_policy", lambda p: p)
    payload = media_evaluator.evaluate_photo(content, include_authenticity=True)
    assert payload is not None
    names = [c["name"] for c in payload["criteria"]]
    assert "Motion Stability" not in names
    assert "Flickering" not in names
    assert "Color Balance" in names and "Color Saturation" in names


def test_historical_criterion_contract_fields():
    frames = [_encode_jpeg(_textured_still()) for _ in range(3)]
    flicker, motion = analyze_temporal_video_criteria(frames)
    for c in (flicker, motion):
        assert set(c.keys()) >= {
            "name",
            "score",
            "label",
            "explanation",
            "suggestion",
            "available",
            "estimate_kind",
            "high_is_good",
        }
        assert c["estimate_kind"] == ESTIMATE_KIND


@pytest.mark.skipif(not VALIDATION_ASSETS.exists(), reason="validation assets not present")
def test_validation_assets_directionality():
    from app.services.ffmpeg_frames import extract_frames

    def score_pair(path: Path, criterion: str) -> int | None:
        content = path.read_bytes()
        frames = extract_frames(content, ".mp4")
        flicker, motion = analyze_temporal_video_criteria(frames)
        c = motion if criterion == "Motion Stability" else flicker
        return None if not c.get("available") else int(c["score"])

    base = score_pair(VALIDATION_ASSETS / "01_baseline_neutral.mp4", "Motion Stability")
    shake = score_pair(VALIDATION_ASSETS / "06_motion_geometric_shake.mp4", "Motion Stability")
    assert base is not None and shake is not None
    assert base > shake

    base_f = score_pair(VALIDATION_ASSETS / "01_baseline_neutral.mp4", "Flickering")
    extreme = VALIDATION_ASSETS / "09_flicker_brightness_extreme.mp4"
    if extreme.exists():
        ext_f = score_pair(extreme, "Flickering")
        assert base_f is not None and ext_f is not None
        assert base_f > ext_f


def test_runtime_budget_sampled_frames():
    base = _textured_still(seed=6)
    frames = [_encode_jpeg(_shift(base, i % 3, -(i % 2))) for i in range(4)]
    t0 = time.perf_counter()
    for _ in range(20):
        analyze_temporal_video_criteria(frames)
    elapsed = time.perf_counter() - t0
    # Generous budget: classical CV on 4 small frames should stay well under 2s for 20 runs.
    assert elapsed < 2.0
