"""Member-facing score/Gemini/XP release gating until admin review completes."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.crud import evaluation as eval_crud
from app.services import gemini_service

MEMBER_UNDER_REVIEW_MESSAGE = (
    "This submission requires administrative review before its evaluation "
    "score and feedback can be released."
)

PENDING_REVIEW_STATUSES = frozenset({"pending_review", "needs_further_review"})

WITHHOLD_SCORES_FINAL_STATUSES = frozenset(
    {
        "confirmed_ai_generated",
        "verified_ai_generated",
        "rejected",
        "reupload_requested",
    }
)

RELEASE_SCORES_STATUSES = frozenset({"verified_human", "accepted_with_warning"})


def apply_review_gate_to_payload(payload: dict[str, Any]) -> dict[str, Any]:
    """Set release flags on evaluation payload before persistence."""
    out = dict(payload)
    ai = out.get("ai_detection") if isinstance(out.get("ai_detection"), dict) else {}
    requires = ai.get("requires_review") is True
    if requires:
        out["member_scores_released"] = False
        out["show_quality_feedback"] = False
        out["review_gate_message"] = MEMBER_UNDER_REVIEW_MESSAGE
        out.pop("gemini_feedback", None)
    else:
        out.setdefault("member_scores_released", True)
        out.setdefault("show_quality_feedback", True)
    return out


def member_may_view_scores(criteria: dict[str, Any], review_status: str | None) -> bool:
    status = (review_status or "").strip().lower()
    if status in WITHHOLD_SCORES_FINAL_STATUSES:
        return False
    if status in RELEASE_SCORES_STATUSES:
        return True
    if status in PENDING_REVIEW_STATUSES:
        return False
    if criteria.get("member_scores_released") is True:
        return True
    ai = criteria.get("ai_detection") if isinstance(criteria.get("ai_detection"), dict) else {}
    if ai.get("requires_review") is True:
        return False
    return bool(criteria.get("member_scores_released", True))


def redact_criteria_json_for_member(criteria: dict[str, Any], review_status: str | None) -> dict[str, Any]:
    """Return member-safe criteria payload (keeps integrity audit fields)."""
    if member_may_view_scores(criteria, review_status):
        return criteria
    ai = criteria.get("ai_detection") if isinstance(criteria.get("ai_detection"), dict) else {}
    out: dict[str, Any] = {
        "media_type": criteria.get("media_type"),
        "scoring_model": criteria.get("scoring_model"),
        "scoring_engine": criteria.get("scoring_engine"),
        "ai_detection": ai,
        "integrity_tier": criteria.get("integrity_tier"),
        "member_scores_released": False,
        "show_quality_feedback": False,
        "review_gate_message": criteria.get("review_gate_message") or MEMBER_UNDER_REVIEW_MESSAGE,
        "xp_pending": criteria.get("xp_pending"),
        "xp_eligible": criteria.get("xp_eligible"),
        "member_integrity_message": criteria.get("member_integrity_message"),
        "quality_provisional": criteria.get("quality_provisional"),
    }
    return out


_LIST_CRITERIA_KEEP_KEYS = (
    "media_type",
    "scoring_model",
    "scoring_engine",
    "scoring_formula_version",
    "overall_score",
    "improvement_suggestions",
    "ai_detection",
    "integrity_tier",
    "member_scores_released",
    "show_quality_feedback",
    "quality_provisional",
    "review_gate_message",
    "xp_pending",
    "xp_eligible",
    "xp_multiplier",
    "xp_points_preview",
    "xp_awarded_at_review",
    "xp_awarded_points",
    "member_integrity_message",
    "evaluation_status",
    "evaluation_available",
)

# List integrity pills need verdict/risk flags, not EXIF dumps or detector signal arrays.
_LIST_AI_DETECTION_KEEP_KEYS = (
    "verdict",
    "confidence",
    "detail",
    "probability",
    "analysis_status",
    "is_final",
    "risk_level",
    "requires_review",
    "camera_provenance_strength",
    "provenance_policy_outcome",
    "visual_risk_level",
    "detector_backend",
    "waverep_frames_analyzed",
    "waverep_requested_frames",
    "waverep_processing_status",
    "waverep_analysis_unavailable",
    "is_video_provenance",
    "primary_review_driver",
    "admin_review_triggers",
    "raw_detector_probability",
    "visual_ai_probability",
)


def _slim_ai_detection_for_list(ai: Any) -> Any:
    if not isinstance(ai, dict):
        return ai
    return {k: ai[k] for k in _LIST_AI_DETECTION_KEEP_KEYS if k in ai}


def _slim_criteria_rows_for_list(criteria: Any) -> list[dict[str, Any]] | None:
    """Name/score/suggestion only — no EXIF or long rubric dumps."""
    if not isinstance(criteria, list):
        return None
    out: list[dict[str, Any]] = []
    for row in criteria:
        if not isinstance(row, dict):
            continue
        name = str(row.get("name") or "").strip()
        if not name:
            continue
        available = row.get("available")
        if available is None:
            available = row.get("score") is not None
        suggestion = str(row.get("suggestion") or "").strip()
        if len(suggestion) > 220:
            suggestion = suggestion[:217].rstrip() + "..."
        out.append(
            {
                "name": name,
                "score": row.get("score"),
                "available": bool(available),
                "suggestion": suggestion,
                "explanation": "",
            }
        )
    return out or None


def slim_criteria_json_for_member_list(criteria_json: str | None) -> str | None:
    """Drop heavy rubric blobs from list responses; keep integrity/status fields for cards.

    Full criteria remain on detail fetches (``GET /evaluations?media_id=``).
    Held-score redaction already removes scores before this runs.
    """
    if not criteria_json or not str(criteria_json).strip():
        return criteria_json
    try:
        parsed = json.loads(criteria_json)
    except (json.JSONDecodeError, TypeError):
        return criteria_json
    if not isinstance(parsed, dict):
        return criteria_json
    slim = {k: parsed[k] for k in _LIST_CRITERIA_KEEP_KEYS if k in parsed}
    if "ai_detection" in slim:
        slim["ai_detection"] = _slim_ai_detection_for_list(slim["ai_detection"])
    # List cards need media_type even when other keys are missing.
    if "media_type" not in slim and parsed.get("media_type") is not None:
        slim["media_type"] = parsed.get("media_type")
    # Prefer top-level formula version; fall back to analysis stamp (Clarity Option C = v2).
    if "scoring_formula_version" not in slim:
        analysis = parsed.get("analysis")
        if isinstance(analysis, dict) and analysis.get("scoring_formula_version") is not None:
            slim["scoring_formula_version"] = analysis.get("scoring_formula_version")
    if "improvement_suggestions" in slim and slim["improvement_suggestions"] is not None:
        tip = str(slim["improvement_suggestions"]).strip()
        if len(tip) > 400:
            slim["improvement_suggestions"] = tip[:397].rstrip() + "..."
    criteria_rows = _slim_criteria_rows_for_list(parsed.get("criteria"))
    if criteria_rows is not None:
        slim["criteria"] = criteria_rows
    return json.dumps(slim)


def release_member_evaluation_scores(
    db: Session,
    media_id: int,
    *,
    member_first_name: str | None = None,
) -> bool:
    """Release held technical scores and generate Gemini once after admin verifies human."""
    ev = eval_crud.get_for_media(db, media_id)
    if not ev or not ev.criteria_json:
        return False
    try:
        data = json.loads(ev.criteria_json)
    except json.JSONDecodeError:
        return False

    if data.get("member_scores_released") and gemini_service.is_valid_gemini_feedback(
        data.get("gemini_feedback")
    ):
        return True

    data["member_scores_released"] = True
    data["show_quality_feedback"] = True
    data["quality_provisional"] = False
    data.pop("review_gate_message", None)

    # Retry while feedback is missing/invalid. Stamp gemini_generated_at only on success.
    if not gemini_service.is_valid_gemini_feedback(data.get("gemini_feedback")):
        feedback = gemini_service.generate_media_evaluation_feedback(
            data,
            member_first_name=member_first_name or "Member",
        )
        if gemini_service.is_valid_gemini_feedback(feedback):
            data["gemini_feedback"] = feedback
            data["gemini_generated_at"] = datetime.now(timezone.utc).isoformat()

    # Remove outdated review-only messages after administrator approval.
    # Preserve legitimate technical feedback and any generated Gemini explanation.
    from app.services.integrity_evaluation_policy import (
        _PARTIAL_PROVENANCE_MEMBER_MESSAGE,
        _SOURCE_UNVERIFIED_MEMBER_MESSAGE,
        _SUSPICIOUS_MEMBER_MESSAGE,
        _AI_GENERATED_MEMBER_MESSAGE,
    )

    stale_messages = (
        _PARTIAL_PROVENANCE_MEMBER_MESSAGE,
        _SOURCE_UNVERIFIED_MEMBER_MESSAGE,
        _SUSPICIOUS_MEMBER_MESSAGE,
        _AI_GENERATED_MEMBER_MESSAGE,
        MEMBER_UNDER_REVIEW_MESSAGE,
    )

    data.pop("member_integrity_message", None)
    data.pop("review_gate_message", None)

    if isinstance(data.get("ai_feedback"), str):
        cleaned = data["ai_feedback"].strip()
        for warning in stale_messages:
            if cleaned.startswith(warning):
                cleaned = cleaned[len(warning):].strip()
        data["ai_feedback"] = cleaned

    if isinstance(ev.feedback, str):
        cleaned = ev.feedback.strip()
        for warning in stale_messages:
            if cleaned.startswith(warning):
                cleaned = cleaned[len(warning):].strip()
        ev.feedback = cleaned

    ev.criteria_json = json.dumps(data)
    if isinstance(data.get("gemini_feedback"), dict):
        explanation = data["gemini_feedback"].get("explanation")
        if explanation:
            ev.feedback = str(explanation)[:4000]
    return True


def evaluation_row_for_member(
    *,
    criteria_json: str | None,
    review_status: str | None,
    overall_score: float | None,
    feedback: str | None,
    sharpness_score: float | None,
    brightness_score: float | None,
    contrast_score: float | None,
    blur_score: float | None,
    noise_score: float | None,
    quality_level: str | None,
    recommendation: str | None,
) -> tuple[str | None, float, str, float, float, float, float, float, str | None, str | None]:
    """Redact DB row fields for member list/detail APIs."""
    status = (review_status or "").strip().lower()
    status_withholds = (
        status in WITHHOLD_SCORES_FINAL_STATUSES or status in PENDING_REVIEW_STATUSES
    )
    parsed: dict[str, Any] | None = None
    if criteria_json:
        try:
            loaded = json.loads(criteria_json)
        except json.JSONDecodeError:
            loaded = None
        if isinstance(loaded, dict):
            parsed = loaded
    if status_withholds or (parsed is not None and not member_may_view_scores(parsed, review_status)):
        gate = MEMBER_UNDER_REVIEW_MESSAGE
        redacted_json = criteria_json
        if parsed is not None:
            redacted = redact_criteria_json_for_member(parsed, review_status)
            gate = redacted.get("review_gate_message") or gate
            redacted_json = json.dumps(redacted)
        return (
            redacted_json,
            0.0,
            gate,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            None,
            None,
        )
    return (
        criteria_json,
        overall_score,
        feedback,
        sharpness_score,
        brightness_score,
        contrast_score,
        blur_score,
        noise_score,
        quality_level,
        recommendation,
    )
