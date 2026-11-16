"""Orchestrate MUSIQ + OpenCV classical + experimental feedback."""

from __future__ import annotations

import math
import time
from typing import Any

from app.hybrid import (
    CLASSICAL_MAP_VERSION,
    classical_quality_from_bgr,
    color_criteria_from_bgr,
    decode_bgr_from_bytes,
    generate_hybrid_feedback,
)
from app.musiq_engine import (
    MUSIQ_MODEL_ID,
    MUSIQ_MODEL_VERSION,
    MUSIQ_SCALE,
    score_image_bytes,
)
from app.video_frames import extract_frames


def _mean_finite(values: list[float | None]) -> float | None:
    nums = [float(v) for v in values if isinstance(v, (int, float)) and math.isfinite(float(v))]
    if not nums:
        return None
    return float(sum(nums) / len(nums))


def _mean_dict(dicts: list[dict[str, Any]]) -> dict[str, float] | None:
    if not dicts:
        return None
    keys = set()
    for d in dicts:
        keys.update(d.keys())
    out: dict[str, float] = {}
    for key in keys:
        avg = _mean_finite([d.get(key) for d in dicts])
        if avg is not None:
            out[key] = avg
    return out or None


def evaluate_photo_bytes(content: bytes) -> dict[str, Any]:
    """Score one photo. Does not invent MUSIQ when the model is unavailable."""
    t0 = time.perf_counter()
    result: dict[str, Any] = {
        "media_type": "photo",
        "status": "ok",
        "musiq": None,
        "classical_map_version": CLASSICAL_MAP_VERSION,
        "criteria_raw": None,
        "criteria_q": None,
        "criteria_badge_equal_bin": None,
        "color": None,
        "experimental_feedback": None,
        "frames_analyzed": 1,
        "per_frame": None,
        "duration_ms": None,
        "error": None,
        "soft_score_applied_to_musiq": False,
        "production_payload_mutated": False,
        "temporal_quality": {
            "flickering": None,
            "motion_stability": None,
            "preserved_on_backend": True,
            "note": (
                "Flickering and Motion Stability stay on the ACCESS FastAPI "
                "media_evaluator path and are not computed by this worker."
            ),
        },
    }

    if not content:
        result["status"] = "error"
        result["error"] = "empty_body"
        result["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return result

    bgr = decode_bgr_from_bytes(content)
    if bgr is None:
        result["status"] = "error"
        result["error"] = "image_decode_failed"
        result["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return result

    try:
        classical = classical_quality_from_bgr(bgr)
        color = color_criteria_from_bgr(bgr)
        result["criteria_raw"] = classical.get("raw")
        result["criteria_q"] = classical.get("q")
        result["criteria_badge_equal_bin"] = classical.get("badge_equal_bin")
        result["color"] = color
        result["classical_map_version"] = classical.get("map_version", CLASSICAL_MAP_VERSION)
    except Exception as exc:  # noqa: BLE001
        result["status"] = "error"
        result["error"] = f"classical_failed: {exc}"
        result["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return result

    musiq = score_image_bytes(content)
    result["musiq"] = musiq
    if musiq.get("status") != "ok":
        result["status"] = "partial"
        result["error"] = musiq.get("error")

    result["experimental_feedback"] = generate_hybrid_feedback(
        criteria_q=result.get("criteria_q"),
        criteria_raw=result.get("criteria_raw"),
        color=result.get("color"),
        musiq_opq_raw=musiq.get("musiq_opq_raw"),
        musiq_status=musiq.get("status"),
    )
    result["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
    return result


def evaluate_video_bytes(
    content: bytes,
    *,
    ext: str = ".mp4",
    max_frames: int = 4,
) -> dict[str, Any]:
    """Sample frames, score each, aggregate. No invented MUSIQ; no temporal invent."""
    t0 = time.perf_counter()
    base: dict[str, Any] = {
        "media_type": "video",
        "status": "ok",
        "musiq": {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": None,
            "error": None,
            "aggregation": "mean_of_finite_frame_scores",
        },
        "classical_map_version": CLASSICAL_MAP_VERSION,
        "criteria_raw": None,
        "criteria_q": None,
        "criteria_badge_equal_bin": None,
        "color": None,
        "experimental_feedback": None,
        "frames_analyzed": 0,
        "per_frame": [],
        "duration_ms": None,
        "error": None,
        "soft_score_applied_to_musiq": False,
        "production_payload_mutated": False,
        "temporal_quality": {
            "flickering": None,
            "motion_stability": None,
            "preserved_on_backend": True,
            "note": (
                "Flickering and Motion Stability remain on the ACCESS FastAPI "
                "media_evaluator path. Worker returns frame aggregates only."
            ),
        },
    }

    if not content:
        base["status"] = "error"
        base["error"] = "empty_body"
        base["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return base

    frames = extract_frames(content, ext=ext, max_frames=max_frames)
    if not frames:
        base["status"] = "error"
        base["error"] = "no_frames_extracted"
        base["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return base

    per_frame: list[dict[str, Any]] = []
    q_list: list[dict[str, Any]] = []
    raw_list: list[dict[str, Any]] = []
    musiq_scores: list[float | None] = []
    musiq_statuses: list[str] = []

    for idx, frame in enumerate(frames):
        photo = evaluate_photo_bytes(frame)
        frame_rec = {
            "frame_index": idx,
            "status": photo.get("status"),
            "musiq_opq_raw": (photo.get("musiq") or {}).get("musiq_opq_raw"),
            "musiq_status": (photo.get("musiq") or {}).get("status"),
            "criteria_q": photo.get("criteria_q"),
            "criteria_badge_equal_bin": photo.get("criteria_badge_equal_bin"),
            "duration_ms": photo.get("duration_ms"),
            "error": photo.get("error"),
        }
        per_frame.append(frame_rec)
        if photo.get("criteria_q"):
            q_list.append(photo["criteria_q"])
        if photo.get("criteria_raw"):
            raw_list.append(photo["criteria_raw"])
        musiq_scores.append((photo.get("musiq") or {}).get("musiq_opq_raw"))
        musiq_statuses.append(str((photo.get("musiq") or {}).get("status") or "unavailable"))

    base["per_frame"] = per_frame
    base["frames_analyzed"] = len(frames)
    base["criteria_q"] = _mean_dict(q_list)
    base["criteria_raw"] = _mean_dict(raw_list)
    if base["criteria_q"]:
        from app.hybrid.classical import equal_bin_1_5

        base["criteria_badge_equal_bin"] = {
            k: equal_bin_1_5(v) for k, v in base["criteria_q"].items()
        }

    # Color from mid frame (same approach as production color-from-frames).
    mid = frames[len(frames) // 2]
    mid_bgr = decode_bgr_from_bytes(mid)
    if mid_bgr is not None:
        try:
            base["color"] = color_criteria_from_bgr(mid_bgr)
        except Exception as exc:  # noqa: BLE001
            base["color"] = {"error": str(exc)}

    agg = _mean_finite(musiq_scores)
    ok_count = sum(1 for s in musiq_statuses if s == "ok")
    if agg is not None and ok_count > 0:
        from app import musiq_engine as eng

        base["musiq"] = {
            "status": "ok",
            "musiq_opq_raw": agg,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": eng.engine_handle(),
            "error": None,
            "aggregation": "mean_of_finite_frame_scores",
            "frames_ok": ok_count,
            "frames_total": len(frames),
        }
        base["status"] = "ok" if ok_count == len(frames) else "partial"
    else:
        base["status"] = "partial"
        base["musiq"]["error"] = "no_finite_musiq_frame_scores"
        base["error"] = "no_finite_musiq_frame_scores"

    base["experimental_feedback"] = generate_hybrid_feedback(
        criteria_q=base.get("criteria_q"),
        criteria_raw=base.get("criteria_raw"),
        color=base.get("color") if isinstance(base.get("color"), dict) else None,
        musiq_opq_raw=(base.get("musiq") or {}).get("musiq_opq_raw"),
        musiq_status=(base.get("musiq") or {}).get("status"),
    )
    base["duration_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
    return base
