"""Partial Android video provenance policy (default queue vs opt-in auto-clear)."""

from __future__ import annotations

from app.services.camera_provenance import CameraProvenanceResult
from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy
from app.services.probe_provenance_policy import apply_probe_provenance_policy


def _android_partial_fields() -> list[dict[str, str]]:
    return [
        {"key": "major_brand", "label": "major_brand", "value": "mp42"},
        {"key": "creation_time", "label": "creation_time", "value": "2026-10-13T12:19:39.000000Z"},
        {"key": "com.android.version", "label": "com.android.version", "value": "11"},
    ]


def _low_waverep_ai() -> dict:
    return {
        "verdict": "authentic",
        "probability": 0.08,
        "raw_detector_probability": 0.08,
        "risk_level": "low",
        "requires_review": False,
        "detector_backend": "waverep_g4",
        "waverep_processing_status": "complete",
    }


def test_partial_android_default_still_requires_review() -> None:
    prov = CameraProvenanceResult(
        "partial",
        reasons=["Container creation timestamp without full device identity."],
        safe_fields=_android_partial_fields(),
        is_video=True,
    )
    merged = apply_probe_provenance_policy(_low_waverep_ai(), prov, file_name="1000442106.mp4")
    assert merged["requires_review"] is True
    assert merged["primary_review_driver"] == "provenance_partial_android"


def test_partial_android_member_message_not_ai_accusation() -> None:
    prov = CameraProvenanceResult(
        "partial",
        reasons=["Container creation timestamp without full device identity."],
        safe_fields=_android_partial_fields(),
        is_video=True,
    )
    merged = apply_probe_provenance_policy(_low_waverep_ai(), prov, file_name="1000442106.mp4")
    payload = apply_integrity_evaluation_policy(
        {
            "ai_detection": merged,
            "legacy": {"overall_score": 3.2},
            "ai_feedback": "Quality notes",
        }
    )
    msg = payload.get("member_integrity_message") or ""
    assert "low AI-generation risk" in msg
    assert "not treated as AI-generated" in msg


def test_partial_android_auto_clear_only_when_flag_enabled(monkeypatch) -> None:
    from app.config import settings

    monkeypatch.setattr(settings, "partial_android_video_auto_clear_enabled", True)
    prov = CameraProvenanceResult(
        "partial",
        reasons=["Container creation timestamp without full device identity."],
        safe_fields=_android_partial_fields(),
        is_video=True,
    )
    merged = apply_probe_provenance_policy(_low_waverep_ai(), prov, file_name="1000442106.mp4")
    assert merged["requires_review"] is False
    assert merged["provenance_policy_outcome"] == "partial_provenance_informational"
