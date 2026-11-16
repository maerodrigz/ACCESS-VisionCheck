"""Tests for photo AI detector router (PROBE only; UnivFD retired)."""

from __future__ import annotations

import io
from unittest.mock import patch

import pytest
from PIL import Image
from pydantic import ValidationError

from app.config import Settings
from app.services import dedicated_ai_detector as det
from app.services.ai_authenticity_detector import detect_ai_generated


def _jpeg_bytes(width: int = 256, height: int = 256) -> bytes:
    im = Image.new("RGB", (width, height), color=(120, 80, 200))
    buf = io.BytesIO()
    im.save(buf, format="JPEG")
    return buf.getvalue()


def test_module_imports() -> None:
    assert callable(det.dedicated_detector_available)
    assert callable(det.dedicated_ai_probability)
    assert det.active_ai_detector_backend() == "probe"


def test_univfd_backend_rejected_at_settings() -> None:
    with pytest.raises(ValidationError, match="univfd"):
        Settings(AI_DETECTOR_BACKEND="univfd")


def test_invalid_bytes_return_none() -> None:
    with patch("app.services.probe_dino_detector.probe_ai_probability", return_value=None):
        assert det.dedicated_ai_probability(b"") is None
        assert det.dedicated_ai_probability(b"not-an-image") is None


def test_dedicated_ai_probability_routes_to_probe() -> None:
    with patch("app.services.probe_dino_detector.probe_ai_probability", return_value=0.33) as mock_probe:
        prob = det.dedicated_ai_probability(_jpeg_bytes())
    assert prob == 0.33
    mock_probe.assert_called_once()


def test_detect_ai_generated_response_structure_without_neural() -> None:
    with patch("app.services.ai_authenticity_detector.dedicated_ai_probability", return_value=None):
        result = detect_ai_generated(_jpeg_bytes(), file_name="sample.jpg")
    assert isinstance(result, dict)
    for key in ("verdict", "confidence", "probability", "detail", "signals", "exif_metadata"):
        assert key in result
    assert result["verdict"] in ("authentic", "suspicious", "ai_generated")
    assert result.get("detector_backend") == "probe"


def test_detect_ai_generated_probe_path_uses_raw_probability() -> None:
    with patch("app.services.ai_authenticity_detector.active_ai_detector_backend", return_value="probe"):
        with patch("app.services.ai_authenticity_detector.dedicated_ai_probability", return_value=0.72):
            result = detect_ai_generated(_jpeg_bytes(), file_name="sample.jpg")
    assert result.get("detector_backend") == "probe"
    assert result.get("raw_detector_probability") == 0.72
    assert "probe" in result.get("signals", {})
