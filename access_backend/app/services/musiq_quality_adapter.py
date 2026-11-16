"""Map MUSIQ worker classical OpenCV raw metrics into the production quality contract.

Production quality engine is ``QUALITY_ENGINE=musiq_worker`` only (OpenCV fallback).
EfficientNet-B0 is retired from production routing.

Safety rules:
  - Map from worker ``criteria_raw`` only (production polarities).
  - Never treat ``criteria_q`` as production raw metrics (blur / blocking are
    higher-is-better in the worker q-space; production expects higher-is-worse
    for blur and blocking_artifacts).
  - MUSIQ OPQ is context-only; it must not feed individual 1-5 criteria.
  - Return None when the worker schema cannot be mapped safely (caller falls back).
"""

from __future__ import annotations

from typing import Any

# Scales aligned with access_backend/app/services/opencv_quality.py
_LAP_SCALE = 420.0
_NOISE_SCALE = 36.0
_RINGING_SCALE = 40.0

# Worker classical raw keys required for a safe production metrics dict.
REQUIRED_CRITERIA_RAW_KEYS = (
    "sharpness_laplacian_var",
    "brightness_mean",
    "contrast_rms",
    "blocking_flat_frac",
    "noise_residual_std",
)

ADAPTER_VERSION = "musiq_quality_adapter_v1"
MUSIQ_CONTEXT_KEY = "_musiq_opq_context"


def clip01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def worker_result_mappable(result: dict[str, Any] | None) -> bool:
    """True when worker payload has classical raw metrics we can map safely."""
    if not isinstance(result, dict):
        return False
    status = str(result.get("status") or "").strip().lower()
    if status in ("unavailable", "error"):
        return False
    raw = result.get("criteria_raw")
    if not isinstance(raw, dict):
        return False
    for key in REQUIRED_CRITERIA_RAW_KEYS:
        if key not in raw:
            return False
        try:
            float(raw[key])
        except (TypeError, ValueError):
            return False
    return True


def musiq_opq_context_from_result(result: dict[str, Any]) -> dict[str, Any]:
    """Thin OPQ context for analysis payloads; never used as criterion scores."""
    musiq = result.get("musiq") if isinstance(result.get("musiq"), dict) else {}
    status = musiq.get("status") or result.get("status") or "unavailable"
    if status not in ("ok", "unavailable", "error", "partial"):
        status = "error"
    raw = musiq.get("musiq_opq_raw")
    opq: float | None
    try:
        opq = float(raw) if raw is not None else None
        if opq is not None and not (opq == opq):  # NaN
            opq = None
    except (TypeError, ValueError):
        opq = None
    return {
        "status": status if opq is not None or status != "ok" else status,
        "musiq_opq_raw": opq,
        "musiq_scale": musiq.get("musiq_scale") or "approx_0_100_mos_like",
        "model_id": musiq.get("model_id") or "tfhub:google/musiq/paq2piq/1",
        "model_version": musiq.get("model_version"),
        "engine_handle": musiq.get("engine_handle"),
        "error": musiq.get("error") or (None if status == "ok" else result.get("error")),
        "context_only": True,
        "not_used_for_criteria": True,
        "source": "musiq_worker",
        "adapter": ADAPTER_VERSION,
    }


def _image_dimensions(content: bytes | None) -> tuple[int, int]:
    """Best-effort width/height for warnings; does not re-score quality."""
    if not content:
        return 0, 0
    try:
        from app.services.opencv_quality import decode_image

        bgr = decode_image(content)
        if bgr is not None:
            h, w = bgr.shape[:2]
            return int(w), int(h)
    except Exception:  # noqa: BLE001
        pass
    return 0, 0


def production_metrics_from_criteria_raw(
    raw: dict[str, Any],
    *,
    content: bytes | None = None,
    width: int | None = None,
    height: int | None = None,
) -> dict[str, Any]:
    """Convert worker classical raw measurements → ENET/OpenCV metric polarities."""
    sharpness = clip01(float(raw["sharpness_laplacian_var"]) / _LAP_SCALE)
    # Production blur is higher-is-worse (opencv_quality: blur = 1 - sharpness).
    blur = clip01(1.0 - sharpness)
    noise = clip01(float(raw["noise_residual_std"]) / _NOISE_SCALE)
    brightness = clip01(float(raw["brightness_mean"]))
    contrast = clip01(float(raw["contrast_rms"]))
    # Production blocking_artifacts is higher-is-worse (flat-block fraction).
    blocking = clip01(float(raw["blocking_flat_frac"]))
    ringing_raw = raw.get("ringing_edge_lap")
    try:
        ringing = clip01(float(ringing_raw) / _RINGING_SCALE) if ringing_raw is not None else 0.08
    except (TypeError, ValueError):
        ringing = 0.08

    w = int(width) if width is not None else 0
    h = int(height) if height is not None else 0
    if w <= 0 or h <= 0:
        dw, dh = _image_dimensions(content)
        w = w if w > 0 else dw
        h = h if h > 0 else dh

    return {
        "sharpness": sharpness,
        "blur": blur,
        "noise": noise,
        "brightness": brightness,
        "contrast": contrast,
        "blocking_artifacts": blocking,
        "ringing_artifacts": ringing,
        "width": int(w),
        "height": int(h),
    }


def metrics_from_worker_result(
    result: dict[str, Any] | None,
    *,
    content: bytes | None = None,
) -> dict[str, Any] | None:
    """Return production metrics (+ optional MUSIQ context) or None if unsafe.

    On success the dict matches ``opencv_quality.analyze_image_bytes`` keys and may
    include ``MUSIQ_CONTEXT_KEY`` for analysis-only OPQ context (pop before averaging
    foreign keys if needed).
    """
    if not worker_result_mappable(result):
        return None
    assert isinstance(result, dict)
    raw = result["criteria_raw"]
    assert isinstance(raw, dict)
    metrics = production_metrics_from_criteria_raw(raw, content=content)
    metrics[MUSIQ_CONTEXT_KEY] = musiq_opq_context_from_result(result)
    metrics["_adapter"] = ADAPTER_VERSION
    metrics["_classical_map_version"] = result.get("classical_map_version")
    return metrics


def strip_adapter_metadata(metrics: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Split production metric keys from adapter-only metadata."""
    out = {
        k: v
        for k, v in metrics.items()
        if not str(k).startswith("_")
    }
    ctx = metrics.get(MUSIQ_CONTEXT_KEY)
    return out, ctx if isinstance(ctx, dict) else None
