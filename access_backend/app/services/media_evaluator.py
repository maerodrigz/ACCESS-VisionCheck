"""Online media evaluation: EfficientNet-B0 scoring + FFmpeg video frames.

Phase 7A: optional ``QUALITY_ENGINE=musiq_worker`` selects MUSIQ worker classical
OpenCV metrics (+ MUSIQ OPQ context only). Default remains EfficientNet-B0.
"""

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
from app.services.color_quality_criteria import (
    analyze_color_criteria_bytes,
    analyze_color_criteria_from_frames,
)
from app.services.video_temporal_quality_criteria import analyze_temporal_video_criteria
from app.services.supplementary_quality_insights import (
    build_photo_supplementary_insights,
    build_video_supplementary_insights,
)
from app.services.musiq_quality_adapter import strip_adapter_metadata
from app.services.rule_based_quality_feedback import (
    format_rule_based_ai_feedback,
    format_rule_based_improvement_suggestions,
    generate_rule_based_media_feedback,
)


SCORING_ENGINE = "efficientnet-b0+ffmpeg+color-heuristics"
SCORING_ENGINE_MUSIQ = "musiq-worker+opencv+color-heuristics"
SCORING_MODEL_MUSIQ = "musiq-paq2piq+opencv-classical"
QUALITY_ENGINE_EFFICIENTNET = "efficientnet-b0"
QUALITY_ENGINE_OPENCV = "opencv"
QUALITY_ENGINE_MUSIQ_WORKER = "musiq_worker"

# Overall photo/video quality formula versions (persisted on new evaluations only).
# v1: unweighted mean of every available criterion (Sharpness and Blur each counted).
# v2: Sharpness+Blur combined into one Clarity factor; other criteria remain independent.
SCORING_FORMULA_V1 = "v1"
SCORING_FORMULA_V2 = "v2"
SCORING_FORMULA_VERSION = SCORING_FORMULA_V2
_CLARITY_CRITERION_NAMES = frozenset({"Sharpness", "Blur"})

_PRACTICE_VIDEO_EXTENSIONS = frozenset(DEFAULT_VIDEO_EXTENSIONS)
# Active photo rubric (Noise/Ringing removed from presentation; historical criteria_json retained).
_PHOTO_CRITERION_NAMES = (
    "Sharpness",
    "Blur",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Color Balance",
    "Color Saturation",
)
_VIDEO_EXTRA_CRITERION_NAMES = ("Flickering", "Motion Stability")
# Legacy names still readable from historical payloads / DB joins.
_LEGACY_PHOTO_CRITERION_NAMES = ("Noise", "Ringing Artifacts")


def preferred_quality_engine() -> str | None:
    """Preferred *local* engine when QUALITY_ENGINE=enet (rollback / pre-cutover).

    Phase 7G cutover path (QUALITY_ENGINE=musiq_worker) does not use this helper for
    fallback; that path is MUSIQ → optimized local OpenCV only. ENET weights remain
    on disk for rollback via QUALITY_ENGINE=enet.
    """
    if efficientnet_available() and ensure_weights():
        return QUALITY_ENGINE_EFFICIENTNET
    if opencv_available():
        return QUALITY_ENGINE_OPENCV
    return None


def _opencv_only(
    content: bytes,
    *,
    as_fallback: bool,
) -> tuple[dict[str, Any] | None, str | None, bool]:
    """Local OpenCV only (Phase 7G MUSIQ fallback; no EfficientNet)."""
    if opencv_available():
        metrics = analyze_image_for_engine(content, QUALITY_ENGINE_OPENCV)
        if metrics is not None:
            return metrics, QUALITY_ENGINE_OPENCV, bool(as_fallback)
    return None, None, False


def _enet_then_opencv(
    content: bytes,
    *,
    from_musiq_fallback: bool = False,
) -> tuple[dict[str, Any] | None, str | None, bool]:
    """ENET first, then local OpenCV. Used only for QUALITY_ENGINE=enet rollback path."""
    # Phase 7G: MUSIQ cutover must not call this (ENET inactive on musiq_worker path).
    if from_musiq_fallback:
        return _opencv_only(content, as_fallback=True)

    enet_ready = efficientnet_available() and ensure_weights()
    if enet_ready:
        metrics = analyze_image_for_engine(content, QUALITY_ENGINE_EFFICIENTNET)
        if metrics is not None:
            return metrics, QUALITY_ENGINE_EFFICIENTNET, False
    if opencv_available():
        metrics = analyze_image_for_engine(content, QUALITY_ENGINE_OPENCV)
        if metrics is not None:
            # Preserve legacy: OpenCV-only hosts report opencv_fallback=False.
            # ENET failure → OpenCV reports opencv_fallback=True.
            opencv_fallback = bool(enet_ready)
            return metrics, QUALITY_ENGINE_OPENCV, opencv_fallback
    return None, None, False


def analyze_image_for_engine(content: bytes, engine: str) -> dict[str, Any] | None:
    if engine == QUALITY_ENGINE_EFFICIENTNET:
        if efficientnet_available() and ensure_weights():
            return efficientnet_analyze(content)
        return None
    if engine == QUALITY_ENGINE_OPENCV:
        if opencv_available():
            return opencv_analyze(content)
        return None
    if engine == QUALITY_ENGINE_MUSIQ_WORKER:
        from app.services.musiq_worker_client import evaluate_bytes as musiq_evaluate_bytes
        from app.services.musiq_worker_client import musiq_worker_configured
        from app.services.musiq_quality_adapter import metrics_from_worker_result

        if not musiq_worker_configured() or not content:
            return None
        result = musiq_evaluate_bytes(content, media_type="photo", filename="frame.jpg")
        mapped = metrics_from_worker_result(result, content=content)
        return mapped
    return None


def resolve_quality_engine_for_bytes(
    content: bytes,
    *,
    media_type: str = "photo",
    filename: str = "upload.jpg",
    file_ext: str = "",
    local_image_bytes: bytes | None = None,
) -> tuple[dict[str, Any] | None, str | None, bool]:
    """
    Returns (metrics, engine_used, opencv_fallback).

    Phase 7G target architecture (QUALITY_ENGINE=musiq_worker):
      MUSIQ worker → optimized local OpenCV only (EfficientNet inactive).
    Rollback / current default (QUALITY_ENGINE=enet, leave .env unchanged until cutover):
      EfficientNet-B0 → local OpenCV. Weights retained on disk.
    """
    from app.services.musiq_worker_client import evaluate_bytes as musiq_evaluate_bytes
    from app.services.musiq_worker_client import musiq_worker_configured, quality_engine
    from app.services.musiq_quality_adapter import metrics_from_worker_result

    local_bytes = local_image_bytes if local_image_bytes is not None else content
    media_norm = (media_type or "photo").strip().lower()
    if media_norm == "image":
        media_norm = "photo"

    if quality_engine() == "musiq_worker":
        if musiq_worker_configured() and content:
            result = musiq_evaluate_bytes(
                content,
                media_type=media_norm,
                filename=filename or "upload.jpg",
                file_ext=file_ext or "",
            )
            # For video worker aggregates, dimension decode uses a sample frame when provided.
            dim_src = local_bytes if media_norm == "video" else content
            mapped = metrics_from_worker_result(result, content=dim_src)
            if mapped is not None:
                return mapped, QUALITY_ENGINE_MUSIQ_WORKER, False
        # Cutover fallback: optimized local OpenCV only (no EfficientNet).
        return _opencv_only(local_bytes, as_fallback=True)

    # Rollback path: QUALITY_ENGINE=enet
    preferred = preferred_quality_engine()
    if preferred == QUALITY_ENGINE_EFFICIENTNET:
        return _enet_then_opencv(local_bytes, from_musiq_fallback=False)
    if preferred == QUALITY_ENGINE_OPENCV:
        metrics = analyze_image_for_engine(local_bytes, QUALITY_ENGINE_OPENCV)
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
    metrics, engine, opencv_fallback = resolve_quality_engine_for_bytes(
        content,
        media_type="photo",
        filename=file_name or "upload.jpg",
    )
    if metrics is None:
        return None
    clean_metrics, musiq_ctx = strip_adapter_metadata(metrics)
    color_balance, color_saturation = analyze_color_criteria_bytes(content)
    criteria = _photo_criteria(clean_metrics, color_balance=color_balance, color_saturation=color_saturation)
    warnings = _quality_warnings(clean_metrics)
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
        enet_metrics=clean_metrics,
        musiq_opq_context=musiq_ctx if engine == QUALITY_ENGINE_MUSIQ_WORKER else None,
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

    from app.services.musiq_worker_client import quality_engine as configured_quality_engine

    musiq_ctx: dict[str, Any] | None = None
    if configured_quality_engine() == "musiq_worker":
        # One worker call for the video aggregate; local frames still drive color/temporal/auth.
        first, engine, opencv_fallback = resolve_quality_engine_for_bytes(
            content,
            media_type="video",
            filename=file_name or f"upload{ext}",
            file_ext=ext,
            local_image_bytes=frame_bytes[0],
        )
        if first is None or engine is None:
            return None
        if engine == QUALITY_ENGINE_MUSIQ_WORKER:
            averaged, musiq_ctx = strip_adapter_metadata(first)
            frame_metrics = [averaged]
        else:
            clean_first, _ = strip_adapter_metadata(first)
            frame_metrics = [clean_first]
            rest = frame_bytes[1:]
            if rest:
                workers = min(4, max(1, len(rest)))

                def _score_fallback_frame(frame: bytes) -> dict[str, Any] | None:
                    raw = analyze_image_for_engine(frame, engine)
                    if raw is None:
                        return None
                    cleaned, _ = strip_adapter_metadata(raw)
                    return cleaned

                with ThreadPoolExecutor(max_workers=workers) as pool:
                    pinned = list(pool.map(_score_fallback_frame, rest))
                frame_metrics.extend(m for m in pinned if m is not None)
            if not frame_metrics:
                return None
            averaged = _average_metrics(frame_metrics)
    else:
        first, engine, opencv_fallback = resolve_quality_engine_for_bytes(frame_bytes[0])
        if first is None or engine is None:
            return None
        clean_first, _ = strip_adapter_metadata(first)
        frame_metrics = [clean_first]
        rest = frame_bytes[1:]
        if rest:
            workers = min(4, max(1, len(rest)))

            def _score_frame(frame: bytes) -> dict[str, Any] | None:
                raw = analyze_image_for_engine(frame, engine)
                if raw is None:
                    return None
                cleaned, _ = strip_adapter_metadata(raw)
                return cleaned

            with ThreadPoolExecutor(max_workers=workers) as pool:
                pinned = list(pool.map(_score_frame, rest))
            frame_metrics.extend(m for m in pinned if m is not None)
        if not frame_metrics:
            return None
        averaged = _average_metrics(frame_metrics)
    color_balance, color_saturation = analyze_color_criteria_from_frames(frame_bytes)
    flickering, motion_stability = analyze_temporal_video_criteria(frame_bytes)
    criteria = [
        *_photo_criteria(averaged, color_balance=color_balance, color_saturation=color_saturation),
        flickering,
        motion_stability,
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
        enet_metrics=averaged,
        musiq_opq_context=musiq_ctx if engine == QUALITY_ENGINE_MUSIQ_WORKER else None,
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


def _photo_criteria(
    m: dict[str, Any],
    *,
    color_balance: dict[str, Any],
    color_saturation: dict[str, Any],
) -> list[dict[str, Any]]:
    """Five retained ENET/OpenCV heads + heuristic Color Balance / Color Saturation."""
    return [
        _criterion("Sharpness", _soft_score(m["sharpness"]), high_is_good=True),
        _criterion("Blur", _soft_score(1 - m["blur"]), high_is_good=False),
        _criterion("Brightness", _soft_score(_brightness_metric(m["brightness"]))),
        _criterion("Contrast", _soft_score(min(m["contrast"], 1.0))),
        _criterion("Blocking Artifacts", _soft_score(1 - m["blocking_artifacts"]), high_is_good=False),
        color_balance,
        color_saturation,
    ]


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
    cleaned = [strip_adapter_metadata(m)[0] for m in metrics]

    def avg(key: str) -> float:
        return sum(float(m[key]) for m in cleaned) / len(cleaned)

    out = {k: avg(k) for k in keys if k not in {"width", "height"}}
    out["width"] = int(cleaned[0]["width"])
    out["height"] = int(cleaned[0]["height"])
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
        "available": True,
        "estimate_kind": "experimental_estimate",
        "high_is_good": high_is_good,
    }


def _scored_criteria(criteria: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for c in criteria:
        if not isinstance(c, dict):
            continue
        if c.get("available") is False:
            continue
        try:
            score = int(c.get("score"))
        except (TypeError, ValueError):
            continue
        if 1 <= score <= 5:
            out.append(c)
    return out


def scoring_formula_version_from_payload(payload: dict[str, Any] | None) -> str:
    """Return persisted formula version; missing version means historical v1."""
    if not isinstance(payload, dict):
        return SCORING_FORMULA_V1
    raw = payload.get("scoring_formula_version")
    if not raw and isinstance(payload.get("analysis"), dict):
        raw = payload["analysis"].get("scoring_formula_version")
    text = str(raw or "").strip().lower()
    if text in {SCORING_FORMULA_V1, SCORING_FORMULA_V2}:
        return text
    return SCORING_FORMULA_V1


def compute_overall_score_from_criteria(
    criteria: list[dict[str, Any]] | None,
    *,
    formula_version: str = SCORING_FORMULA_VERSION,
) -> tuple[float, dict[str, Any]]:
    """Compute overall quality score and factor metadata.

    v1: mean of every available criterion (Sharpness and Blur each count).
    v2: mean of Clarity (avg of available Sharpness/Blur) plus other available criteria.
    """
    scored = _scored_criteria(criteria or [])
    meta: dict[str, Any] = {
        "scoring_formula_version": formula_version
        if formula_version in {SCORING_FORMULA_V1, SCORING_FORMULA_V2}
        else SCORING_FORMULA_V1,
        "clarity_score": None,
        "overall_factor_count": 0,
        "clarity_inputs": [],
    }
    if not scored:
        return 0.0, meta

    version = meta["scoring_formula_version"]
    if version == SCORING_FORMULA_V1:
        overall = round(sum(int(c["score"]) for c in scored) / len(scored), 2)
        meta["overall_factor_count"] = len(scored)
        return overall, meta

    clarity_scores: list[int] = []
    other_scores: list[float] = []
    clarity_inputs: list[str] = []
    for c in scored:
        name = str(c.get("name") or "")
        score = int(c["score"])
        if name in _CLARITY_CRITERION_NAMES:
            clarity_scores.append(score)
            clarity_inputs.append(name)
        else:
            other_scores.append(float(score))

    factors: list[float] = list(other_scores)
    if clarity_scores:
        clarity = sum(clarity_scores) / len(clarity_scores)
        meta["clarity_score"] = clarity
        meta["clarity_inputs"] = clarity_inputs
        factors.append(clarity)

    if not factors:
        return 0.0, meta

    overall = round(sum(factors) / len(factors), 2)
    meta["overall_factor_count"] = len(factors)
    return overall, meta


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
        "Brightness": ("Exposure is well balanced." if score >= 4 else "Scene is slightly under- or over-exposed."),
        "Contrast": (
            "Good tonal separation between subjects and background."
            if score >= 4
            else "Flat or harsh contrast limits visual depth."
        ),
        "Blocking Artifacts": (
            "Little compression blocking visible." if score >= 4 else "Compression blocks may appear in flat areas."
        ),
        "Color Balance": (
            "Color cast looks acceptable for documentation."
            if score >= 4
            else "Color cast may affect natural subject appearance."
        ),
        "Color Saturation": (
            "Color saturation looks suitable for documentation."
            if score >= 4
            else "Saturation may be too muted or too intense for documentation."
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
        "Sharpness": "Tap to focus on the main subject and keep the camera steady when capturing.",
        "Blur": "Reduce camera or subject movement; use a faster shutter or brace your stance.",
        "Brightness": "Review lighting and exposure so important details stay visible.",
        "Contrast": "Improve tonal separation with gentle directional light when possible.",
        "Blocking Artifacts": "Export at higher quality and avoid heavy compression filters.",
        "Color Balance": "Check white balance if natural subject colors are required.",
        "Color Saturation": "Adjust saturation conservatively if documentation needs more natural color.",
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
    enet_metrics: dict[str, Any] | None = None,
    musiq_opq_context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    scored = _scored_criteria(criteria)
    overall, overall_meta = compute_overall_score_from_criteria(
        criteria,
        formula_version=SCORING_FORMULA_VERSION,
    )
    quality_level = (
        "Excellent" if overall >= 4.5 else "Good" if overall >= 3.5 else "Fair" if overall >= 2.5 else "Needs Improvement"
    )
    recommendation = (
        "Accepted" if overall >= 3.6 else "Accepted with Suggestions" if overall >= 2.4 else "For Officer Review"
    )
    strengths = [c["name"] for c in scored if int(c["score"]) >= 4]
    weaknesses = [c["name"] for c in scored if int(c["score"]) <= 2]

    rule_feedback = generate_rule_based_media_feedback(
        criteria,
        media_type=media_type,
        overall_score=overall,
        quality_level=quality_level,
        quality_warnings=quality_warnings,
    )
    feedback = format_rule_based_ai_feedback(rule_feedback)
    feedback += f" Recommendation: {recommendation}."
    if quality_warnings:
        feedback = (
            "This media was accepted for evaluation, but some quality issues were detected. "
            "Please review the suggestions below.\n\n" + feedback
        )
    improvement = format_rule_based_improvement_suggestions(rule_feedback)

    if ai_detection is None:
        if include_authenticity:
            ai_detection = detect_ai_generated(content or b"", file_name=file_name)
        else:
            ai_detection = deferred_authenticity_preview()

    by_name = {c["name"]: int(c["score"]) for c in scored}
    # Preserve DB legacy noise_score polarity from ENET/OpenCV noise metric (not Color Balance).
    clean_enet = strip_adapter_metadata(enet_metrics)[0] if isinstance(enet_metrics, dict) else None
    if clean_enet is not None and "noise" in clean_enet:
        noise_amount = float(min(max(float(clean_enet["noise"]), 0.0), 1.0))
        legacy_noise = round(noise_amount, 3)  # stored high = more noise (historical)
    else:
        legacy_noise = None
    legacy = {
        "sharpness_score": round(by_name.get("Sharpness", 3) / 5, 3),
        "brightness_score": round(by_name.get("Brightness", 3) / 5, 3),
        "contrast_score": round(by_name.get("Contrast", 3) / 5, 3),
        "blur_score": round(by_name.get("Blur", 3) / 5, 3),
        "noise_score": legacy_noise,
        "overall_score": round(overall / 5, 3) if overall > 0 else None,
    }

    used_opencv = quality_engine == QUALITY_ENGINE_OPENCV
    used_musiq = quality_engine == QUALITY_ENGINE_MUSIQ_WORKER
    if used_musiq:
        scoring_engine = SCORING_ENGINE_MUSIQ
        scoring_model = SCORING_MODEL_MUSIQ
    elif used_opencv:
        scoring_engine = "opencv+color-heuristics"
        scoring_model = "opencv"
    else:
        scoring_engine = SCORING_ENGINE
        scoring_model = MODEL_ID
    payload = {
        "criteria": criteria,
        "overall_score": overall,
        "quality_level": quality_level,
        "recommendation": recommendation,
        "ai_feedback": feedback,
        "improvement_suggestions": improvement,
        # Structured deterministic feedback (not Gemini). Flutter may use or regenerate locally.
        "rule_based_feedback": rule_feedback,
        "ai_detection": ai_detection,
        "media_type": media_type,
        "scoring_model": scoring_model,
        "scoring_engine": scoring_engine,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "quality_warnings": quality_warnings,
        "quality_disclaimer": (
            "Quality ratings are automated estimates and may not reflect artistic intent or human judgment."
        ),
        "legacy": legacy,
        "evaluation_status": "ok",
        "evaluation_available": True,
        # Active formula for newly generated evaluations (historical payloads without this are v1).
        "scoring_formula_version": SCORING_FORMULA_VERSION,
        "analysis": {
            "engine": scoring_engine,
            "model": scoring_model,
            "quality_engine": quality_engine,
            "efficientnet_used": quality_engine == QUALITY_ENGINE_EFFICIENTNET,
            "efficientnet_development_frozen": True,
            "quality_estimates": "experimental",
            "ffmpeg_used": ffmpeg_available() if media_type == "video" else False,
            "opencv_fallback": bool(opencv_fallback),
            "color_heuristics": True,
            "frames_analyzed": frames_analyzed if frames_analyzed is not None else (1 if media_type == "photo" else None),
            "musiq_opq_context_only": True if used_musiq else None,
            "scoring_formula_version": SCORING_FORMULA_VERSION,
            "scoring_formula": "clarity_unified_v2",
            "clarity_score": overall_meta.get("clarity_score"),
            "clarity_inputs": overall_meta.get("clarity_inputs") or [],
            "overall_factor_count": overall_meta.get("overall_factor_count") or 0,
        },
    }
    if used_musiq and isinstance(musiq_opq_context, dict):
        payload["analysis"]["musiq_opq"] = musiq_opq_context
    # Drop null-only flag when not on musiq path (keep payload shape stable for ENET).
    if payload["analysis"]["musiq_opq_context_only"] is None:
        del payload["analysis"]["musiq_opq_context_only"]
    if supplementary_insights:
        payload["additional_quality_insights"] = supplementary_insights
    if include_authenticity:
        return apply_integrity_evaluation_policy(payload)
    return _apply_preview_integrity_policy(payload)