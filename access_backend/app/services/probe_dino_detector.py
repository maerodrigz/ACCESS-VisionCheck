"""PROBE-DINOv2 AI detector (Step 8C.2 validated: max long edge 1344px before official tiling)."""

from __future__ import annotations

import hashlib
import logging
import sys
import threading
from io import BytesIO
from pathlib import Path
from typing import Any, Callable

import numpy as np

from app.services.torch_runtime import get_torch, torch_available

logger = logging.getLogger("ACCESS.probe_dino_detector")

BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROBE_ROOT = BACKEND_ROOT / "experiments" / "probe"
DEFAULT_CHECKPOINT = (
    PROBE_ROOT
    / "modelscope_cache"
    / "models"
    / "shuinishaojiu--PROBE-AIGI-Detection"
    / "snapshots"
    / "master"
    / "DINOv2_best_model_step_34999.pth"
)
HF_CACHE = PROBE_ROOT / "hf_cache"
EXPECTED_CHECKPOINT_SHA256 = "c8caa9bad54c029e4d22e1909c4673e46a239d8419a986e0ab461d423a450156"
DEFAULT_MAX_LONG_EDGE = 1344
PATCH_BATCH_SIZE = 8

_model_lock = threading.Lock()
_model: Any = None
_probe_imports: tuple[Callable[..., Any], Callable[..., Any]] | None = None


def checkpoint_path() -> Path:
    from app.config import settings

    override = (getattr(settings, "probe_checkpoint_path", None) or "").strip()
    if override:
        return Path(override)
    return DEFAULT_CHECKPOINT


def max_long_edge() -> int:
    from app.config import settings

    value = int(getattr(settings, "probe_max_long_edge", DEFAULT_MAX_LONG_EDGE))
    return value if value > 0 else DEFAULT_MAX_LONG_EDGE


def _ensure_probe_sys_path() -> None:
    vendor = PROBE_ROOT / "vendor_lib"
    if str(vendor) not in sys.path:
        sys.path.insert(0, str(vendor))
    if str(PROBE_ROOT) not in sys.path:
        sys.path.insert(0, str(PROBE_ROOT))


def _get_probe_inference() -> tuple[Callable[..., Any], Callable[..., Any]]:
    global _probe_imports
    if _probe_imports is not None:
        return _probe_imports
    _ensure_probe_sys_path()
    from probe_inference import load_probe_dino_checkpoint, probe_image_scores  # noqa: WPS433

    _probe_imports = (load_probe_dino_checkpoint, probe_image_scores)
    return _probe_imports


def resize_long_edge(image: Any, max_edge: int = DEFAULT_MAX_LONG_EDGE) -> Any:
    """Validated Step 8C.2 resize (no upscale)."""
    _ensure_probe_sys_path()
    from probe_inference import _resize_long_edge  # noqa: WPS433

    return _resize_long_edge(image, max_edge)


def probe_checkpoint_on_disk() -> bool:
    path = checkpoint_path()
    try:
        return path.is_file() and path.stat().st_size > 0
    except OSError:
        return False


def probe_detector_available() -> bool:
    """Checkpoint present and PyTorch can load (inference possible)."""
    if not torch_available():
        return False
    return probe_checkpoint_on_disk()


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _get_model() -> Any | None:
    global _model
    if _model is not None:
        return _model

    with _model_lock:
        if _model is not None:
            return _model
        if not probe_detector_available():
            logger.warning("probe_dino_detector: checkpoint missing at %s", checkpoint_path())
            return None
        ckpt = checkpoint_path()
        try:
            sha = _file_sha256(ckpt)
            if sha != EXPECTED_CHECKPOINT_SHA256:
                logger.error(
                    "probe_dino_detector: checkpoint SHA-256 mismatch (got %s, expected %s)",
                    sha,
                    EXPECTED_CHECKPOINT_SHA256,
                )
                return None
        except OSError:
            logger.warning("probe_dino_detector: could not read checkpoint for SHA-256", exc_info=True)
            return None

        try:
            load_probe_dino_checkpoint, _ = _get_probe_inference()
            HF_CACHE.mkdir(parents=True, exist_ok=True)
            torch = get_torch()
            if torch is None:
                return None
            model = load_probe_dino_checkpoint(ckpt, hf_cache=HF_CACHE)
            model.to(torch.device("cpu"))
            _model = model
            logger.info("probe_dino_detector: loaded PROBE checkpoint from %s", ckpt)
            return _model
        except Exception:
            logger.warning("probe_dino_detector: failed to load PROBE model", exc_info=True)
            return None


def probe_ai_probability(content: bytes) -> float | None:
    """Return P(AI-generated / fake) in [0, 1], or None if unavailable / invalid."""
    if not content or len(content) < 32:
        return None
    if not probe_detector_available():
        return None

    model = _get_model()
    if model is None:
        return None

    torch = get_torch()
    if torch is None:
        return None

    try:
        from PIL import Image

        image = Image.open(BytesIO(content)).convert("RGB")
        if image.size[0] < 8 or image.size[1] < 8:
            return None
    except Exception:
        logger.debug("probe_ai_probability: could not decode image bytes", exc_info=True)
        return None

    try:
        _, probe_image_scores = _get_probe_inference()
        device = torch.device("cpu")
        _, prob, _n_patches, _dims = probe_image_scores(
            model,
            content,
            device=device,
            patch_batch_size=PATCH_BATCH_SIZE,
            max_long_edge=max_long_edge(),
        )
    except Exception:
        logger.warning("probe_ai_probability: PROBE inference failed", exc_info=True)
        return None

    if prob is None or not np.isfinite(prob):
        return None
    return float(max(0.0, min(1.0, prob)))
