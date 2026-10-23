"""PROBE integration step 1: routing, resize helper, no full inference."""

from __future__ import annotations

import io
from unittest.mock import MagicMock, patch

from PIL import Image

from app.config import settings
from app.services import dedicated_ai_detector as det
from app.services import probe_dino_detector as probe_det


def test_default_backend_is_probe() -> None:
    """Isolated stack and app default use PROBE (see app/config.py)."""
    assert settings.ai_detector_backend == "probe"
    assert det.active_ai_detector_backend() == "probe"


def test_probe_backend_routes_to_probe_service() -> None:
    with patch.object(settings, "ai_detector_backend", "probe"):
        with patch("app.services.probe_dino_detector.probe_ai_probability", return_value=0.42) as mock_probe:
            with patch.object(det, "_univfd_ai_probability") as mock_univfd:
                prob = det.dedicated_ai_probability(b"x" * 64)
    assert prob == 0.42
    mock_probe.assert_called_once()
    mock_univfd.assert_not_called()


def test_univfd_backend_uses_univfd_path() -> None:
    with patch.object(settings, "ai_detector_backend", "univfd"):
        with patch.object(det, "_univfd_ai_probability", return_value=0.11) as mock_univfd:
            with patch("app.services.probe_dino_detector.probe_ai_probability") as mock_probe:
                prob = det.dedicated_ai_probability(b"x" * 64)
    assert prob == 0.11
    mock_univfd.assert_called_once()
    mock_probe.assert_not_called()


def test_resize_long_edge_4608x3456() -> None:
    im = Image.new("RGB", (4608, 3456), color=(1, 2, 3))
    out = probe_det.resize_long_edge(im, 1344)
    assert max(out.size) == 1344
    assert out.size == (1344, 1008)


def test_resize_long_edge_1264_unchanged() -> None:
    im = Image.new("RGB", (1264, 1264), color=(1, 2, 3))
    out = probe_det.resize_long_edge(im, 1344)
    assert out.size == (1264, 1264)


def test_resize_long_edge_1024x559_unchanged() -> None:
    im = Image.new("RGB", (1024, 559), color=(1, 2, 3))
    out = probe_det.resize_long_edge(im, 1344)
    assert out.size == (1024, 559)


def test_probe_probability_contract_mocked() -> None:
    with patch.object(probe_det, "probe_detector_available", return_value=True):
        with patch.object(probe_det, "_get_model", return_value=MagicMock()):
            with patch.object(probe_det, "_get_probe_inference") as mock_imp:
                mock_imp.return_value = (MagicMock(), MagicMock(return_value=(0.0, 0.75, 9, (100, 100))))
                prob = probe_det.probe_ai_probability(_jpeg_bytes())
    assert prob == 0.75


def test_probe_probability_none_when_unavailable() -> None:
    with patch.object(probe_det, "probe_detector_available", return_value=False):
        assert probe_det.probe_ai_probability(_jpeg_bytes()) is None


def test_efficientnet_import_unchanged() -> None:
    from app.services import efficientnet_b0_scorer as eff

    assert eff.MODEL_ID == "efficientnet-b0"
    assert callable(eff.analyze_image_bytes)


def _jpeg_bytes(width: int = 64, height: int = 64) -> bytes:
    im = Image.new("RGB", (width, height), color=(10, 20, 30))
    buf = io.BytesIO()
    im.save(buf, format="JPEG")
    return buf.getvalue()
