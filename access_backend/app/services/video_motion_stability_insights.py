"""Feedback-only video motion stability (optical flow bursts). Does not affect rubric scores."""

from __future__ import annotations

import tempfile
from pathlib import Path
from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

InsightDict = dict[str, str]


def _motion_settings() -> tuple[int, int, int]:
    try:
        from app.config import settings

        bursts = max(1, min(8, int(getattr(settings, "motion_insight_burst_count", 5))))
        per_burst = max(3, min(10, int(getattr(settings, "motion_insight_frames_per_burst", 6))))
        max_w = max(160, min(960, int(getattr(settings, "motion_insight_max_width", 480))))
        return bursts, per_burst, max_w
    except Exception:
        return 5, 6, 480


def _unavailable() -> InsightDict:
    return {
        "status": "unavailable",
        "headline": "Unavailable",
        "feedback": "Motion stability coaching could not be run on this video.",
    }


def _inconclusive(feedback: str) -> InsightDict:
    return {
        "status": "inconclusive",
        "headline": "Inconclusive",
        "feedback": feedback,
    }


def _resize_bgr(bgr: np.ndarray, max_width: int) -> np.ndarray:
    h, w = bgr.shape[:2]
    if w <= max_width:
        return bgr
    scale = max_width / float(w)
    new_h = max(1, int(h * scale))
    return cv2.resize(bgr, (max_width, new_h), interpolation=cv2.INTER_AREA)


def _texture_score(gray: np.ndarray) -> float:
    lap = cv2.Laplacian(gray, cv2.CV_64F)
    return float(lap.var())


def _pair_flow_metrics(gray_a: np.ndarray, gray_b: np.ndarray) -> dict[str, float] | None:
    if gray_a.shape != gray_b.shape:
        return None
    flow = cv2.calcOpticalFlowFarneback(
        gray_a,
        gray_b,
        None,
        pyr_scale=0.5,
        levels=3,
        winsize=15,
        iterations=3,
        poly_n=5,
        poly_sigma=1.2,
        flags=0,
    )
    fx = flow[..., 0]
    fy = flow[..., 1]
    mag = np.sqrt(fx * fx + fy * fy)
    ang = np.arctan2(fy, fx)
    mean_mag = float(np.mean(mag))
    std_mag = float(np.std(mag))
    cos_mean = float(np.mean(np.cos(ang)))
    sin_mean = float(np.mean(np.sin(ang)))
    direction_consistency = float(np.hypot(cos_mean, sin_mean))
    return {
        "mean_mag": mean_mag,
        "std_mag": std_mag,
        "direction_consistency": direction_consistency,
    }


def _analyze_burst(frames_bgr: list[np.ndarray], max_width: int) -> dict[str, Any] | None:
    if len(frames_bgr) < 2:
        return None
    resized = [_resize_bgr(f, max_width) for f in frames_bgr]
    grays = [cv2.cvtColor(f, cv2.COLOR_BGR2GRAY) for f in resized]
    if _texture_score(grays[0]) < 25.0:
        return {"kind": "low_texture"}

    pair_stats: list[dict[str, float]] = []
    mag_deltas: list[float] = []
    prev_mean = None
    for i in range(1, len(grays)):
        stats = _pair_flow_metrics(grays[i - 1], grays[i])
        if stats is None:
            continue
        pair_stats.append(stats)
        if prev_mean is not None:
            mag_deltas.append(abs(stats["mean_mag"] - prev_mean))
        prev_mean = stats["mean_mag"]

    if not pair_stats:
        return None

    mean_mags = [s["mean_mag"] for s in pair_stats]
    dir_cons = [s["direction_consistency"] for s in pair_stats]
    avg_mag = float(np.mean(mean_mags))
    mag_jitter = float(np.std(mean_mags))
    delta_jitter = float(np.mean(mag_deltas)) if mag_deltas else 0.0
    avg_dir = float(np.mean(dir_cons))

    return {
        "kind": "ok",
        "avg_mag": avg_mag,
        "mag_jitter": mag_jitter,
        "delta_jitter": delta_jitter,
        "avg_dir": avg_dir,
        "pairs": len(pair_stats),
    }


def _classify_burst(summary: dict[str, Any]) -> str:
    if summary.get("kind") == "low_texture":
        return "inconclusive"
    avg_mag = float(summary.get("avg_mag") or 0.0)
    mag_jitter = float(summary.get("mag_jitter") or 0.0)
    delta_jitter = float(summary.get("delta_jitter") or 0.0)
    avg_dir = float(summary.get("avg_dir") or 0.0)

    if avg_mag < 0.35:
        return "stable"
    if avg_dir >= 0.72 and avg_mag < 2.8 and mag_jitter < 0.55:
        return "smooth_pan"
    if mag_jitter >= 0.45 or delta_jitter >= 0.35 or (avg_mag >= 1.2 and avg_dir < 0.45):
        return "shake"
    return "inconclusive"


def _read_burst(cap: Any, start_index: int, count: int) -> list[np.ndarray]:
    frames: list[np.ndarray] = []
    cap.set(cv2.CAP_PROP_POS_FRAMES, max(0, start_index))
    for _ in range(count):
        ok, frame = cap.read()
        if not ok or frame is None:
            break
        frames.append(frame)
    return frames


def analyze_video_motion_stability_bytes(content: bytes, ext: str = ".mp4") -> InsightDict:
    if cv2 is None:
        return _unavailable()
    if not content:
        return _inconclusive("No video bytes were available for motion analysis.")

    burst_count, frames_per_burst, max_width = _motion_settings()
    ext = ext if ext.startswith(".") else f".{ext}"

    with tempfile.TemporaryDirectory(prefix="access_motion_") as tmp:
        video_path = Path(tmp) / f"clip{ext}"
        video_path.write_bytes(content)
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            return _inconclusive("The video could not be opened for motion analysis.")
        try:
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
            if total < frames_per_burst + 1:
                return _inconclusive(
                    "Clip is too short for consecutive-frame motion sampling. "
                    "This does not affect your official Motion Stability score."
                )

            usable_bursts = min(burst_count, max(1, total // frames_per_burst))
            if usable_bursts < 2:
                return _inconclusive(
                    "Not enough consecutive frames were available for a reliable motion summary."
                )

            span = max(0, total - frames_per_burst)
            start_indices = [
                int(round(span * i / max(1, usable_bursts - 1))) for i in range(usable_bursts)
            ]

            labels: list[str] = []
            decoded_bursts = 0
            for start in start_indices:
                burst_frames = _read_burst(cap, start, frames_per_burst)
                if len(burst_frames) < 2:
                    continue
                summary = _analyze_burst(burst_frames, max_width)
                if summary is None:
                    continue
                decoded_bursts += 1
                labels.append(_classify_burst(summary))

            if decoded_bursts == 0:
                return _inconclusive(
                    "Frame decoding or texture checks did not yield usable motion measurements."
                )
            if decoded_bursts < 2:
                return _inconclusive(
                    "Only one motion sample could be decoded. Results may not represent the full clip."
                )

            stable_like = sum(1 for lb in labels if lb in ("stable", "smooth_pan"))
            shake = sum(1 for lb in labels if lb == "shake")
            inconclusive = sum(1 for lb in labels if lb == "inconclusive")
            ratio_shake = shake / len(labels)
            ratio_stable = stable_like / len(labels)

            if inconclusive / len(labels) >= 0.75:
                return _inconclusive(
                    "Scene motion, low detail, or moving subjects made optical-flow motion "
                    "readings inconsistent. This check cannot separate camera shake from subject movement."
                )

            if ratio_shake >= 0.4:
                return {
                    "status": "possible_shake",
                    "headline": "Possible Camera Shake",
                    "feedback": "Irregular motion patterns appeared across consecutive-frame samples. "
                    "Try a slower pan, brace your phone, or use a tripod. Moving subjects can look similar to shake.",
                }

            if ratio_stable >= 0.55:
                headline = "Stable / Smooth Motion"
                if any(lb == "smooth_pan" for lb in labels):
                    feedback = (
                        "Camera motion looks relatively steady, with some smooth panning detected. "
                        "Optical flow cannot perfectly separate intentional movement from subject motion."
                    )
                else:
                    feedback = (
                        "Camera motion looks relatively steady across sampled consecutive frames. "
                        "This is coaching feedback only and does not change your official score."
                    )
                return {
                    "status": "stable_smooth",
                    "headline": headline,
                    "feedback": feedback,
                }

            return _inconclusive(
                "Mixed motion cues were detected. This may include panning, subject movement, or mild handheld motion. "
                "No single coaching label is reported."
            )
        finally:
            cap.release()


def motion_insight_debug_stats(content: bytes, ext: str = ".mp4") -> dict[str, Any]:
    """Test helper: burst labels and timing metadata (not stored on evaluations)."""
    import time

    t0 = time.perf_counter()
    insight = analyze_video_motion_stability_bytes(content, ext=ext)
    elapsed = time.perf_counter() - t0
    return {"insight": insight, "elapsed_sec": round(elapsed, 3)}
