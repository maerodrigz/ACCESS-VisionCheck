"""Official UniversalFakeDetect (UnivFD) CLIP:ViT-L/14 AI-image detector.

Architecture (from WisconsinAIVision/UniversalFakeDetect):
  CLIP ViT-L/14 backbone  +  Linear(768 -> 1) classifier (fc_weights.pth)

Required local files (no auto-download):
  access_backend/ml/univfd/fc_weights.pth      — official UnivFD classifier head
  access_backend/ml/univfd/ViT-L-14.pt         — OpenAI CLIP ViT-L/14 backbone

Preprocessing (matches validate.py RealFakeDataset for CLIP arch):
  RGB -> CenterCrop(224) -> ToTensor -> CLIP Normalize

Output (matches validate.py validate()):
  logit = model(image)
  P(fake / AI-generated) = sigmoid(logit)
  label 0 = real, label 1 = fake in official evaluation code
"""

from __future__ import annotations

import logging
import threading
from io import BytesIO
from pathlib import Path
from typing import Any

import numpy as np

from app.services.torch_runtime import get_torch, torch_available

logger = logging.getLogger("ACCESS.dedicated_ai_detector")


def _active_detector_backend() -> str:
    from app.config import settings

    backend = (settings.ai_detector_backend or "univfd").strip().lower()
    if backend not in ("univfd", "probe"):
        logger.warning("dedicated_ai_detector: unknown AI_DETECTOR_BACKEND=%r; using univfd", backend)
        return "univfd"
    return backend


def active_ai_detector_backend() -> str:
    """Public read-only backend id: univfd | probe."""
    return _active_detector_backend()


_ML_DIR = Path(__file__).resolve().parents[2] / "ml" / "univfd"
_FC_WEIGHTS_PATH = _ML_DIR / "fc_weights.pth"
_CLIP_BACKBONE_PATH = _ML_DIR / "ViT-L-14.pt"

# validate.py MEAN/STD["clip"] for CLIP:ViT-L/14 evaluation transforms
_CLIP_MEAN = (0.48145466, 0.4578275, 0.40821073)
_CLIP_STD = (0.26862954, 0.26130258, 0.27577711)
_INPUT_SIZE = 224

_model_lock = threading.Lock()
_model: Any = None


def weights_path() -> Path:
    """Official UnivFD classifier checkpoint path."""
    return _FC_WEIGHTS_PATH


def clip_backbone_path() -> Path:
    """OpenAI CLIP ViT-L/14 backbone path (required alongside fc_weights.pth)."""
    return _CLIP_BACKBONE_PATH


def _univfd_weights_on_disk() -> bool:
    return (
        _FC_WEIGHTS_PATH.is_file()
        and _FC_WEIGHTS_PATH.stat().st_size > 0
        and _CLIP_BACKBONE_PATH.is_file()
        and _CLIP_BACKBONE_PATH.stat().st_size > 0
    )


def _univfd_detector_available() -> bool:
    if not torch_available():
        return False
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        return False
    return _univfd_weights_on_disk()


def dedicated_detector_available() -> bool:
    """True when the configured backend can run inference."""
    if _active_detector_backend() == "probe":
        from app.services.probe_dino_detector import probe_detector_available

        return probe_detector_available()
    return _univfd_detector_available()


def dedicated_ai_probability(content: bytes) -> float | None:
    """Return P(AI-generated / fake) in [0, 1], or None if unavailable / invalid."""
    if _active_detector_backend() == "probe":
        from app.services.probe_dino_detector import probe_ai_probability

        return probe_ai_probability(content)
    return _univfd_ai_probability(content)


def _univfd_ai_probability(content: bytes) -> float | None:
    if not content or len(content) < 32:
        return None
    if not _univfd_detector_available():
        return None

    model = _get_model()
    if model is None:
        return None

    try:
        from PIL import Image

        image = Image.open(BytesIO(content)).convert("RGB")
    except Exception:
        logger.debug("dedicated_ai_probability: could not decode image bytes", exc_info=True)
        return None

    if image.size[0] < 8 or image.size[1] < 8:
        return None

    torch = get_torch()
    if torch is None:
        return None

    try:
        tensor = _preprocess(image)
        with torch.no_grad():
            logit = model(tensor)
        prob = _fake_probability_from_logit(logit, torch)
    except Exception:
        logger.warning("dedicated_ai_probability: UnivFD inference failed", exc_info=True)
        return None

    if prob is None or not np.isfinite(prob):
        return None
    return float(max(0.0, min(1.0, prob)))


def _preprocess(image: Any) -> Any:
    """Official UnivFD validate.py transform for CLIP arch (not clip.load preprocess)."""
    from torchvision.transforms import CenterCrop, Compose, Normalize, ToTensor

    transform = Compose(
        [
            CenterCrop(_INPUT_SIZE),
            ToTensor(),
            Normalize(mean=_CLIP_MEAN, std=_CLIP_STD),
        ]
    )
    return transform(image).unsqueeze(0)


def _fake_probability_from_logit(raw: Any, torch: Any) -> float | None:
    """UnivFD validate.py: model(in_tens).sigmoid() — fake label is 1."""
    if raw is None or not isinstance(raw, torch.Tensor):
        return None
    t = raw.detach().float().cpu().reshape(-1)
    if t.numel() == 0:
        return None
    return float(torch.sigmoid(t[0]).item())


def _get_model() -> Any | None:
    global _model
    if _model is not None:
        return _model

    with _model_lock:
        if _model is not None:
            return _model
        if not _univfd_detector_available():
            return None
        torch = get_torch()
        if torch is None:
            return None
        try:
            from app.services.univfd.clip_model import CLIPModel

            model = CLIPModel(clip_backbone_path=str(_CLIP_BACKBONE_PATH))
            try:
                fc_state = torch.load(_FC_WEIGHTS_PATH, map_location="cpu", weights_only=True)
            except TypeError:
                fc_state = torch.load(_FC_WEIGHTS_PATH, map_location="cpu")
            model.fc.load_state_dict(fc_state)
            model.eval()
            _model = model
            logger.info(
                "dedicated_ai_detector: loaded UnivFD CLIP:ViT-L/14 from %s + %s",
                _FC_WEIGHTS_PATH.name,
                _CLIP_BACKBONE_PATH.name,
            )
            return _model
        except Exception:
            logger.warning("dedicated_ai_detector: failed to load UnivFD model", exc_info=True)
            return None
