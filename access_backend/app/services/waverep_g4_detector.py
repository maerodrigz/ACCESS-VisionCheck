"""WaveRep G4 practice-video AI authenticity (inactive until WAVEREP_ENABLED=true).

Photos use PROBE. When enabled, videos use WaveRep G4 only (no PROBE-on-frames).

Asset layout:
  access_backend/ml/waverep/waverep_detector.py
  access_backend/ml/waverep/demo/utils.py
  access_backend/ml/waverep/demo/weights/weights_dinov2_G4.ckpt
"""

from __future__ import annotations

import importlib
import logging
import sys
import tempfile
import threading
import uuid
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

BACKEND_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WAVEREP_DIR = BACKEND_ROOT / "ml" / "waverep"
DEFAULT_CHECKPOINT_REL = Path("ml/waverep/demo/weights/weights_dinov2_G4.ckpt")

_detector_lock = threading.Lock()
_inference_lock = threading.Lock()
_detector_instance: Any | None = None
_detector_init_error: str | None = None


def waverep_enabled() -> bool:
    from app.config import settings

    return bool(getattr(settings, "waverep_enabled", False))


def is_waverep_video_detection_enabled() -> bool:
    return waverep_enabled()


def waverep_module_dir() -> Path:
    from app.config import settings

    raw = (getattr(settings, "waverep_module_dir", None) or "").strip()
    if raw:
        path = Path(raw)
        if not path.is_absolute():
            path = BACKEND_ROOT / path
        return path
    return DEFAULT_WAVEREP_DIR


def waverep_checkpoint_path() -> Path:
    from app.config import settings

    raw = (getattr(settings, "waverep_checkpoint_path", None) or "").strip()
    if raw:
        path = Path(raw)
        if not path.is_absolute():
            path = BACKEND_ROOT / path
        return path
    return BACKEND_ROOT / DEFAULT_CHECKPOINT_REL


def _waverep_device() -> str:
    from app.config import settings

    device = (getattr(settings, "waverep_device", None) or "cpu").strip()
    return device or "cpu"


def _waverep_samples() -> int:
    from app.config import settings

    return max(1, int(getattr(settings, "waverep_samples", 20)))


def waverep_runtime_status() -> dict[str, Any]:
    ckpt = waverep_checkpoint_path()
    mod_dir = waverep_module_dir()
    module_file = mod_dir / "waverep_detector.py"
    return {
        "enabled": waverep_enabled(),
        "module_dir": str(mod_dir),
        "module_file_exists": module_file.is_file(),
        "checkpoint_path": str(ckpt),
        "checkpoint_exists": ckpt.is_file(),
        "samples": _waverep_samples(),
        "device": _waverep_device(),
        "detector_initialized": _detector_instance is not None,
        "init_error": _detector_init_error,
    }


def _ensure_waverep_import_path() -> None:
    mod_dir = str(waverep_module_dir())
    if mod_dir not in sys.path:
        sys.path.insert(0, mod_dir)


def _resolve_detector_instance() -> Any | None:
    global _detector_instance, _detector_init_error

    if _detector_instance is not None:
        return _detector_instance
    if _detector_init_error is not None:
        return None

    with _detector_lock:
        if _detector_instance is not None:
            return _detector_instance
        if _detector_init_error is not None:
            return None

        ckpt = waverep_checkpoint_path()
        if not ckpt.is_file():
            _detector_init_error = f"checkpoint missing: {ckpt}"
            logger.warning("WaveRep G4 unavailable: %s", _detector_init_error)
            return None

        _ensure_waverep_import_path()
        try:
            module = importlib.import_module("waverep_detector")
            cls = module.WaveRepDetector
        except Exception as exc:
            _detector_init_error = f"import waverep_detector failed: {exc}"
            logger.warning("WaveRep G4 unavailable: %s", _detector_init_error)
            return None

        try:
            instance = cls(
                weights=str(ckpt),
                device=_waverep_device(),
                samples=_waverep_samples(),
            )
        except Exception as exc:
            _detector_init_error = f"WaveRepDetector init failed: {exc}"
            logger.warning("WaveRep G4 unavailable: %s", _detector_init_error)
            return None

        if not callable(getattr(instance, "analyze", None)):
            _detector_init_error = "WaveRepDetector.analyze is missing"
            return None

        _detector_instance = instance
        logger.info("WaveRep G4 detector loaded (weights=%s)", ckpt.name)
        return _detector_instance


def _video_suffix(video_ext: str, file_name: str) -> str:
    ext = (video_ext or "").strip().lower()
    if not ext and file_name:
        ext = Path(file_name).suffix.lower()
    if not ext:
        return ".mp4"
    if not ext.startswith("."):
        ext = f".{ext}"
    allowed = {".mp4", ".mov", ".avi", ".webm", ".mkv", ".m4v", ".3gp", ".wmv"}
    return ext if ext in allowed else ".mp4"


def _write_temp_video_file(video_content: bytes, *, suffix: str) -> Path:
    tmp_dir = Path(tempfile.gettempdir()) / "access_waverep"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    path = tmp_dir / f"eval_{uuid.uuid4().hex}{suffix}"
    path.write_bytes(video_content)
    return path


def _run_waverep_inference(
    video_content: bytes,
    *,
    video_ext: str,
    file_name: str,
) -> dict[str, Any] | None:
    detector = _resolve_detector_instance()
    if detector is None:
        return None

    suffix = _video_suffix(video_ext, file_name)
    temp_path: Path | None = None
    try:
        temp_path = _write_temp_video_file(video_content, suffix=suffix)
        with _inference_lock:
            raw = detector.analyze(str(temp_path))
    except Exception as exc:
        logger.exception("WaveRep G4 inference failed")
        return {"status": "error", "error": str(exc)}
    finally:
        if temp_path is not None:
            try:
                temp_path.unlink(missing_ok=True)
            except OSError:
                logger.warning("WaveRep temp video cleanup failed: %s", temp_path)

    if not isinstance(raw, dict):
        return {"status": "error", "error": "WaveRep returned non-dict result"}
    return raw


def waverep_analysis_unavailable_payload(reason: str) -> dict[str, Any]:
    return {
        "verdict": "suspicious",
        "confidence": 0.0,
        "probability": None,
        "raw_detector_probability": None,
        "detail": (
            f"WaveRep G4 video authenticity analysis unavailable ({reason}). "
            "Officer review is required. This is not verified as human capture."
        ),
        "signals": {},
        "detector_backend": "waverep_g4",
        "risk_level": "suspicious",
        "requires_review": True,
        "waverep_analysis_unavailable": True,
        "waverep_processing_status": "unavailable",
    }


def _failed_frame_count(raw: dict[str, Any]) -> int:
    failed = raw.get("failed_frames")
    if failed is None:
        return 0
    if isinstance(failed, list):
        return len(failed)
    try:
        return int(failed)
    except (TypeError, ValueError):
        return 0


def _normalize_prediction(prediction: str) -> str:
    p = (prediction or "").strip().lower()
    if not p:
        return ""
    if "ai-generated" in p or "ai generated" in p or p in ("ai", "fake", "synthetic"):
        return "ai_generated"
    if p.startswith("real") or "non-ai" in p or p in ("human", "authentic"):
        return "real"
    if "generated" in p:
        return "ai_generated"
    return p


def _map_waverep_raw_to_ai_payload(raw: dict[str, Any]) -> dict[str, Any]:
    from app.config import settings

    status = str(raw.get("status") or raw.get("processing_status") or "").lower()
    processed = int(raw.get("processed_frames") or 0)
    requested = int(raw.get("requested_frames") or 0)
    failed_count = _failed_frame_count(raw)
    min_frames = max(1, int(getattr(settings, "waverep_min_successful_frames", 1)))
    frame_results = raw.get("frame_results")
    supplementary: dict[str, Any] = {
        "waverep_total_frames": raw.get("total_frames"),
        "waverep_requested_frames": requested,
        "waverep_processed_frames": processed,
        "waverep_failed_frame_indices": raw.get("failed_frames")
        if isinstance(raw.get("failed_frames"), list)
        else None,
        "waverep_mean_logit": raw.get("mean_logit"),
        "waverep_threshold": raw.get("threshold"),
        "waverep_model": raw.get("model"),
    }
    if isinstance(frame_results, list):
        supplementary["waverep_frame_results"] = frame_results

    if status in ("error", "failed", "unavailable"):
        out = waverep_analysis_unavailable_payload(status or "failed")
        out["waverep_raw"] = raw
        out["waverep_supplementary"] = supplementary
        return out

    if processed < min_frames:
        out = waverep_analysis_unavailable_payload(
            f"insufficient processed frames ({processed}<{min_frames})"
        )
        out["waverep_raw"] = raw
        out["waverep_supplementary"] = supplementary
        return out

    score_raw = raw.get("ai_score")
    if score_raw is None:
        out = waverep_analysis_unavailable_payload("missing ai_score")
        out["waverep_raw"] = raw
        out["waverep_supplementary"] = supplementary
        return out

    try:
        p = float(score_raw)
    except (TypeError, ValueError):
        out = waverep_analysis_unavailable_payload("invalid ai_score")
        out["waverep_raw"] = raw
        out["waverep_supplementary"] = supplementary
        return out

    if p > 1.0 and p <= 100.0:
        p = p / 100.0
    p = max(0.0, min(1.0, p))

    prediction_norm = _normalize_prediction(str(raw.get("prediction") or ""))
    low = float(getattr(settings, "probe_low_risk_threshold", 0.30))
    high = float(getattr(settings, "probe_high_risk_threshold", 0.45))

    if prediction_norm == "ai_generated":
        verdict = "ai_generated"
        risk_level = "high"
    elif prediction_norm == "real":
        verdict = "authentic"
        risk_level = "low" if p < low else ("suspicious" if p < high else "high")
    elif p >= high:
        verdict = "ai_generated"
        risk_level = "high"
    elif p >= low:
        verdict = "suspicious"
        risk_level = "suspicious"
    else:
        verdict = "authentic"
        risk_level = "low"

    requires_review = risk_level != "low" or status == "partial"

    if verdict == "authentic" and risk_level == "low" and status != "partial":
        confidence = 1.0 - p
        detail = (
            f"Low AI authenticity risk from WaveRep G4 ({int(p * 100)}% AI score, "
            f"{processed}/{requested or processed} frames). "
            "This is not proof of human origin."
        )
    elif verdict == "suspicious" or risk_level == "suspicious" or status == "partial":
        verdict = "suspicious"
        confidence = p if p > 0 else 0.5
        if status == "partial":
            detail = (
                f"WaveRep G4 partial frame analysis ({processed}/{requested} frames, "
                f"{failed_count} failed). AI score {int(p * 100)}%. Admin review required."
            )
        else:
            detail = (
                f"Elevated AI authenticity risk from WaveRep G4 ({int(p * 100)}% AI score). "
                "Manual review is recommended."
            )
        requires_review = True
    else:
        verdict = "ai_generated"
        confidence = p
        detail = (
            f"High AI authenticity risk from WaveRep G4 ({int(p * 100)}% AI score). "
            "Requires officer review."
        )
        requires_review = True

    return {
        "verdict": verdict,
        "confidence": round(confidence, 3),
        "probability": round(p, 3),
        "raw_detector_probability": round(p, 3),
        "detail": detail,
        "signals": {"waverep_g4": round(p, 3)},
        "detector_backend": "waverep_g4",
        "risk_level": "suspicious" if status == "partial" and risk_level == "low" else risk_level,
        "requires_review": requires_review,
        "waverep_processing_status": status or "complete",
        "waverep_frames_analyzed": processed,
        "waverep_failed_frames": failed_count,
        "waverep_prediction": raw.get("prediction"),
        "waverep_supplementary": supplementary,
        "waverep_raw": raw,
    }


def detect_ai_generated_video(
    video_content: bytes,
    *,
    video_ext: str = ".mp4",
    file_name: str = "",
) -> dict[str, Any]:
    """WaveRep-only video authenticity with camera provenance overlay (no PROBE fallback)."""
    from app.services.ai_authenticity_detector import _video_provenance_exif_panel
    from app.services.camera_provenance import classify_video_container_provenance
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    if not video_content:
        return waverep_analysis_unavailable_payload("empty video")

    raw = _run_waverep_inference(video_content, video_ext=video_ext, file_name=file_name)
    if raw is None:
        reason = _detector_init_error or "detector not loaded"
        return waverep_analysis_unavailable_payload(reason)

    payload = _map_waverep_raw_to_ai_payload(raw)
    video_provenance = classify_video_container_provenance(
        video_content, video_ext, file_name=file_name
    )
    from app.services.probe_provenance_policy import merge_provenance_policy_exif_fields

    payload = apply_probe_provenance_policy(payload, video_provenance, file_name=file_name)
    payload["exif_metadata"] = _video_provenance_exif_panel(video_provenance, file_name)
    payload = merge_provenance_policy_exif_fields(payload)
    if isinstance(payload.get("exif_metadata"), dict):
        meta = dict(payload["exif_metadata"])
        meta["detector_backend"] = "waverep_g4"
        supp = payload.get("waverep_supplementary")
        if isinstance(supp, dict):
            meta["waverep_supplementary"] = supp
        payload["exif_metadata"] = meta
    return payload
