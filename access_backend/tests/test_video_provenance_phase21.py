"""Phase 2.1: video numeric filename + container provenance (no ML)."""

from __future__ import annotations

from app.services.camera_provenance import (
    CameraProvenanceResult,
    looks_like_reexported_media_filename,
    video_filename_suggests_reexport,
    video_has_android_container_support,
    video_provenance_has_device_identity,
)
from app.services.probe_provenance_policy import apply_probe_provenance_policy
from app.services.waverep_g4_detector import _map_waverep_raw_to_ai_payload


def _android_partial_fields() -> list[dict[str, str]]:
    return [
        {"key": "major_brand", "label": "major_brand", "value": "mp42"},
        {"key": "creation_time", "label": "creation_time", "value": "2026-10-13T12:19:39.000000Z"},
        {"key": "com.android.version", "label": "com.android.version", "value": "11"},
    ]


def _media249_partial() -> CameraProvenanceResult:
    return CameraProvenanceResult(
        "partial",
        reasons=["Container creation timestamp without full device identity."],
        safe_fields=_android_partial_fields(),
        is_video=True,
    )


def test_numeric_android_filename_not_generic_reexport() -> None:
    prov = _media249_partial()
    # Photos still use looks_like_reexported (numeric stems remain suspicious).
    assert looks_like_reexported_media_filename("1000442106.jpg") is True
    assert video_has_android_container_support(prov) is True
    assert video_filename_suggests_reexport("1000442106.mp4", prov) is False


def test_numeric_photo_filename_unchanged_for_photos() -> None:
    assert looks_like_reexported_media_filename("1000442106.jpg") is True


def test_numeric_filename_without_container_support() -> None:
    empty = CameraProvenanceResult("absent", reasons=[], safe_fields=[], is_video=True)
    assert video_filename_suggests_reexport("1000442106.mp4", empty) is True
    assert video_filename_suggests_reexport("1000442106.mp4", None) is True


def test_editor_export_filename_still_reexport() -> None:
    assert looks_like_reexported_media_filename("screen_record_2026.mp4") is True
    assert video_filename_suggests_reexport("download.mp4", _media249_partial()) is True


def test_strong_device_metadata_identity() -> None:
    fields = _android_partial_fields() + [
        {"key": "com.android.manufacturer", "label": "com.android.manufacturer", "value": "INFINIX"},
        {"key": "com.android.model", "label": "com.android.model", "value": "X695"},
    ]
    assert video_provenance_has_device_identity(fields) is True


def test_partial_without_make_model_no_identity() -> None:
    assert video_provenance_has_device_identity(_android_partial_fields()) is False


def test_waverep_low_complete_partial_still_requires_review() -> None:
    raw = {
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
    ai = _map_waverep_raw_to_ai_payload(raw)
    assert ai["requires_review"] is False
    assert ai["risk_level"] == "low"

    merged = apply_probe_provenance_policy(ai, _media249_partial(), file_name="1000442106.mp4")
    assert merged["probability"] == 0.135
    assert merged["requires_review"] is True
    assert merged["final_review_required"] is True
    assert merged["provenance_policy_outcome"] == "source_partially_verified"
    assert merged["camera_provenance_strength"] == "partial"


def test_malformed_empty_provenance_numeric_filename() -> None:
    prov = CameraProvenanceResult("absent", reasons=["Could not read video container metadata."], is_video=True)
    assert video_has_android_container_support(prov) is False
    assert video_filename_suggests_reexport("999888777.mp4", prov) is True


def test_conflicting_ai_filename_flag_still_review() -> None:
    ai = {
        "verdict": "authentic",
        "probability": 0.05,
        "raw_detector_probability": 0.05,
        "risk_level": "low",
        "requires_review": False,
        "detector_backend": "probe",
        "exif_metadata": {
            "flags": [{"code": "ai_hint_filename", "label": "AI filename hint", "severity": "warn"}],
        },
    }
    strong = CameraProvenanceResult(
        "strong",
        reasons=["Device tags present."],
        safe_fields=[
            {"key": "Make", "label": "Make", "value": "Apple"},
            {"key": "Model", "label": "Model", "value": "iPhone"},
        ],
        is_video=False,
    )
    out = apply_probe_provenance_policy(ai, strong, file_name="midjourney_export.jpg")
    assert out["requires_review"] is True
