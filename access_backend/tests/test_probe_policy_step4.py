"""Integration Step 4: PROBE-specific authenticity risk policy (mocked inference only)."""

from __future__ import annotations

import io
from unittest.mock import patch

import pytest
from PIL import Image

from app.services.ai_authenticity_detector import (
    detect_ai_generated,
    probe_risk_level_from_probability,
)
from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy


def _jpeg_bytes(width: int = 64, height: int = 64) -> bytes:
    im = Image.new("RGB", (width, height), color=(90, 120, 60))
    buf = io.BytesIO()
    im.save(buf, format="JPEG")
    return buf.getvalue()


PROBE_BACKEND = "app.services.ai_authenticity_detector.active_ai_detector_backend"
PROBE_PROB = "app.services.ai_authenticity_detector.dedicated_ai_probability"
FUSE = "app.services.ai_authenticity_detector._fuse_probability"


@pytest.mark.parametrize(
    "p,expected",
    [
        (0.10, "low"),
        (0.2999, "low"),
        (0.30, "suspicious"),
        (0.40, "suspicious"),
        (0.4499, "suspicious"),
        (0.45, "high"),
        (0.80, "high"),
    ],
)
def test_probe_risk_level_thresholds(p: float, expected: str) -> None:
    assert probe_risk_level_from_probability(p) == expected


@pytest.mark.parametrize(
    "mock_p,expected_verdict,expected_risk,requires_review",
    [
        (0.10, "authentic", "low", False),
        (0.2999, "authentic", "low", False),
        (0.30, "suspicious", "suspicious", True),
        (0.40, "suspicious", "suspicious", True),
        (0.4499, "suspicious", "suspicious", True),
        (0.45, "ai_generated", "high", True),
        (0.80, "ai_generated", "high", True),
    ],
)
def test_probe_detect_bypasses_fusion(
    mock_p: float,
    expected_verdict: str,
    expected_risk: str,
    requires_review: bool,
) -> None:
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=mock_p):
            with patch(FUSE) as fuse_mock:
                result = detect_ai_generated(_jpeg_bytes(), file_name="photo.jpg")

    fuse_mock.assert_not_called()
    assert result["detector_backend"] == "probe"
    assert result["risk_level"] == expected_risk
    assert result["verdict"] == expected_verdict
    assert result["requires_review"] is requires_review
    assert result["probability"] == round(mock_p, 3)
    assert result["raw_detector_probability"] == round(mock_p, 3)
    assert "neural" not in result["signals"]
    assert "neural_authentic" not in result["signals"]
    assert result["signals"]["probe"] == round(mock_p, 3)


def test_probe_unavailable_does_not_clear_as_low_risk() -> None:
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=None):
            result = detect_ai_generated(_jpeg_bytes(), file_name="photo.jpg")

    assert result["detector_backend"] == "probe"
    assert result["requires_review"] is True
    assert result["risk_level"] == "suspicious"
    assert result["verdict"] == "suspicious"
    assert result["raw_detector_probability"] is None
    assert "could not run" in result["detail"].lower()


def test_probe_low_not_neural_authentic_suppression() -> None:
    """High supporting heuristic scores must not reduce raw PROBE probability."""
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=0.12):
            with patch(
                "app.services.ai_authenticity_detector._collect_forensic_support",
                return_value=({"filename": 0.9, "metadata": 0.85, "frequency": 0.7}, ["hint"]),
            ):
                result = detect_ai_generated(_jpeg_bytes(), file_name="midjourney_v6.png")

    assert result["probability"] == 0.12
    assert result["risk_level"] == "low"
    assert "support_filename" in result["signals"]


def test_probe_integrity_flow() -> None:
    base = {
        "criteria": [],
        "overall_score": 4.0,
        "legacy": {"overall_score": 0.8},
        "ai_feedback": "Quality feedback.",
    }

    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=0.15):
            low = detect_ai_generated(_jpeg_bytes())
        with patch(PROBE_PROB, return_value=0.35):
            susp = detect_ai_generated(_jpeg_bytes())
        with patch(PROBE_PROB, return_value=0.70):
            high = detect_ai_generated(_jpeg_bytes())

    low_out = apply_integrity_evaluation_policy({**base, "ai_detection": low})
    susp_out = apply_integrity_evaluation_policy({**base, "ai_detection": susp})
    high_out = apply_integrity_evaluation_policy({**base, "ai_detection": high})

    assert low_out["xp_eligible"] is True
    assert low_out["xp_pending"] is False
    assert susp_out["xp_eligible"] is False
    assert susp_out["xp_pending"] is True
    assert high_out["xp_eligible"] is False
    assert high_out["xp_pending"] is True


def test_univfd_still_fuses_when_backend_univfd() -> None:
    with patch(PROBE_BACKEND, return_value="univfd"):
        with patch(PROBE_PROB, return_value=0.72):
            with patch(FUSE, return_value=0.65) as fuse_mock:
                result = detect_ai_generated(_jpeg_bytes(), file_name="sample.jpg")

    fuse_mock.assert_called_once()
    assert "neural" in result["signals"]
    assert result.get("detector_backend") != "probe"
