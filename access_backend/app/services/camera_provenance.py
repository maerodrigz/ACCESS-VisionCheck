"""Camera / container provenance classification (supporting signal, not AI verdict)."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Any

try:
    from PIL import Image
    from PIL.ExifTags import TAGS
except ImportError:  # pragma: no cover
    Image = None  # type: ignore
    TAGS = {}  # type: ignore

from app.services.ai_authenticity_detector import _AI_SOFTWARE_HINTS, _filename_ai_hint_score

_STRENGTH_STRONG = "strong"
_STRENGTH_PARTIAL = "partial"
_STRENGTH_ABSENT = "absent"

_GPS_KEY_SUBSTR = ("gps", "location", "latitude", "longitude")


@dataclass
class CameraProvenanceResult:
    strength: str
    reasons: list[str] = field(default_factory=list)
    safe_fields: list[dict[str, str]] = field(default_factory=list)
    is_video: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "camera_provenance_strength": self.strength,
            "camera_provenance_reasons": list(self.reasons),
            "camera_provenance_fields": list(self.safe_fields),
            "is_video_provenance": self.is_video,
        }


def _clean_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace").strip()
        except Exception:
            return ""
    return str(value).strip()


def _is_gps_key(key: str) -> bool:
    lower = key.lower()
    return any(part in lower for part in _GPS_KEY_SUBSTR)


def _camera_like_software(software: str) -> bool:
    s = software.lower()
    if not s:
        return False
    for hint in _AI_SOFTWARE_HINTS:
        if hint in s:
            return False
    camera_hints = (
        "ios",
        "android",
        "camera",
        "iphone",
        "pixel",
        "samsung",
        "huawei",
        "oppo",
        "vivo",
        "oneplus",
        "nikon",
        "canon",
        "sony",
        "fujifilm",
        "olympus",
        "panasonic",
        "gopro",
        "dji",
    )
    return any(h in s for h in camera_hints)


def _coherent_phone_filename(file_name: str) -> bool:
    base = Path(file_name or "").name
    if re.match(r"^IMG_\d{4,}\.(jpe?g|heic)$", base, re.I):
        return True
    if re.match(r"^PXL_\d{8}_\d{6,}\.(jpe?g|heic)$", base, re.I):
        return True
    if re.match(r"^VID_\d{4,}\.(mp4|mov)$", base, re.I):
        return True
    return False


def looks_like_reexported_media_filename(file_name: str) -> bool:
    """Gallery saves, downloads, and screen captures (not canonical camera names)."""
    if _coherent_phone_filename(file_name):
        return False
    stem = Path(file_name or "").stem.strip()
    if not stem:
        return False
    if re.fullmatch(r"\d{6,}", stem):
        return True
    if re.match(
        r"^(video|download|screen_?record|screenrecording|mvimg|snapchat|tiktok|"
        r"image|images|photo|pics?|picture|saved|copy|screenshot|screen|thumb|blob|temp)",
        stem,
        re.I,
    ):
        return True
    if re.search(r"\(\d+\)$", stem):
        return True
    lower = stem.lower()
    for hint in (
        "whatsapp",
        "telegram",
        "facebook",
        "instagram",
        "pinterest",
        "twitter",
        "reddit",
        "messenger",
        "viber",
        "chrome",
        "browser",
    ):
        if hint in lower:
            return True
    return False


_RESAVE_SOFTWARE_HINTS = (
    "google photos",
    "snapseed",
    "instagram",
    "facebook",
    "whatsapp",
    "telegram",
    "pinterest",
    "canva",
    "photoshop",
    "lightroom",
    "gimp",
    "paint",
    "microsoft",
    "windows photo",
    "gallery",
    "share",
    "save",
)


def _safe_field_values(provenance: CameraProvenanceResult, key: str) -> str:
    for row in provenance.safe_fields:
        if (row.get("key") or row.get("label")) == key:
            return _clean_text(row.get("value"))
    return ""


def photo_has_credible_in_camera_identity(provenance: CameraProvenanceResult, *, file_name: str = "") -> bool:
    """True when partial/strong tags look like an original camera capture, not a bare download."""
    if provenance.is_video:
        return provenance.strength == "strong"
    make = _safe_field_values(provenance, "Make")
    model = _safe_field_values(provenance, "Model")
    if make and model:
        return True
    if _coherent_phone_filename(file_name) and (make or model):
        return True
    return provenance.strength == "strong"


def photo_likely_download_or_resave(
    *,
    file_name: str,
    provenance: CameraProvenanceResult,
    exif_metadata: dict[str, Any] | None,
) -> bool:
    """Downloads, gallery re-saves, and stripped metadata should not auto-clear on low PROBE risk."""
    if provenance.is_video:
        return False
    if looks_like_reexported_media_filename(file_name):
        return True
    if provenance.strength == "absent":
        return True

    credible = photo_has_credible_in_camera_identity(provenance, file_name=file_name)

    flags = (exif_metadata or {}).get("flags") or []
    flag_codes = {
        str(f.get("code"))
        for f in flags
        if isinstance(f, dict) and f.get("code")
    }
    if not credible and flag_codes & {"jpeg_no_exif", "png_webp_no_exif", "no_exif", "missing_camera_make_model"}:
        return True

    software = ""
    for row in (exif_metadata or {}).get("fields") or []:
        if isinstance(row, dict) and row.get("key") == "Software":
            software = _clean_text(row.get("value")).lower()
            break
    if software and any(h in software for h in _RESAVE_SOFTWARE_HINTS):
        return True

    if provenance.strength == "partial" and not credible:
        return True
    return False


def video_provenance_has_device_identity(safe_fields: list[dict[str, str]]) -> bool:
    """True when container metadata includes a camera/device make or model."""
    for row in safe_fields:
        key = (row.get("key") or row.get("label") or "").strip().lower()
        if not key:
            continue
        if key in ("make", "model", "com.android.manufacturer", "com.android.model"):
            return True
        if "manufacturer" in key or key.endswith(".model"):
            return True
    return False


def classify_photo_camera_provenance(content: bytes, file_name: str = "") -> CameraProvenanceResult:
    """Classify original photo bytes: strong / partial / absent."""
    reasons: list[str] = []
    safe_fields: list[dict[str, str]] = []
    decoded: dict[str, Any] = {}

    if Image is None or not content:
        reasons.append("Could not read image bytes for provenance.")
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons)

    try:
        img = Image.open(BytesIO(content))
        exif = img.getexif()
        if exif:
            decoded = {TAGS.get(k, str(k)): v for k, v in exif.items()}
    except Exception:
        reasons.append("Image metadata could not be parsed.")
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons)

    if not decoded:
        reasons.append("No EXIF metadata in original upload.")
        if _coherent_phone_filename(file_name):
            reasons.append("Filename suggests a camera capture but EXIF is missing.")
            return CameraProvenanceResult(_STRENGTH_PARTIAL, reasons=reasons)
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons)

    make = _clean_text(decoded.get("Make"))
    model = _clean_text(decoded.get("Model"))
    software = _clean_text(decoded.get("Software"))
    dt_orig = _clean_text(decoded.get("DateTimeOriginal") or decoded.get("DateTime"))
    lens = _clean_text(decoded.get("LensModel") or decoded.get("LensMake"))

    for key, raw in decoded.items():
        if _is_gps_key(key):
            continue
        val = _clean_text(raw)
        if not val or val == "—":
            continue
        if key in ("Make", "Model", "Software", "DateTime", "DateTimeOriginal", "LensModel", "LensMake"):
            safe_fields.append({"key": key, "label": key, "value": val})

    ai_software = software and any(h in software.lower() for h in _AI_SOFTWARE_HINTS)
    if ai_software:
        reasons.append("Software tag suggests AI tooling (visual review still applies).")

    has_make_model = bool(make and model)
    has_capture_time = bool(dt_orig)
    has_lens = bool(lens)
    has_camera_software = _camera_like_software(software)

    if has_make_model and (has_capture_time or has_lens or has_camera_software) and not ai_software:
        reasons.append(f"Camera make/model present ({make} {model}).".strip())
        if has_capture_time:
            reasons.append("Capture timestamp present in EXIF.")
        if has_lens:
            reasons.append("Lens metadata present.")
        if has_camera_software:
            reasons.append("Device/camera software tag present.")
        return CameraProvenanceResult(_STRENGTH_STRONG, reasons=reasons, safe_fields=safe_fields)

    partial_signals = 0
    if make or model:
        partial_signals += 1
        reasons.append(f"Partial camera tag: {make or model}.")
    if has_capture_time:
        partial_signals += 1
        reasons.append("Capture timestamp present without full camera identity.")
    if has_lens:
        partial_signals += 1
        reasons.append("Lens metadata without full make/model pair.")
    if _coherent_phone_filename(file_name):
        partial_signals += 1
        reasons.append("Camera-style filename without full EXIF coherence.")

    if partial_signals >= 1:
        return CameraProvenanceResult(_STRENGTH_PARTIAL, reasons=reasons, safe_fields=safe_fields)

    if len(decoded) <= 2:
        reasons.append("Only minimal EXIF tags present (not credible camera provenance).")
    else:
        reasons.append("EXIF present but no credible camera-origin combination.")
    return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, safe_fields=safe_fields)


def classify_video_container_provenance(
    content: bytes,
    ext: str = ".mp4",
    file_name: str = "",
) -> CameraProvenanceResult:
    """Inspect original video container via ffprobe (before frame extraction)."""
    reasons: list[str] = []
    safe_fields: list[dict[str, str]] = []

    if not content:
        reasons.append("Empty video upload.")
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, is_video=True)

    if not shutil.which("ffprobe"):
        reasons.append("ffprobe unavailable; container provenance not assessed.")
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, is_video=True)

    ext = ext if ext.startswith(".") else f".{ext}"
    tags: dict[str, str] = {}
    encoder = ""
    try:
        with tempfile.TemporaryDirectory(prefix="access_prov_") as tmp:
            video_path = Path(tmp) / f"input{ext}"
            video_path.write_bytes(content)
            cmd = [
                "ffprobe",
                "-v",
                "quiet",
                "-print_format",
                "json",
                "-show_format",
                "-show_streams",
                str(video_path),
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            if result.returncode != 0 or not result.stdout.strip():
                reasons.append("Could not read video container metadata.")
                return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, is_video=True)
            data = json.loads(result.stdout)
    except (json.JSONDecodeError, subprocess.SubprocessError, OSError):
        reasons.append("Video container metadata parse failed.")
        return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, is_video=True)

    fmt = data.get("format") if isinstance(data.get("format"), dict) else {}
    fmt_tags = fmt.get("tags") if isinstance(fmt.get("tags"), dict) else {}
    for k, v in fmt_tags.items():
        key = _clean_text(k)
        val = _clean_text(v)
        if not key or not val or _is_gps_key(key):
            continue
        tags[key.lower()] = val
        safe_fields.append({"key": key, "label": key, "value": val})

    streams = data.get("streams") if isinstance(data.get("streams"), list) else []
    for stream in streams:
        if not isinstance(stream, dict):
            continue
        encoder = _clean_text(stream.get("codec_name")) or encoder
        st_tags = stream.get("tags") if isinstance(stream.get("tags"), dict) else {}
        for k, v in st_tags.items():
            key = _clean_text(k)
            val = _clean_text(v)
            if not key or not val or _is_gps_key(key):
                continue
            tags[key.lower()] = val

    creation = tags.get("creation_time") or tags.get("com.apple.quicktime.creationdate")
    make = tags.get("make") or tags.get("com.android.manufacturer")
    model = tags.get("model") or tags.get("com.android.model")
    handler = tags.get("handler_name") or tags.get("encoder")

    mobile_hint = any(
        x in (handler or "").lower()
        for x in ("android", "iphone", "apple", "quicktime", "video handler")
    ) or any(x in (encoder or "").lower() for x in ("h264", "hevc", "avc1"))

    if creation and (make or model):
        reasons.append("Container reports device make/model and creation time.")
        return CameraProvenanceResult(_STRENGTH_STRONG, reasons=reasons, safe_fields=safe_fields, is_video=True)

    if creation and mobile_hint:
        reasons.append("Container creation time with mobile/video encoder hints (no device make/model).")
        return CameraProvenanceResult(_STRENGTH_PARTIAL, reasons=reasons, safe_fields=safe_fields, is_video=True)

    if creation or make or model or mobile_hint:
        if creation:
            reasons.append("Container creation timestamp without full device identity.")
        if make or model:
            reasons.append("Partial device tag in container metadata.")
        if mobile_hint:
            reasons.append("Encoder/container hints without full device metadata.")
        return CameraProvenanceResult(_STRENGTH_PARTIAL, reasons=reasons, safe_fields=safe_fields, is_video=True)

    if _coherent_phone_filename(file_name):
        reasons.append("Camera-style video filename without container device metadata.")
        return CameraProvenanceResult(_STRENGTH_PARTIAL, reasons=reasons, safe_fields=safe_fields, is_video=True)

    fn_score, fn_reason = _filename_ai_hint_score(file_name)
    reasons.append("No credible original camera/container provenance in video file.")
    if fn_score > 0 and fn_reason:
        reasons.append(fn_reason)
    return CameraProvenanceResult(_STRENGTH_ABSENT, reasons=reasons, safe_fields=safe_fields, is_video=True)
