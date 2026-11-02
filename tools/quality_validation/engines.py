"""Explicit EfficientNet vs OpenCV analysis (no silent fallback)."""

from __future__ import annotations

from typing import Any, Literal

EngineId = Literal["efficientnet", "opencv"]

ENGINE_EFFICIENTNET: EngineId = "efficientnet"
ENGINE_OPENCV: EngineId = "opencv"


def engine_availability() -> dict[str, bool | str]:
    """Report whether each engine can run in this environment."""
    out: dict[str, bool | str] = {"efficientnet": False, "opencv": False}
    try:
        from app.services.efficientnet_b0_scorer import (
            MODEL_ID,
            MODEL_VERSION,
            efficientnet_available,
            ensure_weights,
            weights_path,
        )

        out["efficientnet_model_id"] = MODEL_ID
        out["efficientnet_model_version"] = MODEL_VERSION
        out["efficientnet_weights_path"] = str(weights_path())
        out["efficientnet"] = bool(efficientnet_available() and ensure_weights())
    except Exception as exc:  # pragma: no cover
        out["efficientnet_error"] = str(exc)
    try:
        from app.services.opencv_quality import opencv_available

        out["opencv"] = bool(opencv_available())
    except Exception as exc:  # pragma: no cover
        out["opencv_error"] = str(exc)
    return out


def analyze_image_metrics(content: bytes, engine: EngineId) -> tuple[dict[str, Any] | None, str | None]:
    """
    Return (metrics_dict, error_code). Never falls back to the other engine.
    error_code is None on success.
    """
    if not content:
        return None, "empty_input"

    if engine == ENGINE_EFFICIENTNET:
        from app.services.efficientnet_b0_scorer import (
            analyze_image_bytes,
            efficientnet_available,
            ensure_weights,
        )

        if not efficientnet_available():
            return None, "efficientnet_unavailable"
        if not ensure_weights():
            return None, "efficientnet_weights_missing"
        metrics = analyze_image_bytes(content)
        if metrics is None:
            return None, "efficientnet_inference_failed"
        return metrics, None

    if engine == ENGINE_OPENCV:
        from app.services.opencv_quality import analyze_image_bytes, opencv_available

        if not opencv_available():
            return None, "opencv_unavailable"
        metrics = analyze_image_bytes(content)
        if metrics is None:
            return None, "opencv_inference_failed"
        return metrics, None

    return None, "unknown_engine"
