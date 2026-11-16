"""Regression: FFmpeg under-sampling must fall back to OpenCV multi-frame extraction."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import cv2
import numpy as np
import pytest

from app.services import ffmpeg_frames as ff
from app.services.video_temporal_quality_criteria import analyze_temporal_video_criteria


def _jpeg(seed: int = 0, shift: int = 0) -> bytes:
    rng = np.random.default_rng(seed)
    img = np.zeros((120, 160, 3), dtype=np.uint8)
    img[:, :] = (40 + seed * 3, 80, 120)
    cv2.rectangle(img, (20 + shift, 20), (80 + shift, 90), (20, 180, 40), -1)
    noise = rng.integers(0, 25, img.shape, dtype=np.uint8)
    img = cv2.add(img, noise)
    ok, buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    assert ok
    return buf.tobytes()


def _write_synthetic_mp4(path: Path, *, frames: int = 8, w: int = 160, h: int = 120) -> None:
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(path), fourcc, 8.0, (w, h))
    assert writer.isOpened()
    for i in range(frames):
        img = np.zeros((h, w, 3), dtype=np.uint8)
        img[:, :] = (30 + i * 5, 60, 90)
        cv2.rectangle(img, (10 + i * 4, 20), (50 + i * 4, 80), (0, 200, 50), -1)
        writer.write(img)
    writer.release()


def test_opencv_sample_indices_are_distinct_and_span_clip() -> None:
    assert ff._opencv_sample_indices(1, 4) == [0]
    assert ff._opencv_sample_indices(2, 4) == [0, 1]
    idxs = ff._opencv_sample_indices(10, 4)
    assert idxs[0] == 0
    assert idxs[-1] == 9
    assert len(idxs) == len(set(idxs))
    assert len(idxs) >= 2


def test_normal_ffmpeg_success_keeps_ffmpeg_method() -> None:
    frames = [_jpeg(i, shift=i) for i in range(4)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=2.5):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=frames) as ffmpeg_ext:
                with patch.object(ff, "_extract_with_opencv") as opencv_ext:
                    result = ff.extract_frames_detailed(b"fake-video", ".mp4", max_frames=4)
    ffmpeg_ext.assert_called_once()
    opencv_ext.assert_not_called()
    assert result.sampling_method == ff.SAMPLING_METHOD_FFMPEG
    assert result.sampled_frame_count == 4
    assert result.probe_duration_sec == 2.5
    assert result.diagnostics()["sampled_frame_count"] == 4


def test_ffmpeg_one_frame_triggers_opencv_fallback() -> None:
    one = [_jpeg(1)]
    many = [_jpeg(i, shift=i * 3) for i in range(4)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=0.0):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=one):
                with patch.object(ff, "_extract_with_opencv", return_value=many) as opencv_ext:
                    result = ff.extract_frames_detailed(b"fake-video", ".mp4", max_frames=4)
    opencv_ext.assert_called_once()
    assert result.sampling_method == ff.SAMPLING_METHOD_OPENCV_FALLBACK
    assert result.sampled_frame_count == 4
    assert result.probe_duration_sec == 0.0


def test_zero_duration_does_not_skip_opencv_when_ffmpeg_returns_one() -> None:
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=0.0):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=[_jpeg(0)]):
                with patch.object(
                    ff,
                    "_extract_with_opencv",
                    return_value=[_jpeg(1, 2), _jpeg(2, 5), _jpeg(3, 8)],
                ):
                    result = ff.extract_frames_detailed(b"x", ".mp4")
    assert result.sampled_frame_count >= 2
    assert result.sampling_method == ff.SAMPLING_METHOD_OPENCV_FALLBACK


def test_opencv_fallback_failure_keeps_single_ffmpeg_frame() -> None:
    one = [_jpeg(9)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=1.0):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=one):
                with patch.object(ff, "_extract_with_opencv", return_value=[]):
                    result = ff.extract_frames_detailed(b"x", ".mp4")
    assert result.sampled_frame_count == 1
    assert result.sampling_method == ff.SAMPLING_METHOD_FFMPEG
    assert result.frames == one


def test_opencv_unavailable_leaves_single_ffmpeg_frame() -> None:
    one = [_jpeg(3)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "cv2", None):
            with patch.object(ff, "_probe_duration", return_value=0.0):
                with patch.object(ff, "_extract_with_ffmpeg", return_value=one):
                    result = ff.extract_frames_detailed(b"x", ".mp4")
    assert result.sampled_frame_count == 1
    assert result.sampling_method == ff.SAMPLING_METHOD_FFMPEG


def test_genuine_single_frame_input_stays_one(tmp_path: Path) -> None:
    path = tmp_path / "one.mp4"
    _write_synthetic_mp4(path, frames=1)
    content = path.read_bytes()
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_extract_with_ffmpeg", return_value=[_jpeg(0)]):
            # Real OpenCV decode of a 1-frame file should not invent a second sample.
            result = ff.extract_frames_detailed(content, ".mp4", max_frames=4)
    assert result.sampled_frame_count == 1
    flicker, motion = analyze_temporal_video_criteria(result.frames)
    assert flicker["available"] is False
    assert motion["available"] is False
    assert "Fewer than two sampled frames" in str(flicker["explanation"])
    assert "Fewer than two sampled frames" in str(motion["explanation"])


def test_no_duplicate_fabricated_frames_on_fallback() -> None:
    """Fallback must use OpenCV samples, not copy the single FFmpeg JPEG twice."""
    one = [_jpeg(7)]
    opencv = [_jpeg(1, 1), _jpeg(2, 4)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=0.0):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=one):
                with patch.object(ff, "_extract_with_opencv", return_value=opencv):
                    result = ff.extract_frames_detailed(b"x", ".mp4")
    assert result.frames == opencv
    assert result.frames[0] != result.frames[1]
    assert one[0] not in result.frames or result.frames != [one[0], one[0]]


def test_temporal_criteria_available_after_fallback_frames() -> None:
    frames = [_jpeg(i, shift=i * 6) for i in range(4)]
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_probe_duration", return_value=0.0):
            with patch.object(ff, "_extract_with_ffmpeg", return_value=[frames[0]]):
                with patch.object(ff, "_extract_with_opencv", return_value=frames):
                    result = ff.extract_frames_detailed(b"x", ".mp4")
    flicker, motion = analyze_temporal_video_criteria(result.frames)
    assert result.sampled_frame_count >= 2
    assert flicker.get("available") is True
    assert motion.get("available") is True
    assert 1 <= int(flicker["score"]) <= 5
    assert 1 <= int(motion["score"]) <= 5


def test_evaluate_video_persists_sampling_diagnostics() -> None:
    from app.services import media_evaluator

    frames = [_jpeg(i, shift=i * 5) for i in range(3)]
    extraction = ff.FrameExtractionResult(
        frames=frames,
        sampling_method=ff.SAMPLING_METHOD_OPENCV_FALLBACK,
        probe_duration_sec=0.0,
    )
    metrics = {
        "sharpness": 0.7,
        "blur": 0.3,
        "brightness": 0.5,
        "contrast": 0.5,
        "blocking_artifacts": 0.2,
        "noise": 0.1,
        "ringing_artifacts": 0.2,
        "width": 160,
        "height": 120,
    }
    color = (
        {"name": "Color Balance", "score": 4, "label": "Good", "available": True, "explanation": "", "suggestion": ""},
        {"name": "Color Saturation", "score": 4, "label": "Good", "available": True, "explanation": "", "suggestion": ""},
    )
    with patch.object(media_evaluator, "extract_frames_detailed", return_value=extraction):
        with patch(
            "app.services.musiq_worker_client.quality_engine",
            return_value="opencv",
        ):
            with patch.object(
                media_evaluator,
                "resolve_quality_engine_for_bytes",
                return_value=(dict(metrics), media_evaluator.QUALITY_ENGINE_OPENCV, False),
            ):
                with patch.object(media_evaluator, "analyze_image_for_engine", return_value=dict(metrics)):
                    with patch.object(
                        media_evaluator,
                        "analyze_color_criteria_from_frames",
                        return_value=color,
                    ):
                        with patch.object(
                            media_evaluator,
                            "build_video_supplementary_insights",
                            return_value={"feedback_only": True, "frames_analyzed": 3},
                        ):
                            with patch.object(
                                media_evaluator,
                                "detect_ai_generated_from_frames",
                                return_value={"verdict": "authentic", "confidence": 0.9},
                            ):
                                payload = media_evaluator.evaluate_video(
                                    b"video-bytes",
                                    ext=".mp4",
                                    file_name="clip.mp4",
                                    include_authenticity=True,
                                )
    assert payload is not None
    analysis = payload["analysis"]
    assert analysis["sampled_frame_count"] == 3
    assert analysis["sampling_method"] == ff.SAMPLING_METHOD_OPENCV_FALLBACK
    assert analysis["probe_duration_sec"] == 0.0
    by_name = {c["name"]: c for c in payload["criteria"]}
    assert by_name["Flickering"]["available"] is True
    assert by_name["Motion Stability"]["available"] is True


def test_live_opencv_multi_frame_file(tmp_path: Path) -> None:
    path = tmp_path / "multi.mp4"
    _write_synthetic_mp4(path, frames=6)
    content = path.read_bytes()
    with patch.object(ff, "ffmpeg_available", return_value=True):
        with patch.object(ff, "_extract_with_ffmpeg", return_value=[_jpeg(0)]):
            result = ff.extract_frames_detailed(content, ".mp4", max_frames=4)
    assert result.sampled_frame_count >= 2
    assert result.sampling_method == ff.SAMPLING_METHOD_OPENCV_FALLBACK
    assert len({id(b) for b in result.frames}) == len(result.frames)
