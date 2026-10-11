"""Extract video frames via FFmpeg (preferred) or OpenCV VideoCapture fallback."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

DEFAULT_SAMPLE_COUNT = 6


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None


def extract_frames(content: bytes, ext: str, *, max_frames: int = DEFAULT_SAMPLE_COUNT) -> list[bytes]:
    ext = ext if ext.startswith(".") else f".{ext}"
    if not content:
        return []

    with tempfile.TemporaryDirectory(prefix="access_frames_") as tmp:
        tmp_path = Path(tmp)
        video_path = tmp_path / f"input{ext}"
        video_path.write_bytes(content)

        if ffmpeg_available():
            frames = _extract_with_ffmpeg(video_path, tmp_path, max_frames=max_frames)
            if frames:
                return frames

        if cv2 is not None:
            return _extract_with_opencv(video_path, max_frames=max_frames)

    return []


def _extract_with_ffmpeg(video_path: Path, tmp_path: Path, *, max_frames: int) -> list[bytes]:
    """Sample frames across the clip (one ffprobe + one ffmpeg when possible)."""
    duration = _probe_duration(video_path)
    if duration <= 0:
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


def _extract_with_opencv(video_path: Path, *, max_frames: int) -> list[bytes]:
    if cv2 is None:
        return []

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        return []

    try:
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        if frame_count <= 0:
            indices = list(range(max_frames))
        else:
            step = max(1, frame_count // max_frames)
            indices = [min(frame_count - 1, step * i) for i in range(max_frames)]

        frames: list[bytes] = []
        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ok, frame = cap.read()
            if not ok or frame is None:
                continue
            ok, encoded = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            if ok:
                frames.append(encoded.tobytes())
        return frames
    finally:
        cap.release()
