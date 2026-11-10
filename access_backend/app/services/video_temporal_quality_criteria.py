"""Classical CV Motion Stability and Flickering for sampled video frames.

Experimental heuristics only. Operates on FFmpeg-sampled JPEG/PNG frame bytes.
Does not use EfficientNet brightness/sharpness heads. Thresholds are unvalidated
diagnostics for documentation-oriented screening, not scientific IQA claims.

Sparse sampling (often ~4 frames) limits sensitivity to high-frequency flicker
and short shake bursts between samples.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

ESTIMATE_KIND = "heuristic_experimental"

# --- Experimental thresholds (documented; not human-validated) ---
_MAX_WIDTH = 320
_MIN_TEXTURE_VAR = 20.0
_MIN_TRACKED_POINTS = 8
_LK_WIN = (21, 21)
_LK_MAX_LEVEL = 3
_FEATURE_MAX = 80
_FEATURE_QUALITY = 0.01
_FEATURE_MIN_DIST = 8

# Motion: prefer jitter / direction inconsistency over absolute magnitude.
_MOTION_JITTER_EXCELLENT = 0.35  # px (resized space)
_MOTION_JITTER_GOOD = 0.90
_MOTION_JITTER_FAIR = 1.80
_MOTION_JITTER_POOR = 3.50
_PAN_DIR_CONSISTENCY = 0.70
_PAN_MAG_CAP = 12.0  # intentional pans can be large if direction-stable

# Flicker: OpenCV mean luminance in 0–1.
_FLICKER_MEAN_DELTA_EXCELLENT = 0.025
_FLICKER_MEAN_DELTA_GOOD = 0.06
_FLICKER_MEAN_DELTA_FAIR = 0.12
_FLICKER_MEAN_DELTA_POOR = 0.22
_MONOTONIC_FRAC = 0.75  # fraction of consecutive deltas with same sign → gradual ramp
_OSCILLATION_SIGN_FLIPS_MIN = 1


def _na(name: str, explanation: str, suggestion: str = "") -> dict[str, Any]:
    return {
        "name": name,
        "score": None,
        "label": "N/A",
        "explanation": explanation,
        "suggestion": suggestion or "No reliable estimate is available for this clip sample.",
        "available": False,
        "estimate_kind": ESTIMATE_KIND,
        "high_is_good": True,
    }


def _scored(
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


def _decode_gray(frame: bytes) -> np.ndarray | None:
    if cv2 is None or not frame:
        return None
    arr = np.frombuffer(frame, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None or bgr.size == 0:
        return None
    h, w = bgr.shape[:2]
    if w > _MAX_WIDTH:
        scale = _MAX_WIDTH / float(w)
        bgr = cv2.resize(bgr, (_MAX_WIDTH, max(1, int(h * scale))), interpolation=cv2.INTER_AREA)
    return cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)


def _pair_motion(gray_a: np.ndarray, gray_b: np.ndarray) -> dict[str, float] | None:
    if gray_a.shape != gray_b.shape:
        return None
    if float(cv2.Laplacian(gray_a, cv2.CV_64F).var()) < _MIN_TEXTURE_VAR:
        return None

    pts = cv2.goodFeaturesToTrack(
        gray_a,
        maxCorners=_FEATURE_MAX,
        qualityLevel=_FEATURE_QUALITY,
        minDistance=_FEATURE_MIN_DIST,
        blockSize=7,
    )
    if pts is None or len(pts) < _MIN_TRACKED_POINTS:
        return None

    nxt, status, _err = cv2.calcOpticalFlowPyrLK(
        gray_a,
        gray_b,
        pts,
        None,
        winSize=_LK_WIN,
        maxLevel=_LK_MAX_LEVEL,
        criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 20, 0.03),
    )
    if nxt is None or status is None:
        return None
    ok = status.reshape(-1) == 1
    if int(ok.sum()) < _MIN_TRACKED_POINTS:
        return None

    prev = pts.reshape(-1, 2)[ok]
    cur = nxt.reshape(-1, 2)[ok]
    flow = cur - prev
    mag = np.sqrt((flow[:, 0] ** 2) + (flow[:, 1] ** 2))
    ang = np.arctan2(flow[:, 1], flow[:, 0])
    med_mag = float(np.median(mag))
    cos_m = float(np.mean(np.cos(ang)))
    sin_m = float(np.mean(np.sin(ang)))
    dir_consistency = float(np.hypot(cos_m, sin_m))
    # Residual after subtracting median translation: local inconsistency / shake.
    med_flow = np.median(flow, axis=0)
    residual = flow - med_flow
    residual_rms = float(np.sqrt(np.mean(residual[:, 0] ** 2 + residual[:, 1] ** 2)))
    return {
        "median_mag": med_mag,
        "dir_consistency": dir_consistency,
        "residual_rms": residual_rms,
        "tracked": float(ok.sum()),
    }


def analyze_motion_stability_from_frames(frame_bytes: list[bytes]) -> dict[str, Any]:
    name = "Motion Stability"
    if cv2 is None:
        return _na(name, "Motion stability estimate unavailable (OpenCV missing).")
    if len(frame_bytes) < 2:
        return _na(
            name,
            "Fewer than two sampled frames; motion stability is not scored.",
            "Record a slightly longer clip so more frames can be sampled.",
        )

    grays: list[np.ndarray] = []
    for fb in frame_bytes:
        g = _decode_gray(fb)
        if g is not None:
            grays.append(g)
    if len(grays) < 2:
        return _na(name, "Could not decode enough frames for motion estimation.")

    pair_stats: list[dict[str, float]] = []
    for i in range(1, len(grays)):
        stats = _pair_motion(grays[i - 1], grays[i])
        if stats is not None:
            pair_stats.append(stats)

    if not pair_stats:
        return _na(
            name,
            "Not enough reliable feature tracks between sampled frames "
            "(low texture or tracking failure). Score withheld.",
            "Use a textured scene and a steadier hold if possible.",
        )

    mags = [p["median_mag"] for p in pair_stats]
    dirs = [p["dir_consistency"] for p in pair_stats]
    residuals = [p["residual_rms"] for p in pair_stats]
    avg_mag = float(np.mean(mags))
    avg_dir = float(np.mean(dirs))
    # Median residual resists occasional LK outliers on sparse samples.
    avg_residual = float(np.median(residuals))
    mag_jitter = float(np.std(mags)) if len(mags) > 1 else 0.0
    # Instability: temporal mag jitter + robust residual. Direction-stable pans
    # emphasize mag_jitter so constant-speed translation is not treated as shake.
    if avg_dir >= _PAN_DIR_CONSISTENCY and avg_mag <= _PAN_MAG_CAP:
        instability = float(mag_jitter + 0.25 * avg_residual)
    else:
        instability = max(mag_jitter, avg_residual * 0.85)

    if instability <= _MOTION_JITTER_EXCELLENT and avg_mag < 1.2:
        score = 5
        explanation = (
            "Sampled frames show little camera jitter. Experimental heuristic "
            "based on sparse feature tracking between FFmpeg samples."
        )
        suggestion = "Maintain this steady shooting technique."
    elif (
        avg_dir >= _PAN_DIR_CONSISTENCY
        and avg_mag >= 0.4
        and instability <= _MOTION_JITTER_GOOD
    ):
        score = 4
        explanation = (
            "Motion looks like a relatively smooth directional move (possible pan) "
            "rather than erratic shake. Experimental heuristic; sparse sampling limits certainty."
        )
        suggestion = "Keep pans slow and even for documentation clips."
    elif instability <= _MOTION_JITTER_GOOD:
        score = 4
        explanation = (
            "Mild camera movement between sampled frames. Experimental heuristic."
        )
        suggestion = "Brace your elbows or slow down camera moves."
    elif instability <= _MOTION_JITTER_FAIR:
        score = 3
        explanation = (
            "Noticeable inter-frame camera movement or jitter in the sampled frames. "
            "Experimental heuristic."
        )
        suggestion = "Use a steadier grip or a tripod when possible."
    elif instability <= _MOTION_JITTER_POOR:
        score = 2
        explanation = (
            "Strong erratic motion between sampled frames. Experimental heuristic; "
            "not a full optical-stabilization analysis."
        )
        suggestion = "Stabilize the camera; avoid sudden shakes while recording."
    else:
        score = 1
        explanation = (
            "Very unstable camera motion across sampled frames. Experimental heuristic."
        )
        suggestion = "Re-record with a tripod or gimbal if documentation clarity matters."

    return _scored(name, score, explanation, suggestion)


def analyze_flickering_from_frames(frame_bytes: list[bytes]) -> dict[str, Any]:
    name = "Flickering"
    if cv2 is None:
        return _na(name, "Flickering estimate unavailable (OpenCV missing).")
    if len(frame_bytes) < 2:
        return _na(
            name,
            "Fewer than two sampled frames; flickering is not scored.",
            "Record a slightly longer clip so more frames can be sampled.",
        )

    luminances: list[float] = []
    for fb in frame_bytes:
        gray = _decode_gray(fb)
        if gray is None:
            continue
        luminances.append(float(np.mean(gray)) / 255.0)

    if len(luminances) < 2:
        return _na(name, "Could not decode enough frames for luminance flicker analysis.")

    deltas = [luminances[i] - luminances[i - 1] for i in range(1, len(luminances))]
    abs_deltas = [abs(d) for d in deltas]
    mean_abs = float(np.mean(abs_deltas))
    signs = [1 if d > 1e-4 else (-1 if d < -1e-4 else 0) for d in deltas]
    nonzero = [s for s in signs if s != 0]
    if len(nonzero) >= 2:
        flips = sum(1 for i in range(1, len(nonzero)) if nonzero[i] != nonzero[i - 1])
        same_sign_frac = max(
            nonzero.count(1) / len(nonzero),
            nonzero.count(-1) / len(nonzero),
        )
    else:
        flips = 0
        same_sign_frac = 1.0

    gradual = same_sign_frac >= _MONOTONIC_FRAC and flips == 0
    oscillating = flips >= _OSCILLATION_SIGN_FLIPS_MIN and mean_abs >= _FLICKER_MEAN_DELTA_GOOD

    # Gradual exposure ramps: soften effective delta so ordinary fades are not "flicker".
    effective = mean_abs
    if gradual and not oscillating:
        effective = mean_abs * 0.45

    if effective <= _FLICKER_MEAN_DELTA_EXCELLENT:
        score = 5
        explanation = (
            "Sampled-frame luminance stays relatively steady. Experimental heuristic "
            "using OpenCV mean brightness on FFmpeg samples (not EfficientNet)."
        )
        suggestion = "Maintain this stable lighting when recording."
    elif gradual and effective <= _FLICKER_MEAN_DELTA_GOOD:
        score = 4
        explanation = (
            "Luminance changes look more like a gradual exposure or scene brightness "
            "shift than rapid flicker. Experimental heuristic; sparse sampling limits certainty."
        )
        suggestion = "Lock exposure if your camera allows, when documentation needs stable brightness."
    elif effective <= _FLICKER_MEAN_DELTA_GOOD and not oscillating:
        score = 4
        explanation = (
            "Minor luminance variation between sampled frames. Experimental heuristic."
        )
        suggestion = "Keep lighting continuous when possible."
    elif effective <= _FLICKER_MEAN_DELTA_FAIR:
        score = 3
        explanation = (
            "Moderate frame-to-frame brightness changes in the samples"
            + (" with oscillating pattern." if oscillating else ".")
            + " Experimental heuristic."
        )
        suggestion = "Use continuous lighting and avoid flickering sources."
    elif effective <= _FLICKER_MEAN_DELTA_POOR:
        score = 2
        explanation = (
            "Large luminance swings between sampled frames"
            + (" consistent with flicker-like oscillation." if oscillating else ".")
            + " Experimental heuristic."
        )
        suggestion = "Avoid strobing lights and unlock/relock exposure carefully."
    else:
        score = 1
        explanation = (
            "Extreme sampled-frame brightness alternation. Experimental heuristic; "
            "not a calibrated flicker meter."
        )
        suggestion = "Re-record under stable continuous lighting."

    return _scored(name, score, explanation, suggestion)


def analyze_temporal_video_criteria(frame_bytes: list[bytes]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return (Flickering, Motion Stability) criterion dicts for the video rubric order."""
    return (
        analyze_flickering_from_frames(frame_bytes),
        analyze_motion_stability_from_frames(frame_bytes),
    )
