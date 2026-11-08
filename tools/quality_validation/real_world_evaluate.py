"""Production-equivalent local quality scoring. No DB, no AI detector, no Gemini."""

from __future__ import annotations

from typing import Any

from tools.quality_validation.real_world_schema import PHOTO_CRITERIA, VIDEO_CRITERIA


class SafetyViolation(RuntimeError):
    """Raised if quality validation accidentally reaches forbidden services."""


def _forbid_ai(*_args: Any, **_kwargs: Any) -> None:
    raise SafetyViolation("AI content detection is forbidden in quality validation.")


def _forbid_db(*_args: Any, **_kwargs: Any) -> None:
    raise SafetyViolation("Database writes are forbidden in quality validation.")


def evaluate_production_quality(
    content: bytes,
    *,
    file_name: str,
) -> dict[str, Any]:
    """
    Call the live media_evaluator quality path with authenticity disabled.
    Failures stay failures: no 0.5 placeholders.
    """
    from unittest.mock import patch

    from app.services.media_evaluator import evaluate_bytes
    from app.services.quality_score_display import evaluation_failed

    if not content:
        return _failed("empty_input", file_name)

    with (
        patch("app.services.media_evaluator.detect_ai_generated", side_effect=_forbid_ai),
        patch("app.services.media_evaluator.detect_ai_generated_from_frames", side_effect=_forbid_ai),
        patch("app.crud.evaluation.create_evaluation", side_effect=_forbid_db),
        patch("app.database.SessionLocal", side_effect=_forbid_db),
    ):
        payload = evaluate_bytes(content, file_name=file_name, include_authenticity=False)

    if payload is None or evaluation_failed(payload):
        reason = None
        if isinstance(payload, dict):
            analysis = payload.get("analysis") if isinstance(payload.get("analysis"), dict) else {}
            reason = analysis.get("fail_reason") or payload.get("ai_feedback")
        return _failed("quality_evaluation_failed", file_name, detail=reason)

    analysis = payload.get("analysis") if isinstance(payload.get("analysis"), dict) else {}
    criteria = payload.get("criteria") if isinstance(payload.get("criteria"), list) else []
    by_name = {
        str(row.get("name")): row.get("score")
        for row in criteria
        if isinstance(row, dict) and row.get("name") is not None and row.get("score") is not None
    }
    media_type = str(payload.get("media_type") or "")
    expected = VIDEO_CRITERIA if media_type == "video" else PHOTO_CRITERIA
    missing = [name for name in expected if name not in by_name]
    overall = payload.get("overall_score")
    if overall is None or missing:
        return _failed(
            "incomplete_quality_payload",
            file_name,
            detail=f"missing criteria: {missing}" if missing else "missing overall",
            extra={
                "quality_engine": analysis.get("quality_engine"),
                "opencv_fallback": bool(analysis.get("opencv_fallback")),
            },
        )

    return {
        "analysis_status": "ok",
        "error_code": None,
        "error_detail": None,
        "media_type": media_type,
        "overall_score": overall,
        "system_overall_is_mean_of_criteria": True,
        "quality_level": payload.get("quality_level"),
        "criterion_scores": by_name,
        "quality_engine": analysis.get("quality_engine"),
        "opencv_fallback": bool(analysis.get("opencv_fallback")),
        "efficientnet_used": bool(analysis.get("efficientnet_used")),
        "ffmpeg_used": bool(analysis.get("ffmpeg_used")),
        "frames_analyzed": analysis.get("frames_analyzed"),
        "scoring_model": payload.get("scoring_model"),
        "scoring_engine": payload.get("scoring_engine"),
        "evaluation_status": payload.get("evaluation_status"),
        "ai_detection_invoked": False,
        "gemini_invoked": False,
        "database_written": False,
    }


def _failed(code: str, file_name: str, *, detail: str | None = None, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    row = {
        "analysis_status": "failed",
        "error_code": code,
        "error_detail": detail,
        "file_name": file_name,
        "overall_score": None,
        "criterion_scores": {},
        "quality_engine": None,
        "opencv_fallback": False,
        "frames_analyzed": None,
        "scoring_model": None,
        "scoring_engine": None,
        "ai_detection_invoked": False,
        "gemini_invoked": False,
        "database_written": False,
    }
    if extra:
        row.update(extra)
    return row
