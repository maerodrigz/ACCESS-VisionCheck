"""Online media evaluation: EfficientNet-B0 scoring + FFmpeg video frames."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

from app.services.efficientnet_b0_scorer import MODEL_ID, analyze_image_bytes as efficientnet_analyze
from app.services.efficientnet_b0_scorer import efficientnet_available, ensure_weights
from app.services.ffmpeg_frames import extract_frames, ffmpeg_available
from app.services.media_upload_config import DEFAULT_VIDEO_EXTENSIONS
from app.services.image_quality import legacy_scores_from_payload, parse_client_payload
from app.services.ai_authenticity_detector import detect_ai_generated, detect_ai_generated_from_frames
from app.services.integrity_evaluation_policy import (
    apply_integrity_evaluation_policy,
    finalize_member_evaluation_payload,
)
from app.services.opencv_quality import analyze_image_bytes as opencv_analyze
from app.services.opencv_quality import opencv_available
from app.services.supplementary_quality_insights import (
    build_photo_supplementary_insights,
    build_video_supplementary_insights,
)


SCORING_ENGINE = "efficientnet-b0+ffmpeg"
QUALITY_ENGINE_EFFICIENTNET = "efficientnet-b0"
QUALITY_ENGINE_OPENCV = "opencv"

_PRACTICE_VIDEO_EXTENSIONS = frozenset(DEFAULT_VIDEO_EXTENSIONS)
_PHOTO_CRITERION_NAMES = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)
_VIDEO_EXTRA_CRITERION_NAMES = ("Flickering", "Motion Stability")


def preferred_quality_engine() -> str | None:
    if efficientnet_available() and ensure_weights():
        return QUALITY_ENGINE_EFFICIENTNET
    if opencv_available():
        return QUALITY_ENGINE_OPENCV
    return None


def analyze_image_for_engine(content: bytes, engine: str) -> dict[str, Any] | None:
    if engine == QUALITY_ENGINE_EFFICIENTNET:
        if efficientnet_available() and ensure_weights():
            return efficientnet_analyze(content)
        return None
    if engine == QUALITY_ENGINE_OPENCV:
        if opencv_available():
            return opencv_analyze(content)
        return None
    return None


def resolve_quality_engine_for_bytes(content: bytes) -> tuple[dict[str, Any] | None, str | None, bool]:
    """
    Returns (metrics, engine_used, opencv_fallback).
    Tries EfficientNet first; OpenCV only if EfficientNet is unavailable or fails.
    """
    preferred = preferred_quality_engine()
    if preferred == QUALITY_ENGINE_EFFICIENTNET:
        metrics = analyze_image_for_engine(content, QUALITY_ENGINE_EFFICIENTNET)
        if metrics is not None:
            return metrics, QUALITY_ENGINE_EFFICIENTNET, False
        if opencv_available():
            metrics = analyze_image_for_engine(content, QUALITY_ENGINE_OPENCV)
            if metrics is not None:
                return metrics, QUALITY_ENGINE_OPENCV, True
        return None, None, False
    if preferred == QUALITY_ENGINE_OPENCV:
        metrics = analyze_image_for_engine(content, QUALITY_ENGINE_OPENCV)
        return (metrics, QUALITY_ENGINE_OPENCV, False) if metrics else (None, None, False)
    return None, None, False


def deferred_authenticity_preview() -> dict[str, Any]:
    """Quality-only preview: authenticity runs on saved-media background pipeline."""
    return {
        "analysis_status": "deferred",
        "is_final": False,
        "requires_review": False,
        "detail": "AI authenticity risk will be assessed when you save this submission.",
    }


def is_deferred_authenticity_preview(ai_detection: dict[str, Any] | None) -> bool:
    if not isinstance(ai_detection, dict):
        return False
    if str(ai_detection.get("analysis_status", "")).lower() == "deferred":
        return True
    if ai_detection.get("is_final") is False:
        return True
    return False


def _apply_preview_integrity_policy(payload: dict[str, Any]) -> dict[str, Any]:
    """Preview scores only; no final authenticity or XP eligibility."""
    out = dict(payload)
    out["authenticity_deferred"] = True
    out["show_quality_feedback"] = True
    out["quality_provisional"] = True
    out["xp_eligible"] = False
    out["xp_multiplier"] = 0.0
    out["xp_pending"] = True
    out["member_integrity_message"] = (
        "Technical quality scores are ready. AI authenticity risk is assessed when you save."
    )
    legacy = out.get("legacy") if isinstance(out.get("legacy"), dict) else {}
    overall = float(legacy.get("overall_score", 0))
    out["xp_points_preview"] = max(0, int(round(overall * 100)))
    return out


def _analyze_image(content: bytes) -> dict[str, Any] | None:
    metrics, _engine, _fallback = resolve_quality_engine_for_bytes(content)
    return metrics


def evaluate_authenticity_bytes(content: bytes, *, file_name: str = "") -> dict[str, Any] | None:
    """PROBE + provenance only (no EfficientNet / quality re-score)."""
    if not content:
        return None
    ext = Path(file_name or "").suffix.lower()
    if ext in _PRACTICE_VIDEO_EXTENSIONS:
        frame_bytes = extract_frames(content, ext)
        if not frame_bytes:
            return None
        return detect_ai_generated_from_frames(
            frame_bytes,
            file_name=file_name,
            video_content=content,
            video_ext=ext,
        )
    return detect_ai_generated(content, file_name=file_name)


def evaluate_bytes(
    content: bytes,
    *,
    file_name: str = "",
    include_authenticity: bool = True,
) -> dict[str, Any] | None:
    ext = Path(file_name or "").suffix.lower()
    if ext in _PRACTICE_VIDEO_EXTENSIONS:
        return evaluate_video(content, ext=ext, file_name=file_name, include_authenticity=include_authenticity)
    return evaluate_photo(content, file_name=file_name, include_authenticity=include_authenticity)


def evaluate_photo(content: bytes, *, file_name: str = "", include_authenticity: bool = True) -> dict[str, Any] | None:
    metrics, engine, opencv_fallback = resolve_quality_engine_for_bytes(content)
    if metrics is None:
        return None
    criteria = _photo_criteria(metrics)
    warnings = _quality_warnings(metrics)
    supplementary = build_photo_supplementary_insights(content)
    return _build_payload(
        criteria,
        media_type="photo",
        quality_warnings=warnings,
        content=content,
        file_name=file_name,
        include_authenticity=include_authenticity,
        supplementary_insights=supplementary,
        quality_engine=engine,
        opencv_fallback=opencv_fallback,
        frames_analyzed=1,
    )


def evaluate_video(
    content: bytes,
    *,
    ext: str,
    file_name: str = "",
    include_authenticity: bool = True,
) -> dict[str, Any] | None:
    frame_bytes = extract_frames(content, ext)
    if not frame_bytes:
        return None

    first, engine, opencv_fallback = resolve_quality_engine_for_bytes(frame_bytes[0])
    if first is None or engine is None:
        return None

    frame_metrics = [first]
    rest = frame_bytes[1:]
    if rest:
        workers = min(4, max(1, len(rest)))

        def _score_frame(frame: bytes) -> dict[str, Any] | None:
            return analyze_image_for_engine(frame, engine)

        with ThreadPoolExecutor(max_workers=workers) as pool:
            pinned = list(pool.map(_score_frame, rest))
        frame_metrics.extend(m for m in pinned if m is not None)
    if not frame_metrics:
        return None

    averaged = _average_metrics(frame_metrics)
    criteria = [
        *_photo_criteria(averaged),
        _flickering(frame_metrics),
        _motion_stability(frame_metrics),
    ]
    warnings = _quality_warnings(averaged)
    supplementary = build_video_supplementary_insights(
        frame_bytes,
        video_content=content,
        video_ext=ext,
    )
    sample_frame = frame_bytes[len(frame_bytes) // 2]
    ai_payload = (
        detect_ai_generated_from_frames(
            frame_bytes,
            file_name=file_name,
            video_content=content,
            video_ext=ext,
        )
        if include_authenticity
        else deferred_authenticity_preview()
    )
    payload = _build_payload(
        criteria,
        media_type="video",
        quality_warnings=warnings,
        content=sample_frame,
        file_name=file_name,
        ai_detection=ai_payload,
        include_authenticity=include_authenticity,
        supplementary_insights=supplementary,
        quality_engine=engine,
        opencv_fallback=opencv_fallback,
        frames_analyzed=len(frame_metrics),
    )
    return payload


def merge_client_gemini(server_payload: dict[str, Any], client_raw: str | None) -> dict[str, Any]:
    """Keep authoritative EfficientNet scores; merge Gemini narrative from client metadata."""
    client = parse_client_payload(client_raw)
    if not client:
        return server_payload

    merged = dict(server_payload)
    gemini = client.get("gemini_feedback")
    if isinstance(gemini, dict):
        merged["gemini_feedback"] = gemini

    if not merged.get("show_quality_feedback", True):
        return finalize_member_evaluation_payload(merged)

    if isinstance(gemini, dict):
        explanation = gemini.get("explanation")
        if explanation:
            merged["ai_feedback"] = explanation
        tips = gemini.get("tips")
        if isinstance(tips, list) and tips:
            merged["improvement_suggestions"] = "\n".join(f"• {t}" for t in tips if t)
    elif client.get("ai_feedback"):
        merged["ai_feedback"] = client["ai_feedback"]
    if client.get("improvement_suggestions"):
        merged["improvement_suggestions"] = client["improvement_suggestions"]
    return finalize_member_evaluation_payload(merged)


def scores_from_payload(payload: dict[str, Any]) -> dict[str, float] | None:
    from app.services.quality_score_display import evaluation_failed

    if evaluation_failed(payload):
        return None
    scores = legacy_scores_from_payload(payload)
    if not scores or scores.get("overall_score") is None:
        return None
    return scores


def preview_quality_complete(payload: dict[str, Any] | None) -> bool:
    """True when preview JSON has a full measured rubric (not a placeholder)."""
    from app.services.quality_score_display import evaluation_failed

    if not isinstance(payload, dict) or evaluation_failed(payload):
        return False
    criteria = payload.get("criteria")
    if not isinstance(criteria, list) or not criteria:
        return False
    names = {str(c.get("name")) for c in criteria if isinstance(c, dict)}
    required = set(_PHOTO_CRITERION_NAMES)
    media_type = str(payload.get("media_type") or "").lower()
    if media_type == "video":
        required.update(_VIDEO_EXTRA_CRITERION_NAMES)
    if not required.issubset(names):
        return False
    overall = payload.get("overall_score")
    if not isinstance(overall, (int, float)) or float(overall) <= 0:
        return False
    if not (payload.get("scoring_engine") or payload.get("scoring_model")):
        return False
    legacy = payload.get("legacy")
    if not isinstance(legacy, dict) or legacy.get("overall_score") in (None,):
        return False
    try:
        if float(legacy.get("overall_score", 0)) <= 0:
            return False
    except (TypeError, ValueError):
        return False
    return True


def _photo_criteria(m: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        _criterion("Sharpness", _soft_score(m["sharpness"]), high_is_good=True),
        _criterion("Blur", _soft_score(1 - m["blur"]), high_is_good=False),
        _criterion("Noise", _soft_score(1 - min(m["noise"], 0.85)), high_is_good=False),
        _criterion("Brightness", _soft_score(_brightness_metric(m["brightness"]))),
        _criterion("Contrast", _soft_score(min(m["contrast"], 1.0))),
        _criterion("Blocking Artifacts", _soft_score(1 - m["blocking_artifacts"]), high_is_good=False),
        _criterion("Ringing Artifacts", _soft_score(1 - m["ringing_artifacts"]), high_is_good=False),
    ]


def _flickering(frames: list[dict[str, Any]]) -> dict[str, Any]:
    if len(frames) < 2:
        return _criterion(
            "Flickering",
            4,
            explanation="Limited frame samples; no significant flicker detected.",
            suggestion="Keep lighting consistent while recording.",
        )
    flicker = sum(abs(frames[i]["brightness"] - frames[i - 1]["brightness"]) for i in range(1, len(frames))) / (
        len(frames) - 1
    )
    score = _soft_score(max(0.0, min(1.0, 1 - flicker * 3)))
    return _criterion(
        "Flickering",
        score,
        explanation=(
            "Exposure remains stable across sampled frames."
            if score >= 4
            else "Minor brightness shifts detected between frames."
            if score >= 3
            else "Noticeable flicker may distract viewers."
        ),
        suggestion=(
            "Maintain this stable lighting when recording."
            if score >= 4
            else "Use continuous lighting and lock exposure if your camera allows."
        ),
    )


def _motion_stability(frames: list[dict[str, Any]]) -> dict[str, Any]:
    if len(frames) < 2:
        return _criterion(
            "Motion Stability",
            4,
            explanation="Limited frame samples; motion appears acceptable.",
            suggestion="Use a tripod or steady grip for longer clips.",
        )
    blur_delta = sum(abs(frames[i]["sharpness"] - frames[i - 1]["sharpness"]) for i in range(1, len(frames))) / (
        len(frames) - 1
    )
    score = _soft_score(max(0.0, min(1.0, 1 - blur_delta * 2.5)))
    return _criterion(
        "Motion Stability",
        score,
        explanation=(
            "Camera motion is smooth across the clip."
            if score >= 4
            else "Some handheld movement is visible."
            if score >= 3
            else "Shaky motion reduces professional documentation value."
        ),
        suggestion=(
            "Keep this steady shooting technique."
            if score >= 4
            else "Brace your elbows, move slowly, or use a gimbal/tripod."
        ),
    )


def _average_metrics(metrics: list[dict[str, Any]]) -> dict[str, Any]:
    keys = [
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
        "width",
        "height",
    ]

    def avg(key: str) -> float:
        return sum(float(m[key]) for m in metrics) / len(metrics)

    out = {k: avg(k) for k in keys if k not in {"width", "height"}}
    out["width"] = int(metrics[0]["width"])
    out["height"] = int(metrics[0]["height"])
    return out


def _brightness_metric(value: float) -> float:
    return max(0.0, min(1.0, 1 - abs(value - 0.48) * 2.2))


def _soft_score(metric: float) -> int:
    boosted = max(0.0, min(1.0, metric * 0.5 + 0.42))
    if boosted >= 0.80:
        return 5
    if boosted >= 0.64:
        return 4
    if boosted >= 0.46:
        return 3
    if boosted >= 0.28:
        return 2
    return 1


def _criterion(
    name: str,
    score: int,
    *,
    high_is_good: bool = True,
    explanation: str | None = None,
    suggestion: str | None = None,
) -> dict[str, Any]:
    labels = {5: "Excellent", 4: "Good", 3: "Fair", 2: "Needs Improvement", 1: "Poor"}
    if explanation is None:
        explanation = _default_explanation(name, score, high_is_good)
    if suggestion is None:
        suggestion = _default_suggestion(name, score)
    return {
        "name": name,
        "score": score,
        "label": labels.get(score, "Fair"),
        "explanation": explanation,
        "suggestion": suggestion,
    }


def _default_explanation(name: str, score: int, high_is_good: bool) -> str:
    explanations = {
        "Sharpness": (
            "Edges and fine detail are well preserved."
            if score >= 4
            else "Some softness limits crisp documentation detail."
        ),
        "Blur": (
            "Minimal motion or focus blur detected." if score >= 4 else "Blur reduces clarity of the subject."
        ),
        "Noise": ("Image noise/grain is low." if score >= 4 else "Visible noise affects clean documentation."),
        "Brightness": ("Exposure is well balanced." if score >= 4 else "Scene is slightly under- or over-exposed."),
        "Contrast": (
            "Good tonal separation between subjects and background."
            if score >= 4
            else "Flat or harsh contrast limits visual depth."
        ),
        "Blocking Artifacts": (
            "Little compression blocking visible." if score >= 4 else "Compression blocks may appear in flat areas."
        ),
        "Ringing Artifacts": (
            "Minimal halo/ringing near edges."
            if score >= 4
            else "Edge halos suggest sharpening or compression artifacts."
        ),
    }
    return explanations.get(
        name,
        f"EfficientNet-B0 quality signal for {name}."
        if high_is_good
        else f"EfficientNet-B0 artifact signal for {name}.",
    )


def _default_suggestion(name: str, score: int) -> str:
    if score >= 4:
        return "Maintain this quality for future submissions."
    tips = {
        "Sharpness": "Hold the camera steady and tap to focus on the subject.",
        "Blur": "Hold the camera steady and tap to focus on the subject.",
        "Noise": "Use better lighting or lower ISO before capturing.",
        "Brightness": "Adjust exposure or shoot in more even lighting.",
        "Contrast": "Avoid flat backlight; add directional light when possible.",
        "Blocking Artifacts": "Export at higher quality and avoid heavy compression filters.",
        "Ringing Artifacts": "Export at higher quality and avoid heavy compression filters.",
    }
    return tips.get(name, "Review capture settings and try again.")


def _quality_warnings(m: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    if m["width"] < 320 or m["height"] < 240:
        warnings.append("Low resolution — higher resolution may score better.")
    if m["sharpness"] < 0.22:
        warnings.append("Some blur detected — hold the camera steadier.")
    if m["brightness"] < 0.18:
        warnings.append("Media is quite dark — more light would improve detail.")
    if m["brightness"] > 0.88:
        warnings.append("Media may be overexposed — highlights could be washed out.")
    if m["contrast"] < 0.12:
        warnings.append("Low contrast — subject may look flat.")
    return warnings


def _build_payload(
    criteria: list[dict[str, Any]],
    *,
    media_type: str,
    quality_warnings: list[str],
    content: bytes | None = None,
    file_name: str = "",
    ai_detection: dict[str, Any] | None = None,
    include_authenticity: bool = True,
    supplementary_insights: dict[str, Any] | None = None,
    quality_engine: str | None = None,
    opencv_fallback: bool = False,
    frames_analyzed: int | None = None,
) -> dict[str, Any]:
    overall = round(sum(c["score"] for c in criteria) / len(criteria), 2)
    quality_level = (
        "Excellent" if overall >= 4.5 else "Good" if overall >= 3.5 else "Fair" if overall >= 2.5 else "Needs Improvement"
    )
    recommendation = (
        "Accepted" if overall >= 3.6 else "Accepted with Suggestions" if overall >= 2.4 else "For Officer Review"
    )
    strengths = [c["name"] for c in criteria if c["score"] >= 4]
    weaknesses = [c["name"] for c in criteria if c["score"] <= 2]

    feedback = f"Overall quality: {quality_level} ({overall}/5)."
    if strengths:
        feedback += f" Strengths: {', '.join(strengths)}."
    if weaknesses:
        feedback += f" Needs improvement: {', '.join(weaknesses)}."
    feedback += f" Recommendation: {recommendation}."
    if quality_warnings:
        feedback = (
            "This media was accepted for evaluation, but some quality issues were detected. "
            "Please review the suggestions below.\n\n" + feedback
        )

    suggestions = list({c["suggestion"] for c in criteria if c["score"] <= 3 and c["suggestion"]})
    improvement = "\n".join(f"• {s}" for s in suggestions) if suggestions else "Keep practicing — every submission builds skill."

    if ai_detection is None:
        if include_authenticity:
            ai_detection = detect_ai_generated(content or b"", file_name=file_name)
        else:
            ai_detection = deferred_authenticity_preview()

    by_name = {c["name"]: c["score"] for c in criteria}
    legacy = {
        "sharpness_score": round(by_name.get("Sharpness", 3) / 5, 3),
        "brightness_score": round(by_name.get("Brightness", 3) / 5, 3),
        "contrast_score": round(by_name.get("Contrast", 3) / 5, 3),
        "blur_score": round(by_name.get("Blur", 3) / 5, 3),
        "noise_score": round(1 - by_name.get("Noise", 3) / 5, 3),
        "overall_score": round(overall / 5, 3),
    }

    used_opencv = quality_engine == QUALITY_ENGINE_OPENCV
    scoring_engine = QUALITY_ENGINE_OPENCV if used_opencv else SCORING_ENGINE
    scoring_model = "opencv" if used_opencv else MODEL_ID
    payload = {
        "criteria": criteria,
        "overall_score": overall,
        "quality_level": quality_level,
        "recommendation": recommendation,
        "ai_feedback": feedback,
        "improvement_suggestions": improvement,
        "ai_detection": ai_detection,
        "media_type": media_type,
        "scoring_model": scoring_model,
        "scoring_engine": scoring_engine,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "quality_warnings": quality_warnings,
        "legacy": legacy,
        "evaluation_status": "ok",
        "evaluation_available": True,
        "analysis": {
            "engine": scoring_engine,
            "model": scoring_model,
            "quality_engine": quality_engine,
            "efficientnet_used": quality_engine == QUALITY_ENGINE_EFFICIENTNET,
            "ffmpeg_used": ffmpeg_available() if media_type == "video" else False,
            "opencv_fallback": bool(opencv_fallback),
            "frames_analyzed": frames_analyzed if frames_analyzed is not None else (1 if media_type == "photo" else None),
        },
    }
    if supplementary_insights:
        payload["additional_quality_insights"] = supplementary_insights
    if include_authenticity:
        return apply_integrity_evaluation_policy(payload)
    return _apply_preview_integrity_policy(payload)
