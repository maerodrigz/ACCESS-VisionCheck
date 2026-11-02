"""Run production-equivalent quality scoring with a forced engine (validation only)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from tools.quality_validation.engines import EngineId, analyze_image_metrics

_PHOTO_EXT = frozenset({".jpg", ".jpeg", ".png", ".webp", ".bmp"})
_VIDEO_EXT = frozenset({".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"})


def media_type_for_path(path: Path) -> str | None:
    ext = path.suffix.lower()
    if ext in _PHOTO_EXT:
        return "photo"
    if ext in _VIDEO_EXT:
        return "video"
    return None


def evaluate_bytes_validation(
    content: bytes,
    *,
    file_name: str,
    engine: EngineId,
    video_sample_frames: int | None = None,
) -> dict[str, Any]:
    """
    Mirror media_evaluator photo/video scoring without DB, authenticity, or engine fallback.
    """
    ext = Path(file_name).suffix.lower()
    if ext in _VIDEO_EXT:
        return _evaluate_video(content, ext=ext, engine=engine, video_sample_frames=video_sample_frames)
    return _evaluate_photo(content, engine=engine)


def _evaluate_photo(content: bytes, *, engine: EngineId) -> dict[str, Any]:
    from app.services.media_evaluator import _build_payload, _photo_criteria, _quality_warnings

    metrics, err = analyze_image_metrics(content, engine)
    if metrics is None:
        return _failure_result(
            media_type="photo",
            engine=engine,
            error_code=err or "analysis_failed",
            frame_count=0,
        )

    criteria = _photo_criteria(metrics)
    warnings = _quality_warnings(metrics)
    payload = _build_payload(
        criteria,
        media_type="photo",
        quality_warnings=warnings,
        content=content,
        include_authenticity=False,
    )
    return _success_result(payload, engine=engine, raw_metrics=metrics, frame_metrics=[metrics], warnings=warnings)


def _evaluate_video(
    content: bytes,
    *,
    ext: str,
    engine: EngineId,
    video_sample_frames: int | None,
) -> dict[str, Any]:
    from app.services.ffmpeg_frames import extract_frames
    from app.services.media_evaluator import (
        _average_metrics,
        _build_payload,
        _flickering,
        _motion_stability,
        _photo_criteria,
        _quality_warnings,
        SCORING_ENGINE,
    )
    from app.services.efficientnet_b0_scorer import MODEL_ID

    max_frames = video_sample_frames
    frame_bytes = extract_frames(content, ext, max_frames=max_frames)
    sample_config = max_frames if max_frames is not None else _default_sample_count()

    if not frame_bytes:
        return _failure_result(
            media_type="video",
            engine=engine,
            error_code="frame_extraction_failed",
            frame_count=0,
            video_sample_frames=sample_config,
        )

    frame_metrics: list[dict[str, Any]] = []
    frame_errors: list[str] = []
    for idx, fb in enumerate(frame_bytes):
        m, err = analyze_image_metrics(fb, engine)
        if m is not None:
            frame_metrics.append(m)
        elif err:
            frame_errors.append(f"frame_{idx}:{err}")

    if not frame_metrics:
        return _failure_result(
            media_type="video",
            engine=engine,
            error_code=frame_errors[0] if frame_errors else "all_frames_failed",
            frame_count=len(frame_bytes),
            video_sample_frames=sample_config,
            detail="; ".join(frame_errors[:5]),
        )

    averaged = _average_metrics(frame_metrics)
    criteria = [
        *_photo_criteria(averaged),
        _flickering(frame_metrics),
        _motion_stability(frame_metrics),
    ]
    warnings = _quality_warnings(averaged)
    payload = _build_payload(
        criteria,
        media_type="video",
        quality_warnings=warnings,
        content=frame_bytes[len(frame_bytes) // 2],
        include_authenticity=False,
    )
    result = _success_result(
        payload,
        engine=engine,
        raw_metrics=averaged,
        frame_metrics=frame_metrics,
        warnings=warnings,
        frame_count=len(frame_bytes),
        frames_scored=len(frame_metrics),
        video_sample_frames=sample_config,
    )
    result["analysis"]["engine"] = SCORING_ENGINE
    result["analysis"]["model"] = MODEL_ID if engine == "efficientnet" else "opencv-heuristics"
    result["analysis"]["validation_engine"] = engine
    if frame_errors:
        result["partial_frame_errors"] = frame_errors
    return result


def _default_sample_count() -> int:
    try:
        from app.services.ffmpeg_frames import _default_sample_count as fn

        return int(fn())
    except Exception:
        return 4


def _success_result(
    payload: dict[str, Any],
    *,
    engine: EngineId,
    raw_metrics: dict[str, Any],
    frame_metrics: list[dict[str, Any]],
    warnings: list[str],
    frame_count: int = 1,
    frames_scored: int = 1,
    video_sample_frames: int | None = None,
) -> dict[str, Any]:
    criteria = payload.get("criteria") or []
    by_name = {c["name"]: c["score"] for c in criteria if isinstance(c, dict) and "name" in c}
    insufficient: list[str] = []
    for name in ("Flickering", "Motion Stability"):
        if name in by_name and frames_scored < 2:
            insufficient.append(f"{name}:limited_frame_samples")

    return {
        "analysis_status": "ok",
        "error_code": None,
        "engine": engine,
        "media_type": payload.get("media_type"),
        "overall_score": payload.get("overall_score"),
        "quality_level": payload.get("quality_level"),
        "criterion_scores": by_name,
        "raw_metrics": {k: raw_metrics[k] for k in raw_metrics if k not in ("width", "height")},
        "width": raw_metrics.get("width"),
        "height": raw_metrics.get("height"),
        "frame_count": frame_count,
        "frames_scored": frames_scored,
        "video_sample_frames": video_sample_frames,
        "quality_warnings": warnings,
        "insufficient_evidence_flags": insufficient,
        "scoring_model": payload.get("scoring_model"),
        "scoring_engine": payload.get("scoring_engine"),
        "legacy_overall_score": (payload.get("legacy") or {}).get("overall_score"),
    }


def _failure_result(
    *,
    media_type: str,
    engine: EngineId,
    error_code: str,
    frame_count: int,
    video_sample_frames: int | None = None,
    detail: str | None = None,
) -> dict[str, Any]:
    return {
        "analysis_status": "failed",
        "error_code": error_code,
        "error_detail": detail,
        "engine": engine,
        "media_type": media_type,
        "overall_score": None,
        "quality_level": None,
        "criterion_scores": {},
        "raw_metrics": {},
        "frame_count": frame_count,
        "frames_scored": 0,
        "video_sample_frames": video_sample_frames,
        "quality_warnings": [],
        "insufficient_evidence_flags": ["evaluation_failed"],
        "scoring_model": None,
        "scoring_engine": None,
        "legacy_overall_score": None,
    }
