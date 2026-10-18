"""Multi-signal AI-generated media authenticity detector."""

from __future__ import annotations

import re
from io import BytesIO
from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

try:
    from PIL import Image
    from PIL.ExifTags import TAGS
except ImportError:  # pragma: no cover
    Image = None  # type: ignore
    TAGS = {}

from app.services.dedicated_ai_detector import active_ai_detector_backend, dedicated_ai_probability
from app.services.opencv_quality import decode_image

AI_GENERATED_THRESHOLD = 0.58
SUSPICIOUS_THRESHOLD = 0.36

_AI_SOFTWARE_HINTS = (
    "midjourney",
    "dall",
    "dalle",
    "chatgpt",
    "gpt_image",
    "gpt image",
    "sora",
    "flux",
    "imagen",
    "stable diffusion",
    "stablediffusion",
    "comfyui",
    "automatic1111",
    "firefly",
    "leonardo",
    "ideogram",
    "playground",
    "generated",
    "openai",
    "gemini",
    "bing image",
    "copilot",
)


def _probe_risk_thresholds() -> tuple[float, float]:
    from app.config import settings

    return float(settings.probe_low_risk_threshold), float(settings.probe_high_risk_threshold)


def probe_risk_level_from_probability(probability: float) -> str:
    """Map raw PROBE P(fake) to low / suspicious / high (validation-set candidate thresholds)."""
    low, high = _probe_risk_thresholds()
    if probability < low:
        return "low"
    if probability < high:
        return "suspicious"
    return "high"


def _collect_forensic_support(content: bytes, *, file_name: str) -> tuple[dict[str, float], list[str]]:
    """OpenCV/metadata/filename signals for context only (not fused with PROBE in probe backend mode)."""
    signals: dict[str, float] = {}
    reasons: list[str] = []

    fn_score, fn_reason = _filename_ai_hint_score(file_name)
    if fn_score > 0:
        signals["filename"] = fn_score
        if fn_reason:
            reasons.append(fn_reason)

    meta_score, meta_reason = _metadata_score(content, file_name)
    if meta_score > 0:
        signals["metadata"] = meta_score
        if meta_reason:
            reasons.append(meta_reason)

    bgr = decode_image(content)
    if bgr is not None and cv2 is not None:
        signals["frequency"] = _frequency_anomaly_score(bgr)
        signals["noise_uniformity"] = _noise_uniformity_score(bgr)
        signals["texture_entropy"] = _texture_entropy_score(bgr)
        signals["quality_paradox"] = _quality_paradox_score(bgr)
        signals["skin_smoothness"] = _skin_smoothness_score(bgr)
    return signals, reasons


def _detect_ai_generated_probe(
    content: bytes,
    *,
    file_name: str = "",
    apply_provenance_policy: bool = True,
    provenance: "CameraProvenanceResult | None" = None,
) -> dict[str, Any]:
    """PROBE backend: raw P(fake) risk bands only; supporting forensic signals are not fused."""
    from app.services.camera_provenance import CameraProvenanceResult, classify_photo_camera_provenance
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    support_signals, support_reasons = _collect_forensic_support(content, file_name=file_name)
    exif_metadata = extract_exif_metadata(content, file_name)

    raw_p = dedicated_ai_probability(content)
    if raw_p is None:
        detail = (
            "PROBE authenticity analysis could not run (checkpoint missing, corrupt, or inference failed). "
            "Officer review is required. This is not a low-risk clearance."
        )
        fail_payload = {
            "verdict": "suspicious",
            "confidence": 0.0,
            "probability": None,
            "detail": detail,
            "signals": {},
            "exif_metadata": exif_metadata,
            "detector_backend": "probe",
            "risk_level": "suspicious",
            "raw_detector_probability": None,
            "requires_review": True,
        }
        if apply_provenance_policy:
            prov = provenance if provenance is not None else classify_photo_camera_provenance(content, file_name)
            return apply_probe_provenance_policy(fail_payload, prov)
        return fail_payload

    p = float(max(0.0, min(1.0, raw_p)))
    risk_level = probe_risk_level_from_probability(p)
    requires_review = risk_level != "low"

    if risk_level == "low":
        verdict = "authentic"
        confidence = 1.0 - p
        detail = (
            f"Low AI authenticity risk from PROBE ({int(p * 100)}% P(fake)). "
            "This is not proof of authenticity."
        )
    elif risk_level == "suspicious":
        verdict = "suspicious"
        confidence = p
        detail = (
            f"Elevated AI authenticity risk from PROBE ({int(p * 100)}% P(fake)). "
            "Manual review is recommended."
        )
    else:
        verdict = "ai_generated"
        confidence = p
        detail = (
            f"High AI authenticity risk from PROBE ({int(p * 100)}% P(fake)). "
            "Requires officer review; not definitive proof of AI generation."
        )

    if support_reasons:
        detail = f"{detail} Supporting context: {' '.join(support_reasons[:2])}"

    signals = {"probe": round(p, 3)}
    for key, val in support_signals.items():
        signals[f"support_{key}"] = round(val, 3)

    payload = {
        "verdict": verdict,
        "confidence": round(confidence, 3),
        "probability": round(p, 3),
        "detail": detail,
        "signals": signals,
        "exif_metadata": exif_metadata,
        "detector_backend": "probe",
        "risk_level": risk_level,
        "raw_detector_probability": round(p, 3),
        "requires_review": requires_review,
    }
    if apply_provenance_policy:
        prov = provenance if provenance is not None else classify_photo_camera_provenance(content, file_name)
        payload = apply_probe_provenance_policy(payload, prov)
        if isinstance(payload.get("exif_metadata"), dict):
            meta = dict(payload["exif_metadata"])
            meta["camera_provenance_strength"] = payload.get("camera_provenance_strength")
            meta["camera_provenance_reasons"] = payload.get("camera_provenance_reasons")
            meta["visual_risk_level"] = payload.get("visual_risk_level")
            meta["provenance_policy_outcome"] = payload.get("provenance_policy_outcome")
            payload["exif_metadata"] = meta
    return payload


def detect_ai_generated(
    content: bytes,
    *,
    file_name: str = "",
    apply_provenance_policy: bool = True,
) -> dict[str, Any]:
    """Return ai_detection payload for evaluation + pipeline."""
    fn_score, fn_reason = _filename_ai_hint_score(file_name)

    if not content:
        if fn_score > 0:
            probability = fn_score
            verdict, confidence = _verdict_from_probability(probability)
            detail = _finalize_detection_detail(
                _build_detail(verdict, [fn_reason] if fn_reason else [], probability),
                verdict,
                probability,
            )
            return {
                "verdict": verdict,
                "confidence": round(confidence, 3),
                "probability": round(probability, 3),
                "detail": detail,
                "signals": {"filename": round(fn_score, 3)},
                "exif_metadata": extract_exif_metadata(content, file_name),
            }
        return _authentic_fallback("Empty file — no authenticity signals.")

    if active_ai_detector_backend() == "probe":
        return _detect_ai_generated_probe(
            content,
            file_name=file_name,
            apply_provenance_policy=apply_provenance_policy,
        )

    signals: dict[str, float] = {}
    reasons: list[str] = []

    if fn_score > 0:
        signals["filename"] = fn_score
        if fn_reason:
            reasons.append(fn_reason)

    meta_score, meta_reason = _metadata_score(content, file_name)
    if meta_score > fn_score:
        if meta_score > 0:
            signals["metadata"] = meta_score
            if meta_reason:
                reasons.append(meta_reason)
    elif fn_score <= 0 and meta_score > 0:
        signals["metadata"] = meta_score
        if meta_reason:
            reasons.append(meta_reason)

    bgr = decode_image(content)
    if bgr is not None and cv2 is not None:
        signals["frequency"] = _frequency_anomaly_score(bgr)
        signals["noise_uniformity"] = _noise_uniformity_score(bgr)
        signals["texture_entropy"] = _texture_entropy_score(bgr)
        signals["quality_paradox"] = _quality_paradox_score(bgr)
        signals["skin_smoothness"] = _skin_smoothness_score(bgr)

        if signals["frequency"] >= 0.55:
            reasons.append("Unusual frequency patterns common in synthetic images.")
        if signals["noise_uniformity"] >= 0.55:
            reasons.append("Noise is unusually uniform across the frame.")
        if signals["quality_paradox"] >= 0.55:
            reasons.append("Overly clean detail with unnaturally low sensor noise.")
        if signals.get("skin_smoothness", 0) >= 0.55:
            reasons.append("Portrait regions look unnaturally smooth compared to edge detail.")

    combined_meta = max(meta_score, fn_score)

    model_p = dedicated_ai_probability(content)
    if model_p is not None:
        if model_p >= 0.55:
            signals["neural"] = max(0.0, min(1.0, (model_p - 0.5) * 2))
            if model_p >= 0.55:
                reasons.append("Neural authenticity model flagged synthetic characteristics.")
        elif model_p <= 0.38:
            # Strong authentic read from the neural head — dampens false positives.
            signals["neural_authentic"] = max(0.0, min(1.0, (0.5 - model_p) * 2))

    probability = _fuse_probability(signals, combined_meta)
    if signals.get("quality_paradox", 0) >= 0.48 and combined_meta >= 0.32:
        probability = min(0.98, probability + 0.16)
        if "Overly clean detail" not in " ".join(reasons):
            reasons.append("Clean synthetic-looking detail on a file without camera metadata.")
    if signals.get("skin_smoothness", 0) >= 0.55 and signals.get("quality_paradox", 0) >= 0.45:
        probability = min(0.98, probability + 0.12)
    if (
        signals.get("noise_uniformity", 0) >= 0.55
        and signals.get("quality_paradox", 0) >= 0.55
        and combined_meta >= 0.32
    ):
        probability = min(0.98, probability + 0.10)
    verdict, confidence = _verdict_from_probability(probability)

    detail = _finalize_detection_detail(
        _build_detail(verdict, reasons, probability),
        verdict,
        probability,
    )
    exif_metadata = extract_exif_metadata(content, file_name)

    return {
        "verdict": verdict,
        "confidence": round(confidence, 3),
        "probability": round(probability, 3),
        "detail": detail,
        "signals": {k: round(v, 3) for k, v in signals.items()},
        "exif_metadata": exif_metadata,
    }


def _video_provenance_exif_panel(provenance: "CameraProvenanceResult", file_name: str) -> dict[str, Any]:
    from app.services.camera_provenance import CameraProvenanceResult

    assert isinstance(provenance, CameraProvenanceResult)
    fields = list(provenance.safe_fields)
    return {
        "has_exif": bool(fields),
        "is_video": True,
        "format": "video_container",
        "field_count": len(fields),
        "fields": fields,
        "flags": [
            {
                "code": "video_container_provenance",
                "label": f"Container provenance: {provenance.strength}.",
                "severity": "info",
            }
        ],
        "summary": "; ".join(provenance.reasons[:3]) if provenance.reasons else "Video container metadata.",
        "camera_provenance_strength": provenance.strength,
        "camera_provenance_reasons": list(provenance.reasons),
    }


def detect_ai_generated_from_frames(
    frame_bytes_list: list[bytes],
    *,
    file_name: str = "",
    video_content: bytes | None = None,
    video_ext: str = ".mp4",
) -> dict[str, Any]:
    """Scan multiple video frames and keep the strongest synthetic-media signal."""
    from app.services.camera_provenance import classify_video_container_provenance
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    video_provenance = None
    if video_content:
        video_provenance = classify_video_container_provenance(
            video_content, video_ext, file_name=file_name
        )

    if not frame_bytes_list:
        return detect_ai_generated(b"", file_name=file_name)

    frame_policy = not (active_ai_detector_backend() == "probe" and video_provenance is not None)

    if len(frame_bytes_list) == 1:
        out = detect_ai_generated(
            frame_bytes_list[0],
            file_name=file_name,
            apply_provenance_policy=frame_policy,
        )
        if video_provenance is not None and active_ai_detector_backend() == "probe":
            out = apply_probe_provenance_policy(out, video_provenance, file_name=file_name)
            out["exif_metadata"] = _video_provenance_exif_panel(video_provenance, file_name)
        return out

    indices = _frame_sample_indices(len(frame_bytes_list), max_samples=5)
    sampled = [frame_bytes_list[i] for i in indices]
    results = [
        detect_ai_generated(frame, file_name=file_name, apply_provenance_policy=frame_policy)
        for frame in sampled
    ]

    if active_ai_detector_backend() == "probe":
        best = max(
            results,
            key=lambda r: float(r.get("raw_detector_probability", r.get("probability", 0)) or 0),
        )
        out = dict(best)
        out["frames_scanned"] = len(sampled)
        if video_provenance is not None:
            out = apply_probe_provenance_policy(out, video_provenance, file_name=file_name)
            out["exif_metadata"] = _video_provenance_exif_panel(video_provenance, file_name)
        return out

    best = max(results, key=lambda r: float(r.get("probability", 0)))

    suspicious_count = sum(
        1 for r in results if float(r.get("probability", 0)) >= SUSPICIOUS_THRESHOLD
    )
    prob = float(best.get("probability", 0))
    if suspicious_count >= 2 and prob < SUSPICIOUS_THRESHOLD:
        prob = min(0.98, prob + 0.10 * (suspicious_count - 1))
    elif suspicious_count >= 2 and best.get("verdict") == "suspicious":
        prob = min(0.98, prob + 0.06)

    verdict, confidence = _verdict_from_probability(prob)
    # Use the strongest frame's supplemental copy (avoid duplicating boilerplate across frames).
    supplement = _strip_detail_boilerplate(str(best.get("detail", "")))
    detail = _finalize_detection_detail(
        _build_detail(verdict, [supplement] if supplement else [], prob),
        verdict,
        prob,
    )

    merged_signals: dict[str, float] = {}
    for r in results:
        for key, val in (r.get("signals") or {}).items():
            merged_signals[key] = max(float(merged_signals.get(key, 0)), float(val))

    exif = best.get("exif_metadata")
    if not isinstance(exif, dict):
        exif = extract_exif_metadata(b"", file_name)

    return {
        "verdict": verdict,
        "confidence": round(confidence, 3),
        "probability": round(prob, 3),
        "detail": detail,
        "signals": {k: round(v, 3) for k, v in merged_signals.items()},
        "exif_metadata": exif,
        "frames_scanned": len(sampled),
    }


def _frame_sample_indices(total: int, *, max_samples: int = 5) -> list[int]:
    if total <= max_samples:
        return list(range(total))
    step = (total - 1) / (max_samples - 1)
    return sorted({int(round(i * step)) for i in range(max_samples)})


def _filename_ai_hint_score(file_name: str) -> tuple[float, str]:
    name_lower = (file_name or "").lower()
    for hint in _AI_SOFTWARE_HINTS:
        if hint in name_lower:
            return 0.85, f"File name suggests AI tooling ({hint})."
    return 0.0, ""


def _fuse_probability(signals: dict[str, float], meta_score: float) -> float:
    weights = {
        "frequency": 0.18,
        "noise_uniformity": 0.16,
        "texture_entropy": 0.12,
        "quality_paradox": 0.18,
        "skin_smoothness": 0.16,
        "neural": 0.28,
    }
    total_w = 0.0
    acc = 0.0
    for key, weight in weights.items():
        if key in signals:
            acc += signals[key] * weight
            total_w += weight
    if meta_score > 0:
        acc += meta_score * 0.28
        total_w += 0.28
    if "filename" in signals:
        acc += signals["filename"] * 0.30
        total_w += 0.30
    if "neural_authentic" in signals:
        acc -= signals["neural_authentic"] * 0.12
        total_w += 0.12
    if total_w <= 0:
        return 0.12
    return float(np.clip(acc / total_w, 0.0, 0.98))


def _verdict_from_probability(probability: float) -> tuple[str, float]:
    if probability >= AI_GENERATED_THRESHOLD:
        return "ai_generated", probability
    if probability >= SUSPICIOUS_THRESHOLD:
        return "suspicious", probability
    return "authentic", 1.0 - probability


_DETAIL_BOILERPLATE_RE = re.compile(
    r"^(?:No strong AI-generation indicators detected\.|"
    r"Likely AI-generated media \(\d+% synthetic probability\)\.|"
    r"Possible AI-generated or heavily edited media \(\d+% synthetic probability\)\.)\s*",
    re.IGNORECASE,
)


def _strip_detail_boilerplate(detail: str, base: str = "") -> str:
    """Remove verdict boilerplate when merging frame-level detail strings."""
    part = detail.strip()
    if not part:
        return ""
    part = _DETAIL_BOILERPLATE_RE.sub("", part, count=1).strip()
    if base and part.startswith(base):
        part = part[len(base) :].strip()
    return part


def _detail_base(verdict: str, probability: float) -> str:
    pct = int(probability * 100)
    if verdict == "ai_generated":
        return f"Likely AI-generated media ({pct}% synthetic probability)."
    if verdict == "suspicious":
        return f"Possible AI-generated or heavily edited media ({pct}% synthetic probability)."
    return "No strong AI-generation indicators detected."


def _unique_detail_clauses(text: str) -> list[str]:
    """Split supplemental copy into sentences and drop exact duplicates."""
    clauses: list[str] = []
    chunk = text.strip()
    if not chunk:
        return clauses
    for piece in re.split(r"(?<=\.)\s+", chunk):
        piece = piece.strip()
        if not piece:
            continue
        if not piece.endswith("."):
            piece = f"{piece}."
        if piece not in clauses:
            clauses.append(piece)
    return clauses


def _build_detail(verdict: str, reasons: list[str], probability: float) -> str:
    base = _detail_base(verdict, probability)

    clauses: list[str] = []
    for raw in reasons:
        part = _strip_detail_boilerplate(raw, base)
        for clause in _unique_detail_clauses(part):
            if clause not in clauses:
                clauses.append(clause)
    if clauses:
        return f"{base} {' '.join(clauses[:2])}"
    return base


def _finalize_detection_detail(detail: str, verdict: str, probability: float) -> str:
    """Last pass for photo + video: never ship duplicated verdict boilerplate."""
    base = _detail_base(verdict, probability)
    supplement = _strip_detail_boilerplate(detail.strip(), base)
    while True:
        nxt = _strip_detail_boilerplate(supplement, base)
        if nxt == supplement:
            break
        supplement = nxt
    clauses = _unique_detail_clauses(supplement)
    joined = " ".join(clauses[:2])
    return _build_detail(verdict, [joined] if joined else [], probability)


def _authentic_fallback(detail: str) -> dict[str, Any]:
    return {
        "verdict": "authentic",
        "confidence": 0.85,
        "probability": 0.1,
        "detail": detail,
        "signals": {},
    }


_EXIF_LABELS: dict[str, str] = {
    "Make": "Camera make",
    "Model": "Camera model",
    "Software": "Software",
    "DateTimeOriginal": "Date taken",
    "DateTime": "File date",
    "DateTimeDigitized": "Digitized",
    "Orientation": "Orientation",
    "LensModel": "Lens",
    "ExposureTime": "Exposure",
    "FNumber": "Aperture",
    "ISOSpeedRatings": "ISO",
    "FocalLength": "Focal length",
    "Flash": "Flash",
    "WhiteBalance": "White balance",
    "ColorSpace": "Color space",
    "ImageWidth": "Width",
    "ImageHeight": "Height",
    "Artist": "Artist",
    "Copyright": "Copyright",
    "GPSInfo": "GPS",
}

_EXIF_DISPLAY_ORDER = (
    "Make",
    "Model",
    "Software",
    "DateTimeOriginal",
    "DateTime",
    "DateTimeDigitized",
    "Orientation",
    "LensModel",
    "ExposureTime",
    "FNumber",
    "ISOSpeedRatings",
    "FocalLength",
    "Flash",
    "WhiteBalance",
    "ColorSpace",
    "ImageWidth",
    "ImageHeight",
    "GPSInfo",
    "Artist",
    "Copyright",
)

_ORIENTATION_LABELS = {
    1: "Normal",
    2: "Mirrored horizontal",
    3: "Rotated 180°",
    4: "Mirrored vertical",
    5: "Mirrored horizontal, rotated 270° CW",
    6: "Rotated 90° CW",
    7: "Mirrored horizontal, rotated 90° CW",
    8: "Rotated 270° CW",
}


def _format_exif_value(key: str, value: Any) -> str:
    if value is None:
        return ""
    if key == "GPSInfo":
        return "Embedded GPS coordinates"
    if key == "Orientation":
        try:
            return _ORIENTATION_LABELS.get(int(value), str(value))
        except (TypeError, ValueError):
            return str(value)
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace").strip()
        except Exception:
            return "—"
    text = str(value).strip()
    return text if text else "—"


def extract_exif_metadata(content: bytes, file_name: str = "") -> dict[str, Any]:
    """Structured EXIF payload for admin integrity review."""
    from app.services.media_file_bytes import is_video_file_name

    flags: list[dict[str, str]] = []
    fields: list[dict[str, str]] = []

    if is_video_file_name(file_name):
        fn_score, fn_reason = _filename_ai_hint_score(file_name)
        if fn_score > 0 and fn_reason:
            flags.append(
                {
                    "code": "ai_hint_filename",
                    "label": fn_reason,
                    "severity": "danger",
                }
            )
        flags.append(
            {
                "code": "video_limited_exif",
                "label": "Video files usually have limited camera EXIF. Rely on visual inspection.",
                "severity": "info",
            }
        )
        summary = "Video upload — limited EXIF metadata available."
        if fn_score > 0:
            summary = f"{summary} {fn_reason}"
        return {
            "has_exif": False,
            "is_video": True,
            "format": None,
            "field_count": 0,
            "fields": [],
            "flags": flags,
            "summary": summary,
        }

    fn_score, fn_reason = _filename_ai_hint_score(file_name)
    if fn_score > 0 and fn_reason:
        flags.append(
            {
                "code": "ai_hint_filename",
                "label": fn_reason,
                "severity": "danger",
            }
        )

    if not content or Image is None:
        summary = "Could not read file metadata."
        if not content:
            summary = "Empty file — no metadata."
        return {
            "has_exif": False,
            "is_video": False,
            "format": None,
            "field_count": 0,
            "fields": [],
            "flags": flags,
            "summary": summary,
        }

    img_format: str | None = None
    decoded: dict[str, Any] = {}

    try:
        img = Image.open(BytesIO(content))
        img_format = img.format
        exif = img.getexif()
        if exif:
            decoded = {TAGS.get(k, str(k)): v for k, v in exif.items()}
    except Exception:
        return {
            "has_exif": False,
            "is_video": False,
            "format": img_format,
            "field_count": 0,
            "fields": [],
            "flags": flags,
            "summary": "Could not parse image metadata.",
        }

    if not decoded:
        if img_format in ("PNG", "WEBP"):
            flags.append(
                {
                    "code": "png_webp_no_exif",
                    "label": "PNG/WebP without camera EXIF metadata.",
                    "severity": "warning",
                }
            )
        elif img_format == "JPEG":
            flags.append(
                {
                    "code": "jpeg_no_exif",
                    "label": "JPEG without camera EXIF metadata (typical of AI exports).",
                    "severity": "warning",
                }
            )
        else:
            flags.append(
                {
                    "code": "no_exif",
                    "label": "No EXIF metadata found in this file.",
                    "severity": "warning",
                }
            )
        return {
            "has_exif": False,
            "is_video": False,
            "format": img_format,
            "field_count": 0,
            "fields": [],
            "flags": flags,
            "summary": flags[-1]["label"] if flags else "No EXIF metadata found.",
        }

    software = str(decoded.get("Software", "")).lower()
    model = str(decoded.get("Model", "")).strip()
    make = str(decoded.get("Make", "")).strip()

    for hint in _AI_SOFTWARE_HINTS:
        if hint in software:
            flags.append(
                {
                    "code": "ai_software_exif",
                    "label": f"EXIF software tag indicates AI generation ({decoded.get('Software', '')}).",
                    "severity": "danger",
                }
            )
            break

    if not make and not model and img_format == "JPEG":
        flags.append(
            {
                "code": "missing_camera_make_model",
                "label": "JPEG lacks typical camera make/model EXIF.",
                "severity": "warning",
            }
        )
    elif make or model:
        camera = " ".join(part for part in (make, model) if part).strip()
        flags.append(
            {
                "code": "camera_metadata_present",
                "label": f"Camera metadata present ({camera}).",
                "severity": "info",
            }
        )

    seen: set[str] = set()
    for key in _EXIF_DISPLAY_ORDER:
        if key not in decoded or key in seen:
            continue
        value = _format_exif_value(key, decoded[key])
        if not value or value == "—":
            continue
        fields.append(
            {
                "key": key,
                "label": _EXIF_LABELS.get(key, key),
                "value": value,
            }
        )
        seen.add(key)

    for key, raw in decoded.items():
        if key in seen or key == "ExifOffset":
            continue
        value = _format_exif_value(key, raw)
        if not value or value == "—":
            continue
        fields.append({"key": key, "label": _EXIF_LABELS.get(key, key), "value": value})

    summary_parts: list[str] = []
    if make or model:
        summary_parts.append(f"Camera: {' '.join(p for p in (make, model) if p)}")
    software_display = str(decoded.get("Software", "")).strip()
    if software_display:
        summary_parts.append(f"Software: {software_display}")
    elif not make and not model:
        summary_parts.append("No camera make/model in EXIF")

    return {
        "has_exif": True,
        "is_video": False,
        "format": img_format,
        "field_count": len(fields),
        "fields": fields,
        "flags": flags,
        "summary": " · ".join(summary_parts) if summary_parts else "EXIF metadata present.",
    }


def _metadata_score(content: bytes, file_name: str) -> tuple[float, str]:
    score = 0.0
    reason = ""

    meta = extract_exif_metadata(content, file_name)
    for flag in meta.get("flags") or []:
        code = flag.get("code", "")
        label = flag.get("label", "")
        if code == "ai_hint_filename":
            score = max(score, 0.85)
            reason = label
        elif code == "ai_software_exif":
            score = max(score, 0.9)
            reason = label
        elif code == "png_webp_no_exif" and score < 0.4:
            score = max(score, 0.35)
            if not reason:
                reason = label
        elif code == "jpeg_no_exif" and score < 0.45:
            score = max(score, 0.42)
            if not reason:
                reason = label
        elif code == "missing_camera_make_model" and score < 0.32:
            score = max(score, 0.32)
            if not reason:
                reason = label

    return score, reason


def _frequency_anomaly_score(bgr: np.ndarray) -> float:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (256, 256), interpolation=cv2.INTER_AREA)
    f = np.fft.fftshift(np.fft.fft2(gray.astype(np.float32)))
    mag = np.log1p(np.abs(f))

    h, w = mag.shape
    cy, cx = h // 2, w // 2
    y, x = np.ogrid[:h, :w]
    dist = np.sqrt((y - cy) ** 2 + (x - cx) ** 2)
    inner = dist < min(h, w) * 0.12
    outer = dist > min(h, w) * 0.35

    low_energy = float(mag[inner].mean()) + 1e-6
    high_energy = float(mag[outer].mean())
    ratio = high_energy / low_energy

    # Synthetic images often have compressed high-frequency roll-off OR abnormal spikes.
    if ratio < 0.08:
        return 0.72
    if ratio < 0.14:
        return 0.52
    if ratio > 0.55:
        return 0.48
    return 0.22


def _noise_uniformity_score(bgr: np.ndarray) -> float:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    block = 32
    stds: list[float] = []
    for y in range(0, h - block, block):
        for x in range(0, w - block, block):
            patch = gray[y : y + block, x : x + block].astype(np.float32)
            blurred = cv2.GaussianBlur(patch, (3, 3), 0)
            stds.append(float(np.std(patch - blurred)))

    if len(stds) < 4:
        return 0.2

    std_arr = np.array(stds)
    mean = float(std_arr.mean()) + 1e-6
    cv = float(std_arr.std() / mean)

    # Very low residual sensor noise — common in AI upscales and diffusion output.
    if mean < 1.5:
        return 0.58
    if mean < 2.0 and cv < 0.55:
        return 0.48
    if mean < 2.2 and cv < 0.32:
        return 0.62
    if mean < 3.5 and cv < 0.40:
        return 0.38
    return 0.15


def _texture_entropy_score(bgr: np.ndarray) -> float:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (192, 192), interpolation=cv2.INTER_AREA)
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    mag = cv2.magnitude(gx, gy)
    hist = cv2.calcHist([mag.astype(np.uint8)], [0], None, [32], [0, 256])
    hist = hist.flatten().astype(np.float64)
    hist /= hist.sum() + 1e-9
    entropy = float(-np.sum(hist * np.log2(hist + 1e-12)))

    # Over-smoothed AI textures cluster in mid gradients.
    if entropy < 2.4:
        return 0.68
    if entropy < 2.9:
        return 0.45
    return 0.2


def _quality_paradox_score(bgr: np.ndarray) -> float:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    residual_std = float(np.std(cv2.absdiff(gray, blurred)))

    sharp = lap_var > 180.0
    clean = residual_std < 4.5
    if sharp and clean:
        return 0.74
    if lap_var > 120.0 and residual_std < 6.0:
        return 0.52
    # Polished AI portraits: subject detail with almost no sensor grain.
    if lap_var > 30.0 and residual_std < 2.5:
        return 0.62
    if lap_var > 25.0 and residual_std < 3.2:
        return 0.48
    return 0.15


def _skin_smoothness_score(bgr: np.ndarray) -> float:
    """Detect unnaturally smooth mid-tone regions vs sharp edges (common in AI portraits)."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    block = max(24, min(h, w) // 16)

    edge_mag = cv2.magnitude(
        cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3),
        cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3),
    )
    edge_thresh = float(np.percentile(edge_mag, 72))

    smooth_patches = 0
    textured_patches = 0
    total = 0
    for y in range(0, h - block, block):
        for x in range(0, w - block, block):
            patch_edge = edge_mag[y : y + block, x : x + block]
            mean_edge = float(patch_edge.mean())
            if mean_edge >= edge_thresh:
                continue
            patch = gray[y : y + block, x : x + block].astype(np.float32)
            local_std = float(np.std(patch))
            total += 1
            if local_std < 8.5:
                smooth_patches += 1
            elif local_std > 14.0:
                textured_patches += 1

    if total < 6:
        return 0.2

    smooth_ratio = smooth_patches / total
    if smooth_ratio >= 0.62 and textured_patches <= 1:
        return 0.72
    if smooth_ratio >= 0.48:
        return 0.55
    if smooth_ratio >= 0.35:
        return 0.38
    return 0.18
