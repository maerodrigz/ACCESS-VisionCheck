"""Tests for official UnivFD dedicated AI detector."""

from __future__ import annotations

import io
from pathlib import Path
from unittest.mock import MagicMock, patch

from PIL import Image

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
    assert det.weights_path().name == "fc_weights.pth"
    assert det.clip_backbone_path().name == "ViT-L-14.pt"


def test_available_false_when_fc_weights_missing() -> None:
    with patch.object(det, "active_ai_detector_backend", return_value="univfd"):
        with patch.object(det, "_FC_WEIGHTS_PATH") as mock_fc:
            mock_fc.is_file.return_value = False
            assert det.dedicated_detector_available() is False


def test_available_false_when_clip_backbone_missing() -> None:
    with patch.object(det, "active_ai_detector_backend", return_value="univfd"):
        with patch.object(det, "_FC_WEIGHTS_PATH") as mock_fc:
            with patch.object(det, "_CLIP_BACKBONE_PATH") as mock_clip:
                mock_fc.is_file.return_value = True
                mock_fc.stat.return_value = MagicMock(st_size=100)
                mock_clip.is_file.return_value = False
                assert det.dedicated_detector_available() is False


def test_invalid_bytes_return_none() -> None:
    assert det.dedicated_ai_probability(b"") is None
    assert det.dedicated_ai_probability(b"not-an-image") is None


def test_fake_probability_from_logit_matches_univfd_sigmoid() -> None:
    import torch

    logit = torch.tensor([[2.0]])
    prob = det._fake_probability_from_logit(logit)
    assert prob is not None
    assert abs(prob - torch.sigmoid(torch.tensor(2.0)).item()) < 1e-6
    assert 0.0 <= prob <= 1.0


def test_preprocess_produces_224_tensor() -> None:
    import torch

    im = Image.new("RGB", (512, 384), color=(10, 20, 30))
    tensor = det._preprocess(im)
    assert isinstance(tensor, torch.Tensor)
    assert tuple(tensor.shape) == (1, 3, 224, 224)


def test_dedicated_ai_probability_with_mocked_model() -> None:
    import torch

    mock_model = MagicMock(return_value=torch.tensor([[1.5]]))
    with patch.object(det, "active_ai_detector_backend", return_value="univfd"):
        with patch.object(det, "_univfd_detector_available", return_value=True):
            with patch.object(det, "_get_model", return_value=mock_model):
                prob = det.dedicated_ai_probability(_jpeg_bytes())
    assert prob is not None
    assert 0.0 <= prob <= 1.0
    mock_model.assert_called_once()


def test_detect_ai_generated_response_structure_without_neural() -> None:
    with patch("app.services.ai_authenticity_detector.dedicated_ai_probability", return_value=None):
        result = detect_ai_generated(_jpeg_bytes(), file_name="sample.jpg")
    assert isinstance(result, dict)
    for key in ("verdict", "confidence", "probability", "detail", "signals", "exif_metadata"):
        assert key in result
    assert result["verdict"] in ("authentic", "suspicious", "ai_generated")


def test_detect_ai_generated_uses_neural_signal_when_mocked() -> None:
    with patch("app.services.ai_authenticity_detector.dedicated_ai_probability", return_value=0.72):
        result = detect_ai_generated(_jpeg_bytes(), file_name="sample.jpg")
    assert "neural" in result["signals"]
    assert result["signals"]["neural"] > 0


def test_ml_univfd_readme_documents_paths() -> None:
    readme = Path(__file__).resolve().parents[1] / "ml" / "univfd" / "README.txt"
    assert readme.is_file()
    text = readme.read_text(encoding="utf-8")
    assert "fc_weights.pth" in text
    assert "ViT-L-14.pt" in text
