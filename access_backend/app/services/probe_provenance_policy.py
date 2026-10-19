"""PROBE visual risk + camera provenance review policy overlay (does not alter P(fake))."""

from __future__ import annotations

from typing import Any

from app.services.camera_provenance import (
    CameraProvenanceResult,
    looks_like_reexported_media_filename,
    photo_has_credible_in_camera_identity,
    photo_has_make_and_model,
    photo_likely_download_or_resave,
    video_provenance_has_device_identity,
)
from app.services.ai_authenticity_detector import probe_risk_level_from_probability

SOURCE_UNVERIFIED_DETAIL = (
    "No reliable original camera provenance was found. Automated visual "
    "analysis indicates low AI risk, but the media source could not be "
    "verified. Administrative review is required."
)

_PARTIAL_LOW_DETAIL = (
    "Automated visual analysis indicates low AI risk. Camera provenance is "
    "only partially verified; scores may remain provisional until review if required."
)


def _normalize_photo_provenance(
    provenance: CameraProvenanceResult,
    *,
    file_name: str = "",
) -> CameraProvenanceResult:
    """Downloads often keep camera EXIF; bad filenames downgrade strong tags unless Make+Model are present."""
    if provenance.is_video:
        return provenance
    if not looks_like_reexported_media_filename(file_name):
        return provenance
    if photo_has_make_and_model(provenance):
        return provenance
    if provenance.strength != "strong":
        return provenance
    reasons = list(provenance.reasons)
    reasons.append("Filename suggests a gallery save or download; admin review required.")
    return CameraProvenanceResult(
        "partial",
        reasons=reasons,
        safe_fields=list(provenance.safe_fields),
        is_video=False,
    )


def _normalize_video_provenance(
    provenance: CameraProvenanceResult,
    *,
    file_name: str = "",
) -> CameraProvenanceResult:
    """Practice videos: do not treat encoder-only or gallery-save metadata as fully verified."""
    if not provenance.is_video:
        return provenance
    reasons = list(provenance.reasons)
    strength = provenance.strength
    has_device = video_provenance_has_device_identity(provenance.safe_fields)

    if strength == "strong" and not has_device:
        reasons.append("Video container lacks verified device make/model.")
        strength = "partial"

    if looks_like_reexported_media_filename(file_name) and strength == "strong":
        reasons.append("Filename suggests a gallery save or re-export; admin review required.")
        strength = "partial"

    if strength == provenance.strength and reasons == list(provenance.reasons):
        return provenance
    return CameraProvenanceResult(
        strength,
        reasons=reasons,
        safe_fields=list(provenance.safe_fields),
        is_video=True,
    )


def apply_probe_provenance_policy(
    ai_detection: dict[str, Any],
    provenance: CameraProvenanceResult,
    *,
    file_name: str = "",
) -> dict[str, Any]:
    """Merge provenance policy into ai_detection without changing probability fields."""
    provenance = _normalize_video_provenance(provenance, file_name=file_name)
    provenance = _normalize_photo_provenance(provenance, file_name=file_name)
    out = dict(ai_detection)
    exif_meta = out.get("exif_metadata") if isinstance(out.get("exif_metadata"), dict) else None
    p_raw = out.get("raw_detector_probability")
    if p_raw is None:
        p_raw = out.get("probability")
    visual_p = float(p_raw) if p_raw is not None else None
    visual_risk = str(out.get("risk_level") or "").lower()
    if visual_p is not None and not visual_risk:
        visual_risk = probe_risk_level_from_probability(visual_p)

    strength = provenance.strength
    prov_dict = provenance.to_dict()
    out.update(prov_dict)
    out["visual_ai_probability"] = out.get("probability")
    out["visual_risk_level"] = visual_risk

    requires_review = bool(out.get("requires_review"))
    outcome = _outcome_for(strength, visual_risk)

    if strength == "strong":
        if visual_risk == "low":
            requires_review = False
            outcome = "low_ai_risk"
        elif visual_risk == "suspicious":
            requires_review = True
            outcome = "elevated_ai_risk"
        else:
            requires_review = True
            outcome = "high_ai_risk"
    elif strength == "partial":
        if visual_risk == "low":
            video_needs_manual_review = provenance.is_video and (
                looks_like_reexported_media_filename(file_name)
                or not video_provenance_has_device_identity(provenance.safe_fields)
            )
            photo_needs_manual_review = photo_likely_download_or_resave(
                file_name=file_name,
                provenance=provenance,
                exif_metadata=exif_meta,
            )
            photo_auto_clear = (
                not provenance.is_video
                and not photo_needs_manual_review
                and photo_has_credible_in_camera_identity(provenance, file_name=file_name)
            )
            if video_needs_manual_review or photo_needs_manual_review:
                requires_review = True
                outcome = (
                    "source_unverified"
                    if photo_needs_manual_review and not provenance.is_video
                    else "source_partially_verified"
                )
                base = str(out.get("detail") or "")
                if photo_needs_manual_review and not provenance.is_video:
                    download_detail = (
                        "This file looks like a download, re-save, or export without verified "
                        "in-camera provenance. Administrative review is required before scores "
                        "and coaching are released."
                    )
                    if download_detail not in base:
                        out["detail"] = download_detail if not base else f"{base} {download_detail}".strip()
                else:
                    partial_detail = (
                        f"{_PARTIAL_LOW_DETAIL} Administrative review is required before "
                        "scores and coaching are released."
                    )
                    if partial_detail not in base:
                        out["detail"] = f"{base} {partial_detail}".strip()
            elif photo_auto_clear:
                requires_review = False
                outcome = "low_ai_risk"
            else:
                requires_review = True
                outcome = "source_partially_verified"
        else:
            requires_review = True
            outcome = "elevated_ai_risk" if visual_risk == "suspicious" else "high_ai_risk"
    else:  # absent
        requires_review = True
        if visual_risk == "low":
            outcome = "source_unverified"
            out["detail"] = SOURCE_UNVERIFIED_DETAIL
            if out.get("verdict") == "authentic":
                pass
        elif visual_risk == "suspicious":
            outcome = "elevated_ai_risk"
        else:
            outcome = "high_ai_risk"

    out["provenance_policy_outcome"] = outcome
    out["requires_review"] = requires_review
    out["final_review_required"] = requires_review
    return out


def _outcome_for(strength: str, visual_risk: str) -> str:
    if visual_risk == "low":
        if strength == "strong":
            return "low_ai_risk"
        if strength == "partial":
            return "source_partially_verified"
        return "source_unverified"
    if visual_risk == "suspicious":
        return "elevated_ai_risk"
    return "high_ai_risk"
