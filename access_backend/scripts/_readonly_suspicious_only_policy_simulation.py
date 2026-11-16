"""Read-only simulation: current vs proposed suspicious-only video provenance policy.

Does not modify DB, review statuses, scores, or production policy code.
Stdout JSON summary; optional --out path under evaluation_results/.
"""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Repo imports (run from access_backend: python scripts/_readonly_suspicious_only_policy_simulation.py)
from app.crud import evaluation as eval_crud
from app.database import SessionLocal
from app.models.ai_detection_result import AiDetectionResult
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_file import MediaFile
from app.services.ai_authenticity_detector import probe_risk_level_from_probability
from app.services.ai_review_workflow import initial_review_status
from app.services.camera_provenance import (
    CameraProvenanceResult,
    video_has_android_container_support,
    video_provenance_has_device_identity,
)
from app.services.media_pipeline import _ai_from_payload, _should_notify_admin_ai_flag
from app.services.probe_provenance_policy import apply_probe_provenance_policy
from app.crud.evaluation import PENDING_INTEGRITY_STATUSES

SECURITY_FLAG_CODES = frozenset({"ai_software_exif", "ai_hint_filename"})

VERIFIED_HUMAN = frozenset({"verified_human", "accepted_with_warning"})
CONFIRMED_AI = frozenset(
    {"confirmed_ai_generated", "verified_ai_generated", "rejected"}
)


def _parse_json(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def _is_practice_video(media: MediaFile, exif: dict[str, Any]) -> bool:
    if getattr(media, "media_category", None) != MEDIA_CATEGORY_EVALUATION:
        return False
    if exif.get("is_video") is True:
        return True
    ft = (getattr(media, "file_type", None) or "").lower()
    if "video" in ft:
        return True
    fn = (media.file_name or "").lower()
    return fn.endswith((".mp4", ".mov", ".webm", ".mkv", ".m4v", ".3gp"))


def provenance_from_exif(exif: dict[str, Any]) -> CameraProvenanceResult:
    strength = str(exif.get("camera_provenance_strength") or "absent").lower()
    if strength not in ("strong", "partial", "absent"):
        strength = "absent"
    reasons = exif.get("camera_provenance_reasons")
    if not isinstance(reasons, list):
        reasons = []
    fields = exif.get("fields")
    if not isinstance(fields, list):
        fields = []
    safe = [f for f in fields if isinstance(f, dict)]
    is_video = exif.get("is_video") is True or exif.get("format") == "video_container"
    return CameraProvenanceResult(
        strength,
        reasons=[str(r) for r in reasons],
        safe_fields=safe,
        is_video=is_video,
    )


def _security_flags(exif_meta: dict[str, Any] | None) -> set[str]:
    flags = (exif_meta or {}).get("flags") or []
    codes: set[str] = set()
    for flag in flags:
        if isinstance(flag, dict) and flag.get("code"):
            codes.add(str(flag["code"]))
    return codes


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


def visual_risk_low(ai: dict[str, Any]) -> bool:
    risk = str(ai.get("risk_level") or ai.get("visual_risk_level") or "").lower()
    if risk:
        return risk == "low"
    p = ai.get("raw_detector_probability")
    if p is None:
        p = ai.get("probability")
    if p is None:
        return False
    return probe_risk_level_from_probability(float(p)) == "low"


def apply_probe_provenance_policy_proposed(
    ai_detection: dict[str, Any],
    provenance: CameraProvenanceResult,
    *,
    file_name: str = "",
) -> dict[str, Any]:
    """Script-only fork: informational partial Android video may auto-clear at low visual risk."""
    from app.services.probe_provenance_policy import (
        _normalize_photo_provenance,
        _normalize_video_provenance,
        _outcome_for,
        _PARTIAL_LOW_DETAIL,
        SOURCE_UNVERIFIED_DETAIL,
    )
    from app.services.camera_provenance import (
        photo_has_credible_in_camera_identity,
        photo_likely_download_or_resave,
        video_filename_suggests_reexport,
    )

    provenance = _normalize_video_provenance(provenance, file_name=file_name)
    provenance = _normalize_photo_provenance(provenance, file_name=file_name)
    out = dict(ai_detection)
    exif_meta = out.get("exif_metadata") if isinstance(out.get("exif_metadata"), dict) else None
    p_raw = out.get("raw_detector_probability")
    if p_raw is None:
        p_raw = out.get("probability")
    visual_risk = str(out.get("risk_level") or "").lower()
    if p_raw is not None and not visual_risk:
        visual_risk = probe_risk_level_from_probability(float(p_raw))

    strength = provenance.strength
    out.update(provenance.to_dict())
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
            reexport = video_filename_suggests_reexport(file_name, provenance)
            no_device = not video_provenance_has_device_identity(provenance.safe_fields)
            android_support = video_has_android_container_support(provenance)
            detector_ok = detector_analysis_complete(out)
            sec = _security_flags(exif_meta)

            proposed_android_informational = (
                provenance.is_video
                and not reexport
                and android_support
                and detector_ok
                and not (sec & SECURITY_FLAG_CODES)
            )

            if provenance.is_video:
                video_needs_manual_review = reexport or (
                    no_device and not proposed_android_informational
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
            elif photo_auto_clear or proposed_android_informational:
                requires_review = False
                outcome = (
                    "partial_provenance_informational"
                    if proposed_android_informational
                    else "low_ai_risk"
                )
            else:
                requires_review = True
                outcome = "source_partially_verified"
        else:
            requires_review = True
            outcome = "elevated_ai_risk" if visual_risk == "suspicious" else "high_ai_risk"
    else:
        requires_review = True
        if visual_risk == "low":
            outcome = "source_unverified"
            out["detail"] = SOURCE_UNVERIFIED_DETAIL
        elif visual_risk == "suspicious":
            outcome = "elevated_ai_risk"
        else:
            outcome = "high_ai_risk"

    sec = _security_flags(exif_meta)
    if sec & SECURITY_FLAG_CODES:
        requires_review = True
        outcome = "source_unverified" if visual_risk == "low" else outcome

    out["provenance_policy_outcome"] = outcome
    out["requires_review"] = requires_review
    out["final_review_required"] = requires_review
    return out


def _base_ai_from_row(
    ai_row: AiDetectionResult,
    exif: dict[str, Any],
    criteria: dict[str, Any],
) -> dict[str, Any]:
    stored = criteria.get("ai_detection") if isinstance(criteria.get("ai_detection"), dict) else {}
    base = deepcopy(stored) if stored else {}
    if not base:
        base = {
            "verdict": "authentic" if (ai_row.detection_result or "").lower() in ("human", "authentic") else ai_row.detection_result,
            "probability": ai_row.ai_probability,
            "raw_detector_probability": exif.get("visual_ai_probability", ai_row.ai_probability),
            "risk_level": exif.get("visual_risk_level"),
            "detector_backend": exif.get("detector_backend"),
            "requires_review": None,
        }
    if exif.get("detector_backend"):
        base["detector_backend"] = exif.get("detector_backend")
    if exif.get("visual_risk_level"):
        base["risk_level"] = exif.get("visual_risk_level")
    if exif.get("waverep_supplementary") and isinstance(exif["waverep_supplementary"], dict):
        supp = exif["waverep_supplementary"]
        for key in (
            "waverep_processing_status",
            "waverep_frames_analyzed",
            "waverep_analysis_unavailable",
        ):
            if key in supp:
                base[key] = supp[key]
    for key in (
        "waverep_processing_status",
        "waverep_analysis_unavailable",
        "waverep_frames_analyzed",
    ):
        if key in exif:
            base[key] = exif[key]
    base["exif_metadata"] = exif
    if base.get("requires_review") is None:
        base["requires_review"] = str(ai_row.review_status or "").lower() in PENDING_INTEGRITY_STATUSES
    return base


@dataclass
class SimRow:
    source: str
    media_id: int | None
    file_name: str
    review_status_stored: str | None
    admin_label: str
    current_requires: bool
    proposed_requires: bool
    current_outcome: str
    proposed_outcome: str
    provenance_strength: str
    visual_risk: str
    exempt_candidate: bool
    simulation_note: str


def _admin_label(status: str | None) -> str:
    s = (status or "").strip().lower()
    if s in VERIFIED_HUMAN:
        return "verified_genuine_admin"
    if s in CONFIRMED_AI:
        return "confirmed_ai_admin"
    if s in PENDING_INTEGRITY_STATUSES:
        return "pending_admin"
    if s == "automated_low_ai_risk":
        return "automated_low_risk"
    return s or "unknown"


def _simulate_one(
    *,
    source: str,
    media_id: int | None,
    file_name: str,
    ai_base: dict[str, Any],
    provenance: CameraProvenanceResult,
    review_status_stored: str | None,
) -> SimRow:
    ai_in = deepcopy(ai_base)
    ai_in.pop("provenance_policy_outcome", None)
    ai_in.pop("camera_provenance_strength", None)
    ai_in.pop("final_review_required", None)

    current = apply_probe_provenance_policy(ai_in, provenance, file_name=file_name)
    proposed = apply_probe_provenance_policy_proposed(deepcopy(ai_in), provenance, file_name=file_name)

    exempt = (
        provenance.is_video
        and provenance.strength == "partial"
        and visual_risk_low(current)
        and video_has_android_container_support(provenance)
        and not video_provenance_has_device_identity(provenance.safe_fields)
        and detector_analysis_complete(ai_in)
        and not (_security_flags(ai_in.get("exif_metadata")) & SECURITY_FLAG_CODES)
    )

    note = "ok"
    if not provenance.safe_fields and provenance.strength == "absent":
        note = "rebuilt_provenance_may_be_incomplete"

    return SimRow(
        source=source,
        media_id=media_id,
        file_name=file_name,
        review_status_stored=review_status_stored,
        admin_label=_admin_label(review_status_stored),
        current_requires=bool(current.get("requires_review")),
        proposed_requires=bool(proposed.get("requires_review")),
        current_outcome=str(current.get("provenance_policy_outcome") or ""),
        proposed_outcome=str(proposed.get("provenance_policy_outcome") or ""),
        provenance_strength=provenance.strength,
        visual_risk=str(current.get("visual_risk_level") or ai_in.get("risk_level") or ""),
        exempt_candidate=exempt,
        simulation_note=note,
    )


def _fixture_cases() -> list[tuple[str, dict[str, Any], CameraProvenanceResult, str]]:
    from app.services.waverep_g4_detector import _map_waverep_raw_to_ai_payload

    android_partial_fields = [
        {"key": "major_brand", "label": "major_brand", "value": "mp42"},
        {"key": "creation_time", "label": "creation_time", "value": "2026-10-13T12:19:39.000000Z"},
        {"key": "com.android.version", "label": "com.android.version", "value": "11"},
    ]
    partial_android = CameraProvenanceResult(
        "partial",
        reasons=["Container creation timestamp without full device identity."],
        safe_fields=android_partial_fields,
        is_video=True,
    )
    raw_low = {
        "model": "WaveRep G4",
        "requested_frames": 20,
        "processed_frames": 20,
        "failed_frames": [],
        "status": "complete",
        "mean_logit": -1.8,
        "ai_score": 0.135,
        "prediction": "Real / Non-AI",
        "threshold": 0.5,
        "frame_results": [],
    }
    waverep_low = _map_waverep_raw_to_ai_payload(raw_low)
    waverep_low["exif_metadata"] = {"flags": [], "fields": android_partial_fields, "is_video": True}

    absent = CameraProvenanceResult("absent", reasons=["No container metadata."], is_video=True)
    probe_low = {
        "verdict": "authentic",
        "probability": 0.05,
        "raw_detector_probability": 0.05,
        "risk_level": "low",
        "requires_review": False,
        "detector_backend": "probe",
        "exif_metadata": {"flags": [], "fields": []},
    }
    ai_flag = {
        **probe_low,
        "exif_metadata": {
            "flags": [{"code": "ai_hint_filename", "label": "hint", "severity": "warn"}],
            "fields": android_partial_fields,
        },
    }

    return [
        ("fixture_waverep_low_android_partial", waverep_low, partial_android, "1000442106.mp4"),
        ("fixture_probe_low_absent_video", probe_low, absent, "clip.mp4"),
        ("fixture_probe_low_partial_ai_filename", ai_flag, partial_android, "1000442106.mp4"),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Suspicious-only policy read-only simulation")
    parser.add_argument(
        "--out",
        type=str,
        default="",
        help="Optional JSON output path (under evaluation_results recommended)",
    )
    args = parser.parse_args()

    rows: list[SimRow] = []

    for name, ai, prov, fn in _fixture_cases():
        rows.append(
            _simulate_one(
                source=name,
                media_id=None,
                file_name=fn,
                ai_base=ai,
                provenance=prov,
                review_status_stored=None,
            )
        )

    db = SessionLocal()
    missing_rebuild = 0
    try:
        joined = (
            db.query(AiDetectionResult, MediaFile)
            .join(MediaFile, MediaFile.id == AiDetectionResult.media_id)
            .all()
        )
        for ai_row, media in joined:
            exif = _parse_json(ai_row.exif_metadata)
            if not _is_practice_video(media, exif):
                continue
            ev = eval_crud.get_for_media(db, media.id)
            criteria = _parse_json(ev.criteria_json if ev else None)
            prov = provenance_from_exif(exif)
            if prov.strength == "absent" and not prov.safe_fields:
                missing_rebuild += 1
            ai_base = _base_ai_from_row(ai_row, exif, criteria)
            rows.append(
                _simulate_one(
                    source="database",
                    media_id=media.id,
                    file_name=media.file_name or "",
                    ai_base=ai_base,
                    provenance=prov,
                    review_status_stored=ai_row.review_status,
                )
            )
    finally:
        db.close()

    db_rows = [r for r in rows if r.source == "database"]
    fixtures = [r for r in rows if r.source != "database"]

    def requires_review_stored(r: SimRow) -> bool:
        if r.review_status_stored:
            return r.review_status_stored.lower() in PENDING_INTEGRITY_STATUSES
        return r.current_requires

    current_req = sum(1 for r in db_rows if r.current_requires)
    proposed_req = sum(1 for r in db_rows if r.proposed_requires)
    would_clear = [
        r
        for r in db_rows
        if r.current_requires and not r.proposed_requires
    ]
    still_req = [r for r in db_rows if r.proposed_requires]

    false_clear_risk = [
        r
        for r in would_clear
        if r.admin_label == "confirmed_ai_admin"
    ]
    verified_cleared = [
        r for r in would_clear if r.admin_label == "verified_genuine_admin"
    ]
    pending_cleared = [
        r for r in would_clear if r.admin_label == "pending_admin"
    ]

    exempt_in_db = [r for r in db_rows if r.exempt_candidate]

    sample_would_clear = [
        {
            "media_id": r.media_id,
            "file_name": r.file_name,
            "review_status_stored": r.review_status_stored,
            "admin_label": r.admin_label,
            "current_outcome": r.current_outcome,
            "proposed_outcome": r.proposed_outcome,
        }
        for r in would_clear[:25]
    ]

    still_requires_detail = [
        {
            "media_id": r.media_id,
            "file_name": r.file_name,
            "review_status_stored": r.review_status_stored,
            "admin_label": r.admin_label,
            "provenance_strength": r.provenance_strength,
            "visual_risk": r.visual_risk,
            "proposed_outcome": r.proposed_outcome,
        }
        for r in still_req
    ]

    admin_outcome_counts = {}
    for r in db_rows:
        admin_outcome_counts[r.admin_label] = admin_outcome_counts.get(r.admin_label, 0) + 1

    report = {
        "simulation": "suspicious_only_admin_review_proposed",
        "read_only": True,
        "production_unchanged": True,
        "totals": {
            "records_analyzed": len(rows),
            "database_practice_videos": len(db_rows),
            "test_fixtures": len(fixtures),
            "missing_or_empty_provenance_rebuild": missing_rebuild,
        },
        "database_policy_comparison": {
            "current_requires_review_simulated": current_req,
            "proposed_requires_review_simulated": proposed_req,
            "would_avoid_review_count": len(would_clear),
            "still_requires_review_count": len(still_req),
            "stored_pending_review_status_count": sum(1 for r in db_rows if requires_review_stored(r)),
        },
        "admin_labeled_outcomes_among_would_clear": {
            "verified_genuine_admin": len(verified_cleared),
            "confirmed_ai_admin": len(false_clear_risk),
            "pending_admin": len(pending_cleared),
            "automated_low_risk_already": sum(
                1 for r in would_clear if r.admin_label == "automated_low_risk"
            ),
        },
        "potential_false_clearance_cases": [
            {
                "media_id": r.media_id,
                "file_name": r.file_name,
                "review_status_stored": r.review_status_stored,
                "note": "Proposed would auto-clear; admin labeled confirmed AI. Low risk does not prove genuine.",
            }
            for r in false_clear_risk
        ],
        "exempt_candidate_profile_count": len(exempt_in_db),
        "fixture_results": [
            {
                "source": r.source,
                "current_requires": r.current_requires,
                "proposed_requires": r.proposed_requires,
                "current_outcome": r.current_outcome,
                "proposed_outcome": r.proposed_outcome,
            }
            for r in fixtures
        ],
        "sample_would_clear": sample_would_clear,
        "still_requires_review_under_proposed": still_requires_detail,
        "stored_admin_status_distribution": admin_outcome_counts,
        "limitations": [
            "Provenance rebuilt from stored exif panel; original bytes not re-scanned.",
            "Base ai_detection may be partial when criteria_json lacked ai_detection.",
            "Admin labels are historical decisions, not ground-truth authenticity.",
            "Low AI risk is not treated as proof of genuine capture in this report.",
            "Does not re-run WaveRep/PROBE; uses persisted scores and metadata only.",
        ],
        "future_minimal_implementation_files": [
            "access_backend/app/services/probe_provenance_policy.py",
            "access_backend/tests/test_video_provenance_phase21.py",
            "access_backend/tests/test_practice_evaluation_video_guardrails.py",
            "access_backend/app/services/integrity_evaluation_policy.py",
            "lib/shared/utils/member_integrity_display.dart",
        ],
    }

    text = json.dumps(report, indent=2)
    print(text)
    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
