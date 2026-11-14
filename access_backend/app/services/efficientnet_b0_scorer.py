"""EfficientNet-B0 multi-criterion technical quality scorer (PyTorch).

FROZEN (2026-11-09): Do not retrain, fine-tune, recalibrate, or replace weights.
Active presentation uses five heads (sharpness, blur, brightness, contrast,
blocking_artifacts). Noise/ringing heads remain in the checkpoint for continuity
but are not shown in the active seven-criterion rubric. Scores are experimental
estimates only; see tools/quality_validation/EFFICIENTNET_B0_FROZEN_STATUS.md.
"""

from __future__ import annotations

import logging
import threading
from pathlib import Path
from typing import Any

import numpy as np

from app.services.torch_runtime import get_torch, torch_available

logger = logging.getLogger("ACCESS.efficientnet_b0")

MODEL_ID = "efficientnet-b0"
MODEL_VERSION = "1.0"
# Freeze gate: set False only with explicit product approval to resume ENET work.
ENET_DEVELOPMENT_FROZEN = True
ESTIMATE_KIND = "experimental_estimate"
CRITERION_KEYS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)
# Heads used for active photo quality presentation (Noise/Ringing not presented).
ACTIVE_PRESENTATION_KEYS = (
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
)

_WEIGHTS_PATH = Path(__file__).resolve().parents[2] / "ml" / "efficientnet_b0_heads.pt"
_model_lock = threading.Lock()
_model: Any = None
_last_load_error: str | None = None


def efficientnet_available() -> bool:
    if not torch_available():
        return False
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        return False
    return True


def weights_path() -> Path:
    return _WEIGHTS_PATH


def last_load_error() -> str | None:
    """Last EfficientNet load failure reason (None if never failed or cleared on success)."""
    return _last_load_error


def runtime_status() -> dict[str, Any]:
    """Diagnostic snapshot for rollback / Phase 7G (does not change scoring)."""
    from app.services.torch_runtime import torch_import_error

    pil_ok = False
    pil_err: str | None = None
    try:
        from PIL import Image  # noqa: F401

        pil_ok = True
    except Exception as exc:  # noqa: BLE001
        pil_err = f"{type(exc).__name__}: {exc}"
    return {
        "torch_available": torch_available(),
        "torch_import_error": torch_import_error(),
        "pil_available": pil_ok,
        "pil_error": pil_err,
        "efficientnet_available": efficientnet_available(),
        "weights_path": str(_WEIGHTS_PATH),
        "weights_exists": _WEIGHTS_PATH.is_file(),
        "model_loaded": _model is not None,
        "last_load_error": _last_load_error,
        "ensure_weights": None,  # filled by callers after ensure_weights()
    }


def analyze_image_bytes(content: bytes) -> dict[str, Any] | None:
    """Run EfficientNet-B0 inference; returns metric dict compatible with media_evaluator."""
    if not efficientnet_available() or not content:
        return None

    model = _get_model()
    if model is None:
        return None

    torch = get_torch()
    if torch is None:
        return None

    try:
        from app.services.image_orientation import oriented_pil_image

        image = oriented_pil_image(content)
        if image is None:
            return None
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


def _preprocess(image: Any) -> Any:
    from torchvision.transforms import functional as TF

    resized = TF.resize(image, [224, 224], antialias=True)
    tensor = TF.to_tensor(resized)
    tensor = TF.normalize(
        tensor,
        mean=(0.485, 0.456, 0.406),
        std=(0.229, 0.224, 0.225),
    )
    return tensor.unsqueeze(0)


def _build_iqa_model() -> Any | None:
    torch = get_torch()
    if torch is None:
        return None
    import torch.nn as nn
    from torchvision.models import EfficientNet_B0_Weights, efficientnet_b0

    class EfficientNetB0IQA(nn.Module):
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

    return EfficientNetB0IQA()


def _get_model() -> Any | None:
    global _model, _last_load_error
    if _model is not None:
        return _model

    with _model_lock:
        if _model is not None:
            return _model
        if not _WEIGHTS_PATH.exists():
            _last_load_error = f"weights_missing:{_WEIGHTS_PATH}"
            logger.warning("EfficientNet-B0 weights missing: %s", _WEIGHTS_PATH)
            return None
        torch = get_torch()
        if torch is None:
            from app.services.torch_runtime import torch_import_error

            _last_load_error = f"torch_unavailable:{torch_import_error()}"
            logger.warning("EfficientNet-B0 skipped: %s", _last_load_error)
            return None
        try:
            model = _build_iqa_model()
            if model is None:
                _last_load_error = "build_iqa_model_returned_none"
                logger.warning("EfficientNet-B0 build returned None")
                return None
            try:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu", weights_only=True)
            except TypeError:
                state = torch.load(_WEIGHTS_PATH, map_location="cpu")
            model.load_state_dict(state, strict=False)
            model.eval()
            _model = model
            _last_load_error = None
            return _model
        except Exception as exc:  # noqa: BLE001
            _last_load_error = f"{type(exc).__name__}: {exc}"
            logger.warning("EfficientNet-B0 load failed: %s", _last_load_error)
            return None


def ensure_weights() -> bool:
    """Load model weights; returns True when ready for inference.

    Prefer calling once on the main thread (API lifespan / process startup) before
    ``asyncio.to_thread`` evaluation so Torch/vision init is not first hit in a
    worker thread (Phase 7B/7G rollback false OpenCV preference).
    """
    return _get_model() is not None


def warm_main_thread() -> dict[str, Any]:
    """Eager init on the calling thread; returns runtime_status including ensure_weights."""
    status = runtime_status()
    status["ensure_weights"] = bool(ensure_weights())
    status["last_load_error"] = _last_load_error
    status["model_loaded"] = _model is not None
    return status
