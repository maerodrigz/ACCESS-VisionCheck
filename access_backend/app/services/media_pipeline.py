"""Auto quality evaluation + AI detection when media is uploaded."""

from __future__ import annotations

import json
import logging

from pathlib import Path

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.crud import member_ranking as ranking_crud
from app.crud import system_settings as settings_crud
from app.crud import user as user_crud
from app.models.ai_detection_result import AiDetectionResult
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.services.media_upload_config import (
    DEFAULT_VIDEO_EXTENSIONS,
    EvaluationVideoDurationError,
    check_evaluation_video_duration,
    is_video_extension,
)
from app.services.integrity_evaluation_policy import (
    apply_integrity_evaluation_policy,
    finalize_member_evaluation_payload,
    xp_award_points_from_payload,
)
from app.services.image_quality import parse_client_payload
from app.services.media_evaluator import (
    evaluate_authenticity_bytes,
    evaluate_bytes,
    is_deferred_authenticity_preview,
    merge_client_gemini,
    scores_from_payload,
)

logger = logging.getLogger(__name__)

_PRACTICE_VIDEO_EXTENSIONS = frozenset(DEFAULT_VIDEO_EXTENSIONS)


def _is_practice_eval_video_file_name(file_name: str) -> bool:
    ext = Path(file_name).suffix.lower()
    return ext in _PRACTICE_VIDEO_EXTENSIONS


def is_evaluation_category_video(media: MediaFile) -> bool:
    """Practice evaluation upload (not event documentation) that is a video container."""
    if getattr(media, "media_category", None) != MEDIA_CATEGORY_EVALUATION:
        return False
    return _is_practice_eval_video_file_name(_pipeline_eval_file_name(media))


def _ignore_client_preview_authenticity_for_video(media: MediaFile) -> bool:
    """Evaluation videos must not reuse client-supplied ai_detection on save."""
    return is_evaluation_category_video(media)


def _video_ai_scan_incomplete(ai_info: dict | None) -> bool:
    """True when a video upload has no completed PROBE/UnivFD authenticity result."""
    if not isinstance(ai_info, dict) or not ai_info:
        return True
    if is_deferred_authenticity_preview(ai_info):
        return True
    if str(ai_info.get("detector_backend", "")).strip():
        return False
    if ai_info.get("raw_detector_probability") is not None or ai_info.get("probability") is not None:
        return False
    if str(ai_info.get("verdict", "")).strip():
        return False
    return True


def _fallback_video_ai_scan_required() -> dict:
    return {
        "verdict": "suspicious",
        "confidence": 0.5,
        "probability": 0.5,
        "raw_detector_probability": 0.5,
        "risk_level": "suspicious",
        "requires_review": True,
        "detector_backend": "probe",
        "detail": (
            "Video AI authenticity scan did not complete (FFmpeg frame extract, PROBE checkpoint, "
            "or stored bytes missing). Officer review is required. This is not verified as human capture."
        ),
    }


def _guard_practice_evaluation_video_bytes(
    db: Session,
    media: MediaFile,
    file_bytes: bytes,
    eval_file_name: str,
) -> bool:
    """Return False when stored video bytes fail practice length rules (pipeline should abort)."""
    if getattr(media, "media_category", None) != MEDIA_CATEGORY_EVALUATION or not file_bytes:
        return True
    ext = Path(eval_file_name).suffix.lower()
    if not ext or not is_video_extension(db, ext, MEDIA_CATEGORY_EVALUATION):
        return True
    try:
        check_evaluation_video_duration(db, ext, file_bytes)
    except EvaluationVideoDurationError as exc:
        logger.error(
            "practice eval pipeline rejected video duration media_id=%s max=%ss actual=%ss",
            media.id,
            exc.max_seconds,
            exc.actual_seconds,
        )
        return False
    return True


def run_pipeline(
    db: Session,
    media: MediaFile,
    file_bytes: bytes,
    *,
    evaluation_metadata: str | None = None,
    require_full_analysis: bool = False,
) -> tuple[MediaEvaluation, AiDetectionResult | None] | None:
    existing = eval_crud.get_for_media(db, media.id)
    if existing is not None:
        return existing, eval_crud.get_ai_for_media(db, media.id)

    eval_file_name = _pipeline_eval_file_name(media)
    if not _guard_practice_evaluation_video_bytes(db, media, file_bytes, eval_file_name):
        return None
    payload: dict = {}
    preview = _payload_from_preview_metadata(evaluation_metadata)
    if preview is not None and _ignore_client_preview_authenticity_for_video(media):
        logger.info(
            "practice eval video: ignoring full preview metadata; server authenticity required media_id=%s",
            media.id,
        )
        preview = None
    quality_preview = _quality_preview_from_metadata(evaluation_metadata) if preview is None else None

    if preview is not None:
        payload = preview
        scores = scores_from_payload(payload)
        feedback = payload.get("ai_feedback") or _feedback_text(scores["overall_score"], "human")
        criteria_json = json.dumps(payload)
        quality_level = payload.get("quality_level")
        recommendation = payload.get("recommendation")
        ai_info = payload.get("ai_detection") if isinstance(payload.get("ai_detection"), dict) else {}
    elif quality_preview is not None:
        if not file_bytes:
            if require_full_analysis:
                return None
            scores = {
                "sharpness_score": 0.5,
                "brightness_score": 0.5,
                "contrast_score": 0.5,
                "blur_score": 0.5,
                "noise_score": 0.5,
                "overall_score": 0.5,
            }
            feedback = "Unable to analyze media bytes. Officers will review manually."
            criteria_json = None
            quality_level = "Fair"
            recommendation = "For Officer Review"
            ai_info = {}
        else:
            ai_detection = evaluate_authenticity_bytes(file_bytes, file_name=eval_file_name)
            if ai_detection is None:
                if require_full_analysis:
                    return None
                scores = {
                    "sharpness_score": 0.5,
                    "brightness_score": 0.5,
                    "contrast_score": 0.5,
                    "blur_score": 0.5,
                    "noise_score": 0.5,
                    "overall_score": 0.5,
                }
                feedback = "Unable to analyze media bytes. Officers will review manually."
                criteria_json = None
                quality_level = "Fair"
                recommendation = "For Officer Review"
                ai_info = {}
            else:
                merged = dict(quality_preview)
                merged["ai_detection"] = ai_detection
                payload = merge_client_gemini(merged, evaluation_metadata)
                payload = apply_integrity_evaluation_policy(payload)
                scores = scores_from_payload(payload)
                feedback = payload.get("ai_feedback") or _feedback_text(scores["overall_score"], "human")
                criteria_json = json.dumps(payload)
                quality_level = payload.get("quality_level")
                recommendation = payload.get("recommendation")
                ai_info = payload.get("ai_detection") if isinstance(payload.get("ai_detection"), dict) else {}
    else:
        analyzed = evaluate_bytes(file_bytes, file_name=eval_file_name)
        if analyzed:
            payload = merge_client_gemini(analyzed, evaluation_metadata)
            scores = scores_from_payload(payload)
            feedback = payload.get("ai_feedback") or _feedback_text(scores["overall_score"], "human")
            criteria_json = json.dumps(payload)
            quality_level = payload.get("quality_level")
            recommendation = payload.get("recommendation")
            ai_info = payload.get("ai_detection") if isinstance(payload.get("ai_detection"), dict) else {}
        else:
            if require_full_analysis:
                return None
            scores = {
                "sharpness_score": 0.5,
                "brightness_score": 0.5,
                "contrast_score": 0.5,
                "blur_score": 0.5,
                "noise_score": 0.5,
                "overall_score": 0.5,
            }
            feedback = "Unable to analyze media bytes. Officers will review manually."
            criteria_json = None
            quality_level = "Fair"
            recommendation = "For Officer Review"
            ai_info = {}

    if _is_practice_eval_video_file_name(eval_file_name) and _video_ai_scan_incomplete(ai_info):
        logger.warning(
            "practice eval video missing AI scan media_id=%s file=%s",
            media.id,
            eval_file_name,
        )
        ai_info = _fallback_video_ai_scan_required()
        if payload:
            payload = dict(payload)
            payload["ai_detection"] = ai_info
            payload = apply_integrity_evaluation_policy(payload)
            criteria_json = json.dumps(payload)
            feedback = payload.get("ai_feedback") or feedback

    ai_prob, ai_label, detection_remarks = _ai_from_payload(ai_info)
    exif_payload = ai_info.get("exif_metadata")
    if isinstance(exif_payload, dict):
        for key in (
            "camera_provenance_strength",
            "camera_provenance_reasons",
            "visual_ai_probability",
            "visual_risk_level",
            "provenance_policy_outcome",
        ):
            if key in ai_info and key not in exif_payload:
                exif_payload[key] = ai_info[key]
    exif_metadata = json.dumps(exif_payload) if isinstance(exif_payload, dict) else None

    evaluation = eval_crud.create_evaluation(
        db,
        {
            "media_id": media.id,
            **scores,
            "feedback": feedback,
            "criteria_json": criteria_json,
            "quality_level": quality_level,
            "recommendation": recommendation,
        },
    )
    from app.services.ai_review_workflow import initial_review_status

    review_status = initial_review_status(ai_label, ai_prob, ai_detection=ai_info)
    ai_row = eval_crud.create_ai_result(
        db,
        {
            "media_id": media.id,
            "ai_probability": ai_prob,
            "detection_result": ai_label,
            "reviewed_by_admin": False,
            "review_status": review_status,
            "detection_remarks": detection_remarks,
            "exif_metadata": exif_metadata,
        },
    )

    if media.uploaded_by:
        user = user_crud.get_by_id(db, media.uploaded_by)
        uploader_name = user.fullname if user else "Member"
        if user:
            if payload:
                xp_points = xp_award_points_from_payload(payload)
            else:
                xp_points = int(round(float(scores["overall_score"]) * 100))
            if xp_points > 0:
                ranking_crud.add_points(db, media.uploaded_by, xp_points)
            if payload and payload.get("member_scores_released", True):
                user_crud.recalculate_skill_level(db, user)
            elif not payload:
                user_crud.recalculate_skill_level(db, user)
            from app.crud import member_profile as profile_crud
            from app.services import member_milestones as milestone_service

            eval_count, _ = profile_crud.evaluations_stats(db, user.id)
            milestone_service.on_evaluation_completed(
                db, user.id, evaluation_count=eval_count
            )

        from app.services import notification_events as notify_events

        # Members are not pinged on every practice eval (score is shown in-app).
        # Notify admins + member only when integrity flags the upload; admin review
        # outcomes notify the member separately via ai_review_workflow.apply_ai_review.
        if _should_notify_admin_ai_flag(db, ai_label, ai_prob, ai_info=ai_info):
            notify_events.notify_ai_detection_alert(
                db,
                media.id,
                media.file_name,
                uploader_name,
                member_id=media.uploaded_by,
                detection_label=ai_label,
            )

    return evaluation, ai_row


def _trusted_preview_payload(evaluation_metadata: str | None) -> dict | None:
    """Server-shaped preview JSON from POST /media/evaluate (not arbitrary client scores)."""
    client = parse_client_payload(evaluation_metadata)
    if not client:
        return None

    criteria = client.get("criteria")
    if not isinstance(criteria, list) or len(criteria) == 0:
        return None

    ai = client.get("ai_detection")
    if not isinstance(ai, dict):
        return None

    has_overall = client.get("overall_score") is not None
    has_legacy = isinstance(client.get("legacy"), dict)
    if not has_overall and not has_legacy:
        return None

    if not (client.get("scoring_engine") or client.get("scoring_model")):
        return None

    return dict(client)


def _quality_preview_from_metadata(evaluation_metadata: str | None) -> dict | None:
    """Quality-only preview (authenticity deferred): save re-runs PROBE on stored bytes only."""
    base = _trusted_preview_payload(evaluation_metadata)
    if not base:
        return None
    ai = base.get("ai_detection")
    if not isinstance(ai, dict) or not is_deferred_authenticity_preview(ai):
        return None
    return base


def _payload_from_preview_metadata(evaluation_metadata: str | None) -> dict | None:
    """Reuse full preview including authenticity (skips all re-analysis on save)."""
    base = _trusted_preview_payload(evaluation_metadata)
    if not base:
        return None

    ai = base.get("ai_detection")
    if not isinstance(ai, dict) or is_deferred_authenticity_preview(ai):
        return None

    return finalize_member_evaluation_payload(base)


def _pipeline_eval_file_name(media: MediaFile) -> str:
    """Use stored URL extension when the display title omits .mp4/.mov (common on mobile save)."""
    name = (media.file_name or "upload").strip()
    if Path(name).suffix:
        return name
    url_ext = Path((media.file_url or "").split("?", 1)[0]).suffix.lower()
    if url_ext:
        return f"{name}{url_ext}"
    if (media.file_type or "").lower() == "video":
        return f"{name}.mp4"
    return name


def _should_notify_admin_ai_flag(
    db: Session,
    ai_label: str,
    ai_prob: float,
    *,
    ai_info: dict | None = None,
) -> bool:
    """Admins are alerted only for suspicious or AI-generated integrity flags — not every practice eval."""
    cfg = settings_crud.settings_payload(db)
    if not cfg.get("enable_ai_detection", True):
        return False
    if not cfg.get("auto_generate_review_alerts", True):
        return False
    if not settings_crud.is_notification_enabled(db, "notify_system_alerts"):
        return False

    backend = str(ai_info.get("detector_backend", "")).strip().lower() if isinstance(ai_info, dict) else ""
    if backend in ("probe", "waverep_g4"):
        return bool(ai_info.get("requires_review"))

    label = (ai_label or "").lower()
    if label == "suspicious":
        return True
    if label in ("ai_generated", "ai") or "generated" in label:
        threshold = float(cfg.get("ai_confidence_threshold", 0.75))
        return ai_prob >= threshold
    return False


def _ai_from_payload(ai_info: dict) -> tuple[float, str, str]:
    verdict = str(ai_info.get("verdict", "authentic")).lower()
    confidence = float(ai_info.get("confidence", 0.85))
    detail = str(ai_info.get("detail", ""))
    prob_raw = ai_info.get("probability")
    if prob_raw is None and ai_info.get("raw_detector_probability") is not None:
        prob_raw = ai_info.get("raw_detector_probability")
    synthetic_prob = float(prob_raw) if prob_raw is not None else None
    backend = str(ai_info.get("detector_backend", "")).strip().lower()
    is_probe = backend == "probe"
    is_waverep = backend == "waverep_g4"
    uses_raw_prob = is_probe or is_waverep

    if verdict == "suspicious":
        prob = synthetic_prob if synthetic_prob is not None else confidence
        if not uses_raw_prob:
            prob = min(0.74, prob)
        return round(prob, 3), "suspicious", detail or (
            "Suspicious indicators detected. Officers will review this submission carefully."
        )
    if verdict in ("ai_generated", "ai"):
        prob = synthetic_prob if synthetic_prob is not None else confidence
        if not uses_raw_prob:
            prob = max(0.75, prob)
        return round(prob, 3), "ai_generated", detail or (
            "Possible AI-generated content flagged for officer review."
        )
    if synthetic_prob is not None:
        prob = synthetic_prob
    else:
        # Authentic verdict stores human confidence (1 - synthetic probability).
        prob = max(0.0, min(0.98, 1.0 - confidence))
    if is_waverep:
        low_risk_default = "Low AI authenticity risk (WaveRep G4). This is not proof of human origin."
    elif is_probe:
        low_risk_default = "Low AI authenticity risk (PROBE). This is not proof of human origin."
    else:
        low_risk_default = "Automated scan indicates authentic human-uploaded media."
    return round(prob, 3), "human", detail or low_risk_default


def _feedback_text(overall: float, ai_result: str) -> str:
    if ai_result == "ai_generated":
        return "Possible AI-generated content detected. Officers will review this submission."
    if overall >= 0.85:
        return "Excellent quality. Sharp focus and balanced exposure."
    if overall >= 0.70:
        return "Good submission. Minor improvements possible in lighting or contrast."
    if overall >= 0.50:
        return "Acceptable quality. Try steadier shots and better lighting."
    return "Quality below target. Retake with more light and reduce motion blur."
