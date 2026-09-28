"""EfficientNet-B0 binary head for AI vs authentic image classification."""

from __future__ import annotations

import threading
from io import BytesIO
from pathlib import Path
from typing import Any

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

_WEIGHTS_PATH = Path(__file__).resolve().parents[2] / "ml" / "ai_authenticity_head.pt"
_model_lock = threading.Lock()
_model: Any = None


class AiAuthenticityNet(nn.Module):  # type: ignore[misc]
    def __init__(self) -> None:
        super().__init__()
        base = efficientnet_b0(weights=EfficientNet_B0_Weights.IMAGENET1K_V1)
        self.features = base.features
        self.avgpool = base.avgpool
        self.dropout = nn.Dropout(p=0.2)
        self.head = nn.Linear(1280, 1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.features(x)
        x = self.avgpool(x)
        x = torch.flatten(x, 1)
        x = self.dropout(x)
        return torch.sigmoid(self.head(x))


def ai_model_available() -> bool:
    return torch is not None and nn is not None and Image is not None and _WEIGHTS_PATH.exists()


def ai_model_probability(content: bytes) -> float | None:
    if not ai_model_available() or not content:
        return None

    model = _get_model()
    if model is None:
        return None

    try:
        image = Image.open(BytesIO(content)).convert("RGB")
    except Exception:
        return None

    tensor = _preprocess(image)
    with torch.no_grad():
        prob = float(model(tensor).squeeze().item())
    return max(0.0, min(1.0, prob))


def _preprocess(image: Image.Image) -> torch.Tensor:
    resized = TF.resize(image, [224, 224], antialias=True)
    tensor = TF.to_tensor(resized)
    tensor = TF.normalize(tensor, mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225))
    return tensor.unsqueeze(0)


def _get_model() -> AiAuthenticityNet | None:
    global _model
    if _model is not None:
        return _model

    with _model_lock:
        if _model is not None:
            return _model
        if not _WEIGHTS_PATH.exists():
            return None
        try:
            model = AiAuthenticityNet()
            try:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu", weights_only=True)
            except TypeError:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu")
            model.load_state_dict(state, strict=True)
            model.eval()
            _model = model
            return _model
        except Exception:
            return None
