"""Validation engines: OpenCV (active). EfficientNet-B0 permanently retired."""

from __future__ import annotations

from typing import Any, Literal

EngineId = Literal["efficientnet", "opencv"]

ENGINE_EFFICIENTNET: EngineId = "efficientnet"
ENGINE_OPENCV: EngineId = "opencv"

_ENET_RETIRED = (
    "efficientnet_retired: EfficientNet-B0 was removed from ACCESS VisionCheck. "
    "Use OpenCV (or production MUSIQ worker). Historical ENET reports remain under "
    "tools/quality_validation/ as evidence only."
)


def engine_availability() -> dict[str, bool | str]:
    """Report whether each engine can run in this environment."""
    out: dict[str, bool | str] = {
        "efficientnet": False,
        "opencv": False,
        "efficientnet_status": "permanently_retired",
        "efficientnet_error": _ENET_RETIRED,
    }
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
        return None, "efficientnet_retired"

    if engine == ENGINE_OPENCV:
        from app.services.opencv_quality import analyze_image_bytes, opencv_available

        if not opencv_available():
            return None, "opencv_unavailable"
        metrics = analyze_image_bytes(content)
        if metrics is None:
            return None, "opencv_inference_failed"
        return metrics, None

    return None, "unknown_engine"
