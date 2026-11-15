"""Extract video frames via FFmpeg (preferred) or OpenCV VideoCapture fallback."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

DEFAULT_SAMPLE_COUNT = 4

# Sampling method labels persisted on new evaluation analysis payloads only.
SAMPLING_METHOD_FFMPEG = "ffmpeg"
SAMPLING_METHOD_OPENCV = "opencv"
SAMPLING_METHOD_OPENCV_FALLBACK = "opencv_fallback"
SAMPLING_METHOD_NONE = "none"


@dataclass(frozen=True)
class FrameExtractionResult:
    """Sampled JPEG/PNG frame bytes plus safe diagnostic metadata (no paths/bytes logged)."""

    frames: list[bytes]
    sampling_method: str
    probe_duration_sec: float | None = None

    @property
    def sampled_frame_count(self) -> int:
        return len(self.frames)

    def diagnostics(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "sampled_frame_count": self.sampled_frame_count,
            "sampling_method": self.sampling_method,
        }
        if self.probe_duration_sec is not None:
            out["probe_duration_sec"] = round(float(self.probe_duration_sec), 3)
        return out


def _default_sample_count() -> int:
    try:
        from app.config import settings

        return max(2, min(8, int(settings.evaluation_video_sample_frames)))
    except Exception:
        return DEFAULT_SAMPLE_COUNT


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None


def extract_frames(content: bytes, ext: str, *, max_frames: int | None = None) -> list[bytes]:
    """Return sampled frame bytes (FFmpeg preferred; OpenCV fallback when under-sampled)."""
    return extract_frames_detailed(content, ext, max_frames=max_frames).frames


def extract_frames_detailed(
    content: bytes,
    ext: str,
    *,
    max_frames: int | None = None,
) -> FrameExtractionResult:
    """Extract frames and report how sampling succeeded (safe diagnostics only)."""
    if max_frames is None:
        max_frames = _default_sample_count()
    max_frames = max(2, min(8, int(max_frames)))
    ext = ext if ext.startswith(".") else f".{ext}"
    if not content:
        return FrameExtractionResult(frames=[], sampling_method=SAMPLING_METHOD_NONE, probe_duration_sec=None)

    with tempfile.TemporaryDirectory(prefix="access_frames_") as tmp:
        tmp_path = Path(tmp)
        video_path = tmp_path / f"input{ext}"
        video_path.write_bytes(content)

        probe_duration: float | None = None
        if shutil.which("ffprobe"):
            probe_duration = _probe_duration(video_path)

        ffmpeg_frames: list[bytes] = []
        if ffmpeg_available():
            ffmpeg_frames = _extract_with_ffmpeg(video_path, tmp_path, max_frames=max_frames)
            if len(ffmpeg_frames) >= 2:
                return FrameExtractionResult(
                    frames=ffmpeg_frames,
                    sampling_method=SAMPLING_METHOD_FFMPEG,
                    probe_duration_sec=probe_duration,
                )

        opencv_frames: list[bytes] = []
        if cv2 is not None:
            opencv_frames = _extract_with_opencv(
                video_path,
                max_frames=max_frames,
                rotation_degrees=_probe_rotation_degrees(video_path),
            )

        if len(opencv_frames) >= 2:
            method = (
                SAMPLING_METHOD_OPENCV_FALLBACK
                if ffmpeg_frames or ffmpeg_available()
                else SAMPLING_METHOD_OPENCV
            )
            # Prefer OpenCV when it recovered multi-frame samples after FFmpeg under-sampling.
            return FrameExtractionResult(
                frames=opencv_frames,
                sampling_method=method,
                probe_duration_sec=probe_duration,
            )

        # Neither path yielded 2+ distinct frames: keep the best non-empty set (may be 0 or 1).
        if len(opencv_frames) > len(ffmpeg_frames):
            method = (
                SAMPLING_METHOD_OPENCV_FALLBACK
                if (ffmpeg_frames or ffmpeg_available())
                else SAMPLING_METHOD_OPENCV
            )
            return FrameExtractionResult(
                frames=opencv_frames,
                sampling_method=method,
                probe_duration_sec=probe_duration,
            )
        if ffmpeg_frames:
            return FrameExtractionResult(
                frames=ffmpeg_frames,
                sampling_method=SAMPLING_METHOD_FFMPEG,
                probe_duration_sec=probe_duration,
            )
        if opencv_frames:
            return FrameExtractionResult(
                frames=opencv_frames,
                sampling_method=SAMPLING_METHOD_OPENCV,
                probe_duration_sec=probe_duration,
            )

    return FrameExtractionResult(
        frames=[],
        sampling_method=SAMPLING_METHOD_NONE,
        probe_duration_sec=None,
    )


def _extract_with_ffmpeg(video_path: Path, tmp_path: Path, *, max_frames: int) -> list[bytes]:
    """Sample frames across the clip (one ffprobe + one ffmpeg when possible)."""
    duration = _probe_duration(video_path)
    if duration <= 0:
        # Unknown duration: do not pretend a single t=0 sample is a full timeline.
        # Callers fall through to OpenCV index sampling when this returns <2 frames.
        times = [0.0]
    else:
        step = duration / max(max_frames, 1)
        times = [min(max(0.0, duration - 0.05), step * i) for i in range(max_frames)]

    batch = _extract_with_ffmpeg_batch(video_path, tmp_path, times=times)
    if batch:
        return batch

    frames: list[bytes] = []
    for i, t in enumerate(times):
        out_path = tmp_path / f"frame_{i}.jpg"
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-ss",
            f"{t:.3f}",
            "-i",
            str(video_path),
            "-frames:v",
            "1",
            "-q:v",
            "2",
            str(out_path),
        ]
        try:
            subprocess.run(cmd, check=False, capture_output=True, timeout=30)
        except (subprocess.SubprocessError, OSError):
            continue
        if out_path.exists() and out_path.stat().st_size > 0:
            frames.append(out_path.read_bytes())
    return frames


def _extract_with_ffmpeg_batch(video_path: Path, tmp_path: Path, *, times: list[float]) -> list[bytes]:
    """Single ffmpeg invocation: seek once, emit one JPEG per timestamp."""
    if not times:
        return []
    out_pattern = str(tmp_path / "frame_%02d.jpg")
    select = "+".join(f"eq(t\\,{t:.3f})" for t in times)
    vf = f"select='{select}',scale=iw:ih"
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(video_path),
        "-vf",
        vf,
        "-vsync",
        "vfr",
        "-frames:v",
        str(len(times)),
        "-q:v",
        "2",
        out_pattern,
    ]
    try:
        subprocess.run(cmd, check=False, capture_output=True, timeout=max(45, 15 * len(times)))
    except (subprocess.SubprocessError, OSError):
        return []

    frames: list[bytes] = []
    for i in range(len(times)):
        out_path = tmp_path / f"frame_{i + 1:02d}.jpg"
        if not out_path.exists():
            out_path = tmp_path / f"frame_{i}.jpg"
        if out_path.exists() and out_path.stat().st_size > 0:
            frames.append(out_path.read_bytes())
    return frames


def probe_video_duration_from_bytes(content: bytes, *, suffix: str = ".mp4") -> float:
    """Return clip duration in seconds, or 0.0 if ffprobe is unavailable or probing fails."""
    if not content:
        return 0.0
    normalized = suffix.lower() if suffix.startswith(".") else f".{suffix.lower()}"
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / f"probe{normalized}"
        path.write_bytes(content)
        return _probe_duration(path)


def _probe_duration(video_path: Path) -> float:
    if not shutil.which("ffprobe"):
        return 0.0
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(video_path),
    ]
    try:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=15)
        if result.returncode == 0 and result.stdout.strip():
            return max(0.0, float(result.stdout.strip()))
    except (ValueError, subprocess.SubprocessError, OSError):
        pass
    return 0.0


def _probe_rotation_degrees(video_path: Path) -> int:
    """Display rotation from container tags (OpenCV does not apply this). FFmpeg autorotates by default."""
    import json

    if not shutil.which("ffprobe"):
        return 0
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream_tags=rotate:stream_side_data=rotation",
        "-of",
        "json",
        str(video_path),
    ]
    try:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=15)
        if result.returncode != 0 or not result.stdout.strip():
            return 0
        data = json.loads(result.stdout)
        streams = data.get("streams") or []
        if not streams:
            return 0
        stream = streams[0]
        tags = stream.get("tags") or {}
        rotate = tags.get("rotate")
        if rotate is not None:
            return int(float(rotate)) % 360
        for item in stream.get("side_data_list") or []:
            if not isinstance(item, dict):
                continue
            rot = item.get("rotation")
            if rot is not None:
                return int(float(rot)) % 360
    except (ValueError, TypeError, subprocess.SubprocessError, OSError, json.JSONDecodeError):
        return 0
    return 0


def _opencv_sample_indices(frame_count: int, max_frames: int) -> list[int]:
    """Chronological, distinct frame indices. Never fabricates indices beyond the clip."""
    max_frames = max(1, int(max_frames))
    if frame_count <= 0:
        return list(range(max_frames))
    if frame_count == 1:
        return [0]
    if max_frames == 1:
        return [0]
    # Always span first→last so temporal heuristics get chronological separation.
    last = frame_count - 1
    if max_frames == 2:
        return [0, last]
    raw = [int(round(i * last / (max_frames - 1))) for i in range(max_frames)]
    # Preserve order while dropping duplicate index collisions on short clips.
    out: list[int] = []
    seen: set[int] = set()
    for idx in raw:
        clamped = min(last, max(0, idx))
        if clamped in seen:
            continue
        seen.add(clamped)
        out.append(clamped)
    if len(out) < 2 and last >= 1:
        return [0, last]
    return out


def _extract_with_opencv(
    video_path: Path,
    *,
    max_frames: int,
    rotation_degrees: int = 0,
) -> list[bytes]:
    if cv2 is None:
        return []

    from app.services.image_orientation import rotate_bgr

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        return []

    try:
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        frames: list[bytes] = []

        if frame_count <= 0:
            # Unknown length: sequential decode up to max_frames (no fabricated seeks).
            while len(frames) < max_frames:
                ok, frame = cap.read()
                if not ok or frame is None:
                    break
                frame = rotate_bgr(frame, rotation_degrees)
                ok, encoded = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                if ok:
                    frames.append(encoded.tobytes())
            return frames

        indices = _opencv_sample_indices(frame_count, max_frames)
        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ok, frame = cap.read()
            if not ok or frame is None:
                continue
            frame = rotate_bgr(frame, rotation_degrees)
            ok, encoded = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            if ok:
                frames.append(encoded.tobytes())
        return frames
    finally:
        cap.release()
