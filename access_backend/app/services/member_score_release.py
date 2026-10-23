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

    if data.get("member_scores_released") and data.get("gemini_feedback"):
        return True

    data["member_scores_released"] = True
    data["show_quality_feedback"] = True
    data["quality_provisional"] = False
    data.pop("review_gate_message", None)

    if not data.get("gemini_feedback") and not data.get("gemini_generated_at"):
        feedback = gemini_service.generate_media_evaluation_feedback(
            data,
            member_first_name=member_first_name or "Member",
        )
        if feedback:
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
    overall_score: float,
    feedback: str,
    sharpness_score: float,
    brightness_score: float,
    contrast_score: float,
    blur_score: float,
    noise_score: float,
    quality_level: str | None,
    recommendation: str | None,
) -> tuple[str | None, float, str, float, float, float, float, float, str | None, str | None]:
    """Redact DB row fields for member list/detail APIs."""
    if not criteria_json:
        return criteria_json, overall_score, feedback, sharpness_score, brightness_score, contrast_score, blur_score, noise_score, quality_level, recommendation
    try:
        parsed = json.loads(criteria_json)
    except json.JSONDecodeError:
        return criteria_json, overall_score, feedback, sharpness_score, brightness_score, contrast_score, blur_score, noise_score, quality_level, recommendation
    if not isinstance(parsed, dict):
        return criteria_json, overall_score, feedback, sharpness_score, brightness_score, contrast_score, blur_score, noise_score, quality_level, recommendation
    if member_may_view_scores(parsed, review_status):
        return criteria_json, overall_score, feedback, sharpness_score, brightness_score, contrast_score, blur_score, noise_score, quality_level, recommendation
    redacted = redact_criteria_json_for_member(parsed, review_status)
    gate_msg = redacted.get("review_gate_message") or MEMBER_UNDER_REVIEW_MESSAGE
    return (
        json.dumps(redacted),
        0.0,
        gate_msg,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        None,
        None,
    )
