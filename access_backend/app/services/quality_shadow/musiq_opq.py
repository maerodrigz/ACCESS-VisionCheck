"""Lazy official MUSIQ PaQ-2-PiQ loader for quality shadow OPQ only.

Never applies production `_soft_score` to MUSIQ output.
Never substitutes prior research/cached benchmark CSV scores for new uploads.
TensorFlow is optional and must not be imported when QUALITY_SHADOW_ENABLED=false.
"""

from __future__ import annotations

import logging
import os
import threading
from typing import Any

logger = logging.getLogger(__name__)

MUSIQ_MODEL_ID = "tfhub:google/musiq/paq2piq/1"
MUSIQ_SCALE = "approx_0_100_mos_like"
TFHUB_PAQ2PIQ = "https://tfhub.dev/google/musiq/paq2piq/1"
KAGGLE_PAQ2PIQ = "https://www.kaggle.com/models/google/musiq/TensorFlow2/paq2piq/1"

_lock = threading.Lock()
_predict_fn: Any | None = None
_engine_handle: str | None = None
_load_error: str | None = None
_load_attempted = False


def reset_musiq_loader_for_tests() -> None:
    """Test helper: clear lazy MUSIQ state."""
    global _predict_fn, _engine_handle, _load_error, _load_attempted
    with _lock:
        _predict_fn = None
        _engine_handle = None
        _load_error = None
        _load_attempted = False


def musiq_runtime_available() -> bool:
    """True only when TensorFlow + tensorflow_hub import without loading weights."""
    try:
        import importlib.util

        return bool(
            importlib.util.find_spec("tensorflow")
            and importlib.util.find_spec("tensorflow_hub")
        )
    except Exception:  # noqa: BLE001
        return False


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


def ensure_musiq_predict_fn(*, tfhub_cache_dir: str | None = None) -> tuple[Any | None, str | None, str | None]:
    """Lazy-load official TF Hub SavedModel once. Returns (fn, handle, error)."""
    global _predict_fn, _engine_handle, _load_error, _load_attempted
    with _lock:
        if _load_attempted:
            return _predict_fn, _engine_handle, _load_error
        _load_attempted = True
        if not musiq_runtime_available():
            _load_error = (
                "MUSIQ runtime unavailable: tensorflow / tensorflow_hub not installed "
                "in this environment"
            )
            return None, None, _load_error
        try:
            os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
            if tfhub_cache_dir:
                os.makedirs(tfhub_cache_dir, exist_ok=True)
                os.environ["TFHUB_CACHE_DIR"] = tfhub_cache_dir
            import tensorflow as tf
            import tensorflow_hub as hub

            tf.config.set_visible_devices([], "GPU")
            last_err: Exception | None = None
            for handle in (TFHUB_PAQ2PIQ, KAGGLE_PAQ2PIQ):
                try:
                    model = hub.load(handle)
                    _predict_fn = model.signatures["serving_default"]
                    _engine_handle = handle
                    _load_error = None
                    logger.info("quality shadow: loaded MUSIQ OPQ engine handle=%s", handle)
                    return _predict_fn, _engine_handle, None
                except Exception as exc:  # noqa: BLE001
                    last_err = exc
            _load_error = f"Could not load official MUSIQ PaQ-2-PiQ: {last_err}"
            return None, None, _load_error
        except Exception as exc:  # noqa: BLE001
            _load_error = f"MUSIQ load failed: {exc}"
            logger.warning("quality shadow: %s", _load_error)
            return None, None, _load_error


def score_image_bytes_musiq(content: bytes, *, tfhub_cache_dir: str | None = None) -> dict[str, Any]:
    """Score JPEG/PNG bytes with MUSIQ. Does not use cached research CSV scores.

    Prefers the remote MUSIQ worker when configured (Linux TF Hub path). Falls back
    to optional local TensorFlow only when the remote path is unset or returns
    unavailable/error without a score.
    """
    if not content:
        return {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "engine_handle": None,
            "error": "empty image bytes",
        }

    try:
        from app.config import settings
        from app.services.musiq_worker_client import (
            evaluate_bytes,
            musiq_opq_from_worker_result,
            musiq_worker_configured,
        )

        if settings.musiq_worker_prefer_remote and musiq_worker_configured():
            remote = evaluate_bytes(content, media_type="photo", filename="shadow.jpg")
            mapped = musiq_opq_from_worker_result(remote)
            if mapped.get("status") == "ok" and mapped.get("musiq_opq_raw") is not None:
                return mapped
            # Offline/timeout: do not invent scores; try local TF only if present.
            logger.info(
                "quality shadow: remote MUSIQ unavailable (%s); trying local TF if present",
                mapped.get("error"),
            )
    except Exception as exc:  # noqa: BLE001
        logger.warning("quality shadow: remote MUSIQ client error: %s", exc)

    predict_fn, handle, err = ensure_musiq_predict_fn(tfhub_cache_dir=tfhub_cache_dir)
    if predict_fn is None:
        return {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "engine_handle": handle,
            "error": err or "MUSIQ unavailable",
        }
    try:
        import tensorflow as tf

        prediction = predict_fn(tf.constant(content))
        score = _scalar_from_hub(prediction)
        return {
            "status": "ok",
            "musiq_opq_raw": score,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "engine_handle": handle,
            "error": None,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "status": "error",
            "musiq_opq_raw": None,
            "musiq_scale": MUSIQ_SCALE,
            "model_id": MUSIQ_MODEL_ID,
            "engine_handle": handle,
            "error": str(exc),
        }
