"""Camera provenance + PROBE policy overlay (mocked, no ML)."""

from __future__ import annotations

import io
import json
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from app.services.ai_authenticity_detector import detect_ai_generated, detect_ai_generated_from_frames
from app.services.ai_review_workflow import PROBE_LOW_RISK_REVIEW_STATUS, initial_review_status
from app.services.camera_provenance import CameraProvenanceResult, classify_photo_camera_provenance
from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy, xp_award_points_from_payload
from app.services.media_pipeline import _ai_from_payload, _should_notify_admin_ai_flag
from app.services.probe_provenance_policy import apply_probe_provenance_policy

PROBE_BACKEND = "app.services.ai_authenticity_detector.active_ai_detector_backend"
PROBE_PROB = "app.services.ai_authenticity_detector.dedicated_ai_probability"
CLASSIFY_PHOTO = "app.services.camera_provenance.classify_photo_camera_provenance"
CLASSIFY_VIDEO = "app.services.camera_provenance.classify_video_container_provenance"


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (48, 48), color=(40, 80, 120)).save(buf, format="JPEG")
    return buf.getvalue()


def _strong() -> CameraProvenanceResult:
    return CameraProvenanceResult("strong", reasons=["Coherent camera EXIF (test)."])


def _absent() -> CameraProvenanceResult:
    return CameraProvenanceResult("absent", reasons=["No credible camera-origin metadata."])


def _partial() -> CameraProvenanceResult:
    return CameraProvenanceResult("partial", reasons=["Partial camera tag (test)."])


def _probe_detection(mock_p: float, provenance: CameraProvenanceResult) -> dict:
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=mock_p):
            with patch(CLASSIFY_PHOTO, return_value=provenance):
                return detect_ai_generated(_jpeg_bytes(), file_name="club_event.jpg")


def _payload(ai_detection: dict) -> dict:
    return apply_integrity_evaluation_policy(
        {
            "criteria": [{"name": "Sharpness", "score": 4}],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "ai_detection": ai_detection,
        }
    )


@pytest.mark.parametrize("mock_p", [0.05, 0.10])
def test_strong_provenance_probe_low_no_review(mock_p: float) -> None:
    ai = _probe_detection(mock_p, _strong())
    assert ai["probability"] == round(mock_p, 3)
    assert ai["raw_detector_probability"] == round(mock_p, 3)
    assert ai["visual_risk_level"] == "low"
    assert ai["requires_review"] is False
    assert ai["provenance_policy_outcome"] == "low_ai_risk"
    payload = _payload(ai)
    assert payload["xp_eligible"] is True
    assert payload["xp_pending"] is False
    prob, label, _ = _ai_from_payload(ai)
    assert initial_review_status(label, prob, ai_detection=ai) == PROBE_LOW_RISK_REVIEW_STATUS


def test_partial_provenance_probe_low_photo_auto_clears() -> None:
    mock_p = 0.05
    ai = _probe_detection(mock_p, _partial())
    assert ai["requires_review"] is False
    assert ai["provenance_policy_outcome"] == "low_ai_risk"
    payload = _payload(ai)
    assert payload["xp_pending"] is False
    assert payload["show_quality_feedback"] is True
    prob, label, _ = _ai_from_payload(ai)
    assert initial_review_status(label, prob, ai_detection=ai) == PROBE_LOW_RISK_REVIEW_STATUS
    db = MagicMock()
    cfg = {"enable_ai_detection": True, "auto_generate_review_alerts": True}
    with patch("app.services.media_pipeline.settings_crud.settings_payload", return_value=cfg):
        with patch("app.services.media_pipeline.settings_crud.is_notification_enabled", return_value=True):
            assert _should_notify_admin_ai_flag(db, label, prob, ai_info=ai) is False


def test_absent_provenance_probe_low_source_unverified() -> None:
    mock_p = 0.05
    ai = _probe_detection(mock_p, _absent())
    assert ai["probability"] == round(mock_p, 3)
    assert ai["verdict"] == "authentic"
    assert ai["requires_review"] is True
    assert ai["provenance_policy_outcome"] == "source_unverified"
    assert "AI-generated" not in ai["detail"]
    payload = _payload(ai)
    assert payload["xp_pending"] is True
    assert payload["xp_eligible"] is False
    prob, label, _ = _ai_from_payload(ai)
    assert initial_review_status(label, prob, ai_detection=ai) == "needs_further_review"


@pytest.mark.parametrize("mock_p", [0.35, 0.40])
def test_absent_provenance_probe_suspicious(mock_p: float) -> None:
    ai = _probe_detection(mock_p, _absent())
    assert ai["probability"] == round(mock_p, 3)
    assert ai["requires_review"] is True
    assert ai["provenance_policy_outcome"] == "elevated_ai_risk"


@pytest.mark.parametrize("mock_p", [0.60, 0.80])
def test_absent_provenance_probe_high(mock_p: float) -> None:
    ai = _probe_detection(mock_p, _absent())
    assert ai["probability"] == round(mock_p, 3)
    assert ai["requires_review"] is True
    assert ai["provenance_policy_outcome"] == "high_ai_risk"


@pytest.mark.parametrize("mock_p", [0.35, 0.40])
def test_strong_provenance_probe_suspicious_still_review(mock_p: float) -> None:
    ai = _probe_detection(mock_p, _strong())
    assert ai["requires_review"] is True
    assert ai["provenance_policy_outcome"] == "elevated_ai_risk"


@pytest.mark.parametrize("mock_p", [0.60, 0.80])
def test_strong_provenance_probe_high_still_review(mock_p: float) -> None:
    ai = _probe_detection(mock_p, _strong())
    assert ai["requires_review"] is True
    assert ai["provenance_policy_outcome"] == "high_ai_risk"


def test_single_weak_exif_tag_not_strong() -> None:
    buf = io.BytesIO()
    img = Image.new("RGB", (32, 32))
    exif = img.getexif()
    exif[274] = 1
    img.save(buf, format="JPEG", exif=exif)
    result = classify_photo_camera_provenance(buf.getvalue(), "photo.jpg")
    assert result.strength != "strong"


def test_coherent_phone_exif_strong() -> None:
    buf = io.BytesIO()
    img = Image.new("RGB", (32, 32))
    exif = img.getexif()
    exif[271] = "Apple"
    exif[272] = "iPhone 14"
    exif[306] = "2026:03:01 12:00:00"
    img.save(buf, format="JPEG", exif=exif)
    result = classify_photo_camera_provenance(buf.getvalue(), "IMG_1234.jpg")
    assert result.strength == "strong"


def test_video_uses_container_provenance_not_frame_exif() -> None:
    frame = _jpeg_bytes()
    video_prov = _strong()
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=0.05):
            with patch(CLASSIFY_VIDEO, return_value=video_prov):
                with patch(CLASSIFY_PHOTO) as photo_classify:
                    out = detect_ai_generated_from_frames(
                        [frame],
                        file_name="clip.mp4",
                        video_content=b"fake-video-bytes",
                        video_ext=".mp4",
                    )
    photo_classify.assert_not_called()
    assert out["camera_provenance_strength"] == "strong"
    assert out["exif_metadata"]["is_video"] is True


def test_probe_probability_unchanged_by_policy_overlay() -> None:
    base = {
        "verdict": "authentic",
        "confidence": 0.95,
        "probability": 0.05,
        "raw_detector_probability": 0.05,
        "risk_level": "low",
        "requires_review": False,
        "detail": "Low AI authenticity risk from PROBE (5% P(fake)).",
        "detector_backend": "probe",
    }
    out = apply_probe_provenance_policy(base, _absent())
    assert out["probability"] == 0.05
    assert out["raw_detector_probability"] == 0.05


def test_admin_human_xp_once_still_guarded() -> None:
    from app.services import ai_review_workflow

    state = {
        "criteria_json": json.dumps(
            {"xp_pending": True, "xp_points_preview": 30, "xp_eligible": False}
        ),
    }
    ev = type("Ev", (), state)()
    calls = []

    def fake_get(_db, _mid):
        return ev

    def fake_add(_db, _uid, pts):
        calls.append(pts)

    with patch.object(ai_review_workflow.eval_crud, "get_for_media", fake_get):
        with patch.object(ai_review_workflow.ranking_crud, "add_points", fake_add):
            first = ai_review_workflow._award_pending_evaluation_xp(None, 1, 1)
            second = ai_review_workflow._award_pending_evaluation_xp(None, 1, 1)
    assert first == 30
    assert second == 0
    assert len(calls) == 1
