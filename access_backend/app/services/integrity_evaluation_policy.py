"""Tiered member feedback + XP rules when AI integrity flags an upload."""

from __future__ import annotations

from typing import Any

from app.services.member_score_release import apply_review_gate_to_payload

INTEGRITY_TIER_AUTHENTIC = "authentic"
INTEGRITY_TIER_SUSPICIOUS = "suspicious"
INTEGRITY_TIER_AI_GENERATED = "ai_generated"

_SUSPICIOUS_MEMBER_MESSAGE = (
    "This upload was flagged for integrity review. Technical scores below are provisional "
    "and may change after an officer verifies your media. XP will be awarded if your submission is approved."
)

_AI_GENERATED_MEMBER_MESSAGE = (
    "This upload was flagged as possible AI-generated content. Quality coaching is paused until "
    "an officer reviews your file. If verified as authentic, your scores and XP will be applied."
)

_SOURCE_UNVERIFIED_MEMBER_MESSAGE = (
    "The source of this upload could not be verified from original camera metadata. "
    "Technical scores are provisional until an officer completes review. "
    "XP will be awarded if your submission is approved."
)

_PARTIAL_PROVENANCE_MEMBER_MESSAGE = (
    "Camera metadata for this upload is incomplete or only partially verified. "
    "An officer must confirm the file before scores, coaching, and XP are released."
)


def integrity_tier_from_detection(ai_detection: dict[str, Any]) -> str:
    verdict = str(ai_detection.get("verdict", INTEGRITY_TIER_AUTHENTIC)).lower()
    if verdict in ("ai_generated", "ai"):
        return INTEGRITY_TIER_AI_GENERATED
    if verdict == "suspicious":
        return INTEGRITY_TIER_SUSPICIOUS
    return INTEGRITY_TIER_AUTHENTIC


def _xp_points_preview(payload: dict[str, Any]) -> int:
    preview = payload.get("xp_points_preview")
    if isinstance(preview, int):
        return max(0, preview)
    legacy = payload.get("legacy") if isinstance(payload.get("legacy"), dict) else {}
    overall = float(legacy.get("overall_score", 0))
    return max(0, int(round(overall * 100)))


def apply_integrity_evaluation_policy(payload: dict[str, Any]) -> dict[str, Any]:
    """Attach tier flags and adjust member-visible copy before save or API response."""
    ai = payload.get("ai_detection") if isinstance(payload.get("ai_detection"), dict) else {}
    tier = integrity_tier_from_detection(ai)
    out = dict(payload)
    out["integrity_tier"] = tier
    xp_preview = _xp_points_preview(out)

    prov_outcome = str(ai.get("provenance_policy_outcome") or "").lower()
    if prov_outcome in ("source_unverified", "source_partially_verified") and ai.get("requires_review"):
        integrity_msg = (
            _PARTIAL_PROVENANCE_MEMBER_MESSAGE
            if prov_outcome == "source_partially_verified"
            else _SOURCE_UNVERIFIED_MEMBER_MESSAGE
        )
        out["show_quality_feedback"] = False
        out["quality_provisional"] = True
        out["xp_eligible"] = False
        out["xp_multiplier"] = 0.0
        out["xp_points_preview"] = xp_preview
        out["xp_pending"] = True
        out["member_integrity_message"] = integrity_msg
        base = out.get("ai_feedback") or ""
        out["ai_feedback"] = f"{integrity_msg}\n\n{base}".strip()
        return apply_review_gate_to_payload(out)

    if tier == INTEGRITY_TIER_AUTHENTIC:
        if ai.get("requires_review") is True:
            prov_outcome = str(ai.get("provenance_policy_outcome") or "").lower()
            integrity_msg = (
                _PARTIAL_PROVENANCE_MEMBER_MESSAGE
                if prov_outcome == "source_partially_verified"
                else _SOURCE_UNVERIFIED_MEMBER_MESSAGE
            )
            out["show_quality_feedback"] = False
            out["quality_provisional"] = True
            out["xp_eligible"] = False
            out["xp_multiplier"] = 0.0
            out["xp_points_preview"] = xp_preview
            out["xp_pending"] = True
            out["member_integrity_message"] = integrity_msg
            base = out.get("ai_feedback") or ""
            out["ai_feedback"] = f"{integrity_msg}\n\n{base}".strip()
            return apply_review_gate_to_payload(out)
        out["show_quality_feedback"] = True
        out["quality_provisional"] = False
        out["xp_eligible"] = True
        out["xp_multiplier"] = 1.0
        out["xp_points_preview"] = xp_preview
        out["xp_pending"] = False
        return apply_review_gate_to_payload(out)

    if tier == INTEGRITY_TIER_SUSPICIOUS:
        out["show_quality_feedback"] = False
        out["quality_provisional"] = True
        out["xp_eligible"] = False
        out["xp_multiplier"] = 0.0
        out["xp_points_preview"] = xp_preview
        out["xp_pending"] = True
        out["member_integrity_message"] = _SUSPICIOUS_MEMBER_MESSAGE
        base = out.get("ai_feedback") or ""
        out["ai_feedback"] = f"{_SUSPICIOUS_MEMBER_MESSAGE}\n\n{base}".strip()
        return apply_review_gate_to_payload(out)

    out["show_quality_feedback"] = False
    out["quality_provisional"] = False
    out["xp_eligible"] = False
    out["xp_multiplier"] = 0.0
    out["xp_points_preview"] = xp_preview
    out["xp_pending"] = True
    out["member_integrity_message"] = _AI_GENERATED_MEMBER_MESSAGE
    out["ai_feedback"] = _AI_GENERATED_MEMBER_MESSAGE
    out["improvement_suggestions"] = ""
    return apply_review_gate_to_payload(out)


def finalize_member_evaluation_payload(payload: dict[str, Any]) -> dict[str, Any]:
    """After client Gemini merge, keep integrity-first member copy."""
    if payload.get("show_quality_feedback", True) and not payload.get("quality_provisional"):
        return payload

    out = dict(payload)
    if not out.get("show_quality_feedback", True):
        integrity_msg = out.get("member_integrity_message") or out.get("ai_feedback")
        if integrity_msg:
            out["ai_feedback"] = integrity_msg
        out["improvement_suggestions"] = ""
        return out

    msg = out.get("member_integrity_message")
    if msg:
        base = out.get("ai_feedback") or ""
        if not base.startswith(msg[: min(len(msg), 40)]):
            out["ai_feedback"] = f"{msg}\n\n{base}".strip()
    return out


def xp_award_points_from_payload(payload: dict[str, Any]) -> int:
    if not payload.get("xp_eligible", True):
        return 0
    mult = float(payload.get("xp_multiplier", 1.0))
    if mult <= 0:
        return 0
    return max(0, int(round(_xp_points_preview(payload) * mult)))
