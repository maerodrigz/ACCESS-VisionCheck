"""Integration Step 5: PROBE policy propagation through pipeline (mocked, no inference)."""

from __future__ import annotations

import io
import json
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from app.services.ai_authenticity_detector import detect_ai_generated
from app.services.camera_provenance import CameraProvenanceResult
from app.services.ai_review_workflow import PROBE_LOW_RISK_REVIEW_STATUS, initial_review_status
from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy, xp_award_points_from_payload
from app.services.media_pipeline import _ai_from_payload, _should_notify_admin_ai_flag

PROBE_BACKEND = "app.services.ai_authenticity_detector.active_ai_detector_backend"
PROBE_PROB = "app.services.ai_authenticity_detector.dedicated_ai_probability"


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (48, 48), color=(40, 80, 120)).save(buf, format="JPEG")
    return buf.getvalue()


def _base_payload(ai_detection: dict) -> dict:
    return apply_integrity_evaluation_policy(
        {
            "criteria": [{"name": "Sharpness", "score": 4}],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "ai_feedback": "Quality coaching text.",
            "ai_detection": ai_detection,
        }
    )


def _probe_detection(mock_p: float) -> dict:
    strong = CameraProvenanceResult("strong", reasons=["Test fixture: strong provenance."])
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=mock_p):
            with patch(
                "app.services.camera_provenance.classify_photo_camera_provenance",
                return_value=strong,
            ):
                return detect_ai_generated(_jpeg_bytes(), file_name="club_event.jpg")


def _admin_alert(ai_detection: dict, ai_label: str, ai_prob: float) -> bool:
    db = MagicMock()
    cfg = {"enable_ai_detection": True, "auto_generate_review_alerts": True}
    with patch("app.services.media_pipeline.settings_crud.settings_payload", return_value=cfg):
        with patch("app.services.media_pipeline.settings_crud.is_notification_enabled", return_value=True):
            return _should_notify_admin_ai_flag(db, ai_label, ai_prob, ai_info=ai_detection)


def _e2e(mock_p: float) -> dict:
    ai_detection = _probe_detection(mock_p)
    ai_prob, ai_label, _remarks = _ai_from_payload(ai_detection)
    review_status = initial_review_status(ai_label, ai_prob, ai_detection=ai_detection)
    payload = _base_payload(ai_detection)
    return {
        "ai_detection": ai_detection,
        "ai_prob": ai_prob,
        "ai_label": ai_label,
        "review_status": review_status,
        "xp_eligible": payload["xp_eligible"],
        "xp_pending": payload["xp_pending"],
        "xp_points": xp_award_points_from_payload(payload),
        "admin_alert": _admin_alert(ai_detection, ai_label, ai_prob),
    }


@pytest.mark.parametrize("mock_p", [0.10, 0.2999])
def test_probe_low_e2e(mock_p: float) -> None:
    out = _e2e(mock_p)
    assert out["ai_detection"]["risk_level"] == "low"
    assert out["ai_detection"]["requires_review"] is False
    assert out["review_status"] == PROBE_LOW_RISK_REVIEW_STATUS
    assert out["review_status"] != "verified_human"
    assert out["ai_prob"] == round(mock_p, 3)
    assert out["xp_eligible"] is True
    assert out["xp_pending"] is False
    assert out["xp_points"] > 0
    assert out["admin_alert"] is False
    assert "not proof" in out["ai_detection"]["detail"].lower() or "not proof" in _ai_from_payload(out["ai_detection"])[2].lower()


@pytest.mark.parametrize("mock_p", [0.30, 0.40, 0.4499])
def test_probe_suspicious_e2e(mock_p: float) -> None:
    out = _e2e(mock_p)
    assert out["ai_detection"]["risk_level"] == "suspicious"
    assert out["ai_detection"]["requires_review"] is True
    assert out["review_status"] == "needs_further_review"
    assert out["ai_label"] == "suspicious"
    assert out["ai_prob"] == round(mock_p, 3)
    assert out["xp_eligible"] is False
    assert out["xp_pending"] is True
    assert out["xp_points"] == 0
    assert out["admin_alert"] is True


@pytest.mark.parametrize("mock_p", [0.45, 0.80])
def test_probe_high_e2e(mock_p: float) -> None:
    out = _e2e(mock_p)
    assert out["ai_detection"]["risk_level"] == "high"
    assert out["ai_detection"]["requires_review"] is True
    assert out["review_status"] == "pending_review"
    assert out["ai_label"] == "ai_generated"
    assert out["ai_prob"] == round(mock_p, 3)
    assert out["xp_eligible"] is False
    assert out["xp_pending"] is True
    assert out["xp_points"] == 0
    assert out["admin_alert"] is True


def test_probe_fields_survive_evaluation_json_blob() -> None:
    ai_detection = _probe_detection(0.35)
    payload = _base_payload(ai_detection)
    blob = json.loads(json.dumps(payload))
    ai = blob["ai_detection"]
    for key in (
        "detector_backend",
        "risk_level",
        "raw_detector_probability",
        "requires_review",
        "probability",
    ):
        assert key in ai
    assert ai["detector_backend"] == "probe"
    assert ai["raw_detector_probability"] == 0.35


def test_univfd_review_and_notify_unchanged() -> None:
    prob, label, _ = _ai_from_payload(
        {"verdict": "authentic", "confidence": 0.72, "probability": 0.28}
    )
    assert initial_review_status(label, prob) == "verified_human"

    prob2, label2, _ = _ai_from_payload(
        {"verdict": "ai_generated", "confidence": 0.82, "probability": 0.82}
    )
    assert round(prob2, 3) == 0.82
    db = MagicMock()
    cfg = {"enable_ai_detection": True, "auto_generate_review_alerts": True, "ai_confidence_threshold": 0.75}
    with patch("app.services.media_pipeline.settings_crud.settings_payload", return_value=cfg):
        with patch("app.services.media_pipeline.settings_crud.is_notification_enabled", return_value=True):
            assert _should_notify_admin_ai_flag(db, label2, prob2, ai_info={"detector_backend": "univfd"}) is True
            assert _should_notify_admin_ai_flag(db, label, prob, ai_info={"detector_backend": "univfd"}) is False

    prob_border, label_border, _ = _ai_from_payload(
        {"verdict": "authentic", "confidence": 0.60, "probability": 0.40}
    )
    assert initial_review_status(label_border, prob_border) == "needs_further_review"
