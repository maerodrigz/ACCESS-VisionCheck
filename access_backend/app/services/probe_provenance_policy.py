"""PROBE visual risk + camera provenance review policy overlay (does not alter P(fake))."""

from __future__ import annotations

from typing import Any

from app.services.camera_provenance import (
    CameraProvenanceResult,
    looks_like_reexported_media_filename,
    photo_has_credible_in_camera_identity,
    photo_has_make_and_model,
    photo_likely_download_or_resave,
    video_filename_suggests_reexport,
    video_has_android_container_support,
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

_PARTIAL_ANDROID_VIDEO_DETAIL = (
    "Automated video screening shows low AI-generation risk. Android container "
    "metadata is present (for example timestamp or OS version), but camera "
    "manufacturer and model are not in this file. Missing device tags alone do "
    "not mean the video is AI-generated. Administrative review is required under "
    "current policy before scores and coaching are released."
)

SECURITY_FLAG_CODES = frozenset({"ai_software_exif", "ai_hint_filename"})

_REVIEW_DRIVER_PRIORITY = (
    "detector_unavailable",
    "security_ai_metadata",
    "visual_high",
    "visual_suspicious",
    "filename_reexport",
    "provenance_absent",
    "provenance_partial_android",
    "provenance_partial_other",
    "provenance_download_resave",
    "combined",
)


def detector_analysis_complete(ai: dict[str, Any]) -> bool:
    if ai.get("waverep_analysis_unavailable") is True:
        return False
    backend = str(ai.get("detector_backend") or "").strip().lower()
    status = str(ai.get("waverep_processing_status") or "").lower()
    if backend == "waverep_g4" or backend.startswith("waverep"):
        if status in ("partial", "unavailable", "failed"):
            return False
        if ai.get("probability") is None and ai.get("raw_detector_probability") is None:
            return False
        return True
    if backend == "probe":
        return ai.get("raw_detector_probability") is not None or ai.get("probability") is not None
    return ai.get("probability") is not None or ai.get("raw_detector_probability") is not None


def merge_provenance_policy_exif_fields(payload: dict[str, Any]) -> dict[str, Any]:
    """Copy provenance policy fields into exif_metadata for admin UI persistence."""
    meta = payload.get("exif_metadata")
    if not isinstance(meta, dict):
        meta = {}
    else:
        meta = dict(meta)
    for key in (
        "camera_provenance_strength",
        "camera_provenance_reasons",
        "camera_provenance_fields",
        "visual_ai_probability",
        "visual_risk_level",
        "provenance_policy_outcome",
        "admin_review_triggers",
        "primary_review_driver",
        "is_video_provenance",
    ):
        if key in payload:
            meta[key] = payload[key]
    payload["exif_metadata"] = meta
    return payload


def _security_flags(exif_meta: dict[str, Any] | None) -> set[str]:
    flags = (exif_meta or {}).get("flags") or []
    codes: set[str] = set()
    for flag in flags:
        if isinstance(flag, dict) and flag.get("code"):
            codes.add(str(flag["code"]))
    return codes


def _primary_review_driver(triggers: list[str]) -> str:
    trigger_set = set(triggers)
    for driver in _REVIEW_DRIVER_PRIORITY:
        if driver in trigger_set:
            return driver
    if triggers:
        return triggers[0]
    return "combined"


def _attach_admin_review_triggers(
    out: dict[str, Any],
    *,
    provenance: CameraProvenanceResult,
    file_name: str,
    visual_risk: str,
    exif_meta: dict[str, Any] | None,
    requires_review: bool,
) -> dict[str, Any]:
    triggers: list[str] = []
    if visual_risk == "high":
        triggers.append("visual_high")
    elif visual_risk == "suspicious":
        triggers.append("visual_suspicious")

    if provenance.is_video and not detector_analysis_complete(out):
        triggers.append("detector_unavailable")

    sec = _security_flags(exif_meta)
    if sec & SECURITY_FLAG_CODES:
        triggers.append("security_ai_metadata")

    if provenance.strength == "absent":
        triggers.append("provenance_absent")
    elif provenance.strength == "partial":
        reexport = video_filename_suggests_reexport(file_name, provenance)
        no_device = not video_provenance_has_device_identity(provenance.safe_fields)
        android_support = video_has_android_container_support(provenance)
        if provenance.is_video and reexport:
            triggers.append("filename_reexport")
        elif provenance.is_video and no_device and android_support:
            triggers.append("provenance_partial_android")
        elif provenance.is_video and no_device:
            triggers.append("provenance_partial_other")
        elif not provenance.is_video and photo_likely_download_or_resave(
            file_name=file_name,
            provenance=provenance,
            exif_metadata=exif_meta,
        ):
            triggers.append("provenance_download_resave")
        else:
            triggers.append("provenance_partial_other")

    if requires_review and len(triggers) > 1:
        if "visual_high" in triggers or "visual_suspicious" in triggers:
            pass
        elif len(triggers) >= 2:
            triggers.append("combined")

    # De-dupe while preserving order
    seen: set[str] = set()
    ordered: list[str] = []
    for t in triggers:
        if t in seen:
            continue
        seen.add(t)
        ordered.append(t)

    out["admin_review_triggers"] = ordered
    if requires_review:
        out["primary_review_driver"] = _primary_review_driver(ordered)
    else:
        out["primary_review_driver"] = "none"
    return out


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

    if video_filename_suggests_reexport(file_name, provenance) and strength == "strong":
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
    from app.config import settings

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

    auto_clear_android = bool(settings.partial_android_video_auto_clear_enabled)

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
            reexport = video_filename_suggests_reexport(file_name, provenance)
            no_device = not video_provenance_has_device_identity(provenance.safe_fields)
            android_support = video_has_android_container_support(provenance)
            detector_ok = detector_analysis_complete(out)
            sec = _security_flags(exif_meta)

            android_informational_auto_clear = (
                auto_clear_android
                and provenance.is_video
                and not reexport
                and android_support
                and detector_ok
                and not (sec & SECURITY_FLAG_CODES)
            )

            if provenance.is_video:
                video_needs_manual_review = reexport or (
                    no_device and not android_informational_auto_clear
                )
            else:
                video_needs_manual_review = False

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
                elif (
                    provenance.is_video
                    and no_device
                    and android_support
                    and not reexport
                ):
                    if _PARTIAL_ANDROID_VIDEO_DETAIL not in base:
                        out["detail"] = (
                            f"{base} {_PARTIAL_ANDROID_VIDEO_DETAIL}".strip()
                            if base
                            else _PARTIAL_ANDROID_VIDEO_DETAIL
                        )
                else:
                    partial_detail = (
                        f"{_PARTIAL_LOW_DETAIL} Administrative review is required before "
                        "scores and coaching are released."
                    )
                    if partial_detail not in base:
                        out["detail"] = f"{base} {partial_detail}".strip()
            elif photo_auto_clear or android_informational_auto_clear:
                requires_review = False
                outcome = (
                    "partial_provenance_informational"
                    if android_informational_auto_clear
                    else "low_ai_risk"
                )
                if android_informational_auto_clear:
                    base = str(out.get("detail") or "")
                    info = (
                        "Low AI-generation risk with partial Android container metadata. "
                        "Auto-cleared under PARTIAL_ANDROID_VIDEO_AUTO_CLEAR policy."
                    )
                    if info not in base:
                        out["detail"] = f"{base} {info}".strip() if base else info
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

    # Explicit AI-related metadata indicators must not be cleared
    # solely because camera EXIF appears credible or PROBE risk is low.
    flags = (exif_meta or {}).get("flags") or []
    security_flag_codes = {
        str(flag.get("code"))
        for flag in flags
        if isinstance(flag, dict) and flag.get("code")
    }
    if security_flag_codes & {"ai_software_exif", "ai_hint_filename"}:
        requires_review = True
        outcome = "source_unverified" if visual_risk == "low" else outcome
        out["detail"] = (
            f"{str(out.get('detail') or '').strip()} "
            "AI-related metadata indicator requires administrative verification."
        ).strip()

    out["provenance_policy_outcome"] = outcome
    out["requires_review"] = requires_review
    out["final_review_required"] = requires_review
    out = _attach_admin_review_triggers(
        out,
        provenance=provenance,
        file_name=file_name,
        visual_risk=visual_risk,
        exif_meta=exif_meta,
        requires_review=requires_review,
    )
    return merge_provenance_policy_exif_fields(out)


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
