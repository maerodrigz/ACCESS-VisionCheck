"""Official TF Hub MUSIQ PaQ-2-PiQ loader (once at worker startup)."""

from __future__ import annotations

import logging
import os
import threading
from typing import Any

logger = logging.getLogger(__name__)

MUSIQ_MODEL_ID = "tfhub:google/musiq/paq2piq/1"
MUSIQ_MODEL_VERSION = "paq2piq/1"
MUSIQ_SCALE = "approx_0_100_mos_like"
KAGGLE_PAQ2PIQ = "https://www.kaggle.com/models/google/musiq/TensorFlow2/paq2piq/1"

_lock = threading.Lock()
_predict_fn: Any | None = None
_engine_handle: str | None = None
_load_error: str | None = None
_ready = False


def reset_for_tests() -> None:
    global _predict_fn, _engine_handle, _load_error, _ready
    with _lock:
        _predict_fn = None
        _engine_handle = None
        _load_error = None
        _ready = False


def is_ready() -> bool:
    return _ready and _predict_fn is not None


def load_error() -> str | None:
    return _load_error


def engine_handle() -> str | None:
    return _engine_handle


def _scalar_from_hub(prediction: Any) -> float:
    import numpy as np

    if isinstance(prediction, dict):
        if "output_0" in prediction:
            tensor = prediction["output_0"]
        elif len(prediction) == 1:
            tensor = next(iter(prediction.values()))
        else:
            for key in ("mos", "predictions", "output", "outputs"):
                if key in prediction:
                    tensor = prediction[key]
                    break
            else:
                tensor = prediction[sorted(prediction.keys())[0]]
    else:
        tensor = prediction
    numpy = tensor.numpy() if hasattr(tensor, "numpy") else tensor
    arr = np.asarray(numpy, dtype=float).reshape(-1)
    if arr.size == 0:
        raise RuntimeError("empty MUSIQ prediction")
    return float(arr[0])


def load_musiq(*, tfhub_cache_dir: str, handle: str) -> None:
    """Load SavedModel once. Safe to call repeatedly; no-ops when already ready."""
    global _predict_fn, _engine_handle, _load_error, _ready
    with _lock:
        if _ready and _predict_fn is not None:
            return
        try:
            os.makedirs(tfhub_cache_dir, exist_ok=True)
            os.environ["TFHUB_CACHE_DIR"] = tfhub_cache_dir
            os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
            import tensorflow as tf
            import tensorflow_hub as hub

            tf.config.set_visible_devices([], "GPU")
            last_err: Exception | None = None
            for candidate in (handle, KAGGLE_PAQ2PIQ):
                try:
                    model = hub.load(candidate)
                    _predict_fn = model.signatures["serving_default"]
                    _engine_handle = candidate
                    _load_error = None
                    _ready = True
                    logger.info("MUSIQ loaded handle=%s", candidate)
                    return
                except Exception as exc:  # noqa: BLE001
                    last_err = exc
            _predict_fn = None
            _engine_handle = None
            _ready = False
            _load_error = f"Could not load official MUSIQ PaQ-2-PiQ: {last_err}"
            logger.error("%s", _load_error)
        except Exception as exc:  # noqa: BLE001
            _predict_fn = None
            _engine_handle = None
            _ready = False
            _load_error = f"MUSIQ load failed: {exc}"
            logger.error("%s", _load_error)


def score_image_bytes(content: bytes) -> dict[str, Any]:
    """Score JPEG/PNG bytes. Never invents scores when the model is not ready."""
    if not content:
        return {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": _engine_handle,
            "error": "empty image bytes",
        }
    if not is_ready() or _predict_fn is None:
        return {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": _engine_handle,
            "error": _load_error or "MUSIQ model not loaded",
        }
    try:
        import tensorflow as tf

        # Verified Colab signature: image_bytes_tensor (tf.string) -> output_0 (float32)
        prediction = _predict_fn(tf.constant(content))
        score = _scalar_from_hub(prediction)
        return {
            "status": "ok",
            "musiq_opq_raw": score,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": _engine_handle,
            "error": None,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "status": "error",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "model_version": MUSIQ_MODEL_VERSION,
            "engine_handle": _engine_handle,
            "error": str(exc),
        }
