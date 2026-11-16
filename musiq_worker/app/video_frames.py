"""Bounded video frame sampling with temp-file cleanup."""

from __future__ import annotations

import logging
import shutil
import subprocess
import tempfile
from pathlib import Path

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

logger = logging.getLogger(__name__)

_VIDEO_EXTS = {".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"}


def normalize_ext(ext: str | None) -> str:
    if not ext:
        return ".mp4"
    e = ext if ext.startswith(".") else f".{ext}"
    return e.lower() if e.lower() in _VIDEO_EXTS else ".mp4"


def extract_frames(content: bytes, *, ext: str = ".mp4", max_frames: int = 4) -> list[bytes]:
    """Sample up to max_frames JPEG frames. Always cleans temp dirs."""
    if not content or max_frames < 1:
        return []
    max_frames = max(1, min(8, int(max_frames)))
    ext = normalize_ext(ext)

    with tempfile.TemporaryDirectory(prefix="musiq_worker_frames_") as tmp:
        tmp_path = Path(tmp)
        video_path = tmp_path / f"input{ext}"
        video_path.write_bytes(content)
        if shutil.which("ffmpeg"):
            frames = _ffmpeg_frames(video_path, tmp_path, max_frames=max_frames)
            if frames:
                return frames
        if cv2 is not None:
            return _opencv_frames(video_path, max_frames=max_frames)
    return []


def _probe_duration(video_path: Path) -> float:
    if not shutil.which("ffprobe"):
        return 0.0
    try:
        out = subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(video_path),
            ],
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
        return max(0.0, float(out.decode("utf-8", errors="ignore").strip() or 0.0))
    except Exception:  # noqa: BLE001
        return 0.0


def _ffmpeg_frames(video_path: Path, tmp_path: Path, *, max_frames: int) -> list[bytes]:
    duration = _probe_duration(video_path)
    if duration <= 0:
        times = [0.0]
    else:
        step = duration / max(max_frames, 1)
        times = [min(max(0.0, duration - 0.05), step * i) for i in range(max_frames)]
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
            subprocess.run(cmd, check=True, timeout=60)
            if out_path.is_file() and out_path.stat().st_size > 0:
                frames.append(out_path.read_bytes())
        except Exception as exc:  # noqa: BLE001
            logger.warning("ffmpeg frame %s failed: %s", i, exc)
    return frames


def _opencv_frames(video_path: Path, *, max_frames: int) -> list[bytes]:
    if cv2 is None:
        return []
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        return []
    try:
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        frames: list[bytes] = []
        if total <= 0:
            ok, frame = cap.read()
            if ok and frame is not None:
                ok2, buf = cv2.imencode(".jpg", frame)
                if ok2:
                    frames.append(buf.tobytes())
            return frames
        indices = [
            min(total - 1, max(0, int(round(i * (total - 1) / max(max_frames - 1, 1)))))
            for i in range(max_frames)
        ]
        seen: set[int] = set()
        for idx in indices:
            if idx in seen:
                continue
            seen.add(idx)
            cap.set(cv2.CAP_PROP_POS_FRAMES, float(idx))
            ok, frame = cap.read()
            if not ok or frame is None:
                continue
            ok2, buf = cv2.imencode(".jpg", frame)
            if ok2:
                frames.append(buf.tobytes())
        return frames
    finally:
        cap.release()
