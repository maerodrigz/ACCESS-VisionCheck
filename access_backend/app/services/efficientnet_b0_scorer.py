"""EfficientNet-B0 multi-criterion technical quality scorer (PyTorch)."""

from __future__ import annotations

import threading
from io import BytesIO
from pathlib import Path
from typing import Any

import numpy as np

try:
    import torch
    import torch.nn as nn
    from PIL import Image
    from torchvision.models import EfficientNet_B0_Weights, efficientnet_b0
    from torchvision.transforms import functional as TF
except ImportError:  # pragma: no cover
    torch = None  # type: ignore
    nn = None  # type: ignore
    Image = None  # type: ignore

MODEL_ID = "efficientnet-b0"
MODEL_VERSION = "1.0"
CRITERION_KEYS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)

_WEIGHTS_PATH = Path(__file__).resolve().parents[2] / "ml" / "efficientnet_b0_heads.pt"
_model_lock = threading.Lock()
_model: Any = None


class EfficientNetB0IQA(nn.Module):  # type: ignore[misc]
    """ImageNet EfficientNet-B0 backbone + regression head for 7 IQA signals."""

    def __init__(self) -> None:
        super().__init__()
        base = efficientnet_b0(weights=EfficientNet_B0_Weights.IMAGENET1K_V1)
        self.features = base.features
        self.avgpool = base.avgpool
        self.dropout = nn.Dropout(p=0.15)
        self.head = nn.Linear(1280, len(CRITERION_KEYS))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.features(x)
        x = self.avgpool(x)
        x = torch.flatten(x, 1)
        x = self.dropout(x)
        return torch.sigmoid(self.head(x))


def efficientnet_available() -> bool:
    return torch is not None and nn is not None and Image is not None


def weights_path() -> Path:
    return _WEIGHTS_PATH


def analyze_image_bytes(content: bytes) -> dict[str, Any] | None:
    """Run EfficientNet-B0 inference; returns metric dict compatible with media_evaluator."""
    if not efficientnet_available() or not content:
        return None

    model = _get_model()
    if model is None:
        return None

    try:
        image = Image.open(BytesIO(content)).convert("RGB")
    except Exception:
        return None

    w, h = image.size
    if w < 8 or h < 8:
        return None

    tensor = _preprocess(image)
    with torch.no_grad():
        outputs = model(tensor).squeeze(0).cpu().numpy()

    metrics = {key: float(np.clip(outputs[i], 0.0, 1.0)) for i, key in enumerate(CRITERION_KEYS)}
    metrics["width"] = int(w)
    metrics["height"] = int(h)
    return metrics


def _preprocess(image: Image.Image) -> torch.Tensor:
    resized = TF.resize(image, [224, 224], antialias=True)
    tensor = TF.to_tensor(resized)
    tensor = TF.normalize(
        tensor,
        mean=(0.485, 0.456, 0.406),
        std=(0.229, 0.224, 0.225),
    )
    return tensor.unsqueeze(0)


def _get_model() -> EfficientNetB0IQA | None:
    global _model
    if _model is not None:
        return _model

    with _model_lock:
        if _model is not None:
            return _model
        if not _WEIGHTS_PATH.exists():
            return None
        try:
            model = EfficientNetB0IQA()
            try:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu", weights_only=True)
            except TypeError:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu")
            model.load_state_dict(state, strict=False)
            model.eval()
            _model = model
            return _model
        except Exception:
            return None


def ensure_weights() -> bool:
    """Load model weights; returns True when ready for inference."""
    return _get_model() is not None
