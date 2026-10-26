"""Phase 2: supplementary video motion stability insights."""

from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import patch

import cv2
import numpy as np
import pytest

from app.services.supplementary_quality_insights import build_video_supplementary_insights
from app.services.video_motion_stability_insights import analyze_video_motion_stability_bytes


def _write_mp4(path: Path, frames: list[np.ndarray], fps: float = 30.0) -> None:
    h, w = frames[0].shape[:2]
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(path), fourcc, fps, (w, h))
    assert writer.isOpened()
    for frame in frames:
        writer.write(frame)
    writer.release()


def _gradient_frame(w: int, h: int, shift: int = 0) -> np.ndarray:
    xs = np.arange(w, dtype=np.float32) + shift
    ys = np.arange(h, dtype=np.float32)[:, None]
    grid = (xs + ys) % 255.0
    noise = np.random.default_rng(shift).normal(0, 8, (h, w)).astype(np.float32)
    img = np.clip(grid + noise, 0, 255).astype(np.uint8)
    return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)


def _stable_video_bytes(frame_count: int = 90) -> bytes:
    base = _gradient_frame(320, 240, shift=0)
    frames = [base.copy() for _ in range(frame_count)]
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "stable.mp4"
        _write_mp4(path, frames)
        return path.read_bytes()


def _pan_video_bytes(frame_count: int = 90) -> bytes:
    frames = [_gradient_frame(320, 240, shift=i * 3) for i in range(frame_count)]
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "pan.mp4"
        _write_mp4(path, frames)
        return path.read_bytes()


def _jitter_video_bytes(frame_count: int = 90) -> bytes:
    rng = np.random.default_rng(42)
    frames = []
    for i in range(frame_count):
        shift = int(rng.integers(-12, 12)) + (i % 5) * 7
        frames.append(_gradient_frame(320, 240, shift=abs(shift) + i))
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "jitter.mp4"
        _write_mp4(path, frames)
        return path.read_bytes()


def _moving_subject_video_bytes(frame_count: int = 90) -> bytes:
    frames = []
    bg = _gradient_frame(320, 240, shift=1)
    for i in range(frame_count):
        frame = bg.copy()
        x0 = 40 + (i * 2) % 200
        cv2.rectangle(frame, (x0, 80), (x0 + 60, 140), (20, 220, 20), -1)
        frames.append(frame)
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "subject.mp4"
        _write_mp4(path, frames)
        return path.read_bytes()


def test_stable_video_classified_smooth_or_inconclusive() -> None:
    out = analyze_video_motion_stability_bytes(_stable_video_bytes())
    assert out["status"] in ("stable_smooth", "inconclusive")
    assert out["headline"] in ("Stable / Smooth Motion", "Inconclusive")


def test_pan_video_often_stable_smooth() -> None:
    out = analyze_video_motion_stability_bytes(_pan_video_bytes())
    assert out["status"] in ("stable_smooth", "inconclusive", "possible_shake")


def test_jitter_video_possible_shake_or_inconclusive() -> None:
    out = analyze_video_motion_stability_bytes(_jitter_video_bytes())
    assert out["status"] in ("possible_shake", "inconclusive")


def test_moving_subject_not_always_shake() -> None:
    out = analyze_video_motion_stability_bytes(_moving_subject_video_bytes())
    assert out["status"] in ("inconclusive", "possible_shake", "stable_smooth")


def test_insufficient_frames_inconclusive() -> None:
    tiny = _stable_video_bytes(frame_count=4)
    out = analyze_video_motion_stability_bytes(tiny)
    assert out["status"] == "inconclusive"


def test_decode_failure_inconclusive() -> None:
    out = analyze_video_motion_stability_bytes(b"not-a-video")
    assert out["status"] == "inconclusive"


def test_backward_compat_photo_insights_no_motion_field() -> None:
    from app.services.supplementary_quality_insights import build_photo_supplementary_insights

    bgr = np.zeros((64, 64, 3), dtype=np.uint8)
    ok, buf = cv2.imencode(".png", bgr)
    assert ok
    packed = build_photo_supplementary_insights(buf.tobytes())
    assert packed is not None
    assert "motion_stability" not in packed


def test_video_insights_includes_motion_when_bytes_provided() -> None:
    warm = np.full((80, 80, 3), (40, 120, 240), dtype=np.uint8)
    ok, buf = cv2.imencode(".png", warm)
    assert ok
    video_bytes = _stable_video_bytes()
    packed = build_video_supplementary_insights(
        [buf.tobytes(), buf.tobytes()],
        video_content=video_bytes,
        video_ext=".mp4",
    )
    assert packed is not None
    assert "motion_stability" in packed
    assert packed["motion_stability"]["headline"]


def test_evaluate_video_backward_compat_without_motion(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.services import media_evaluator

    frames_png = []
    warm = np.full((80, 80, 3), (40, 120, 240), dtype=np.uint8)
    ok, buf = cv2.imencode(".png", warm)
    assert ok
    frames_png = [buf.tobytes(), buf.tobytes()]

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

    with patch.object(media_evaluator, "extract_frames", return_value=frames_png):
        with patch.object(media_evaluator, "_analyze_image", return_value=_stub_metrics()):
            with patch.object(
                media_evaluator,
                "detect_ai_generated_from_frames",
                return_value={"verdict": "authentic"},
            ):
                with patch.object(
                    media_evaluator,
                    "apply_integrity_evaluation_policy",
                    side_effect=lambda p: p,
                ):
                    with patch(
                        "app.services.video_motion_stability_insights.analyze_video_motion_stability_bytes",
                        return_value={
                            "status": "stable_smooth",
                            "headline": "Stable / Smooth Motion",
                            "feedback": "ok",
                        },
                    ):
                        payload = media_evaluator.evaluate_video(b"x", ext=".mp4")
    assert payload is not None
    assert payload["additional_quality_insights"]["motion_stability"]["status"] == "stable_smooth"
