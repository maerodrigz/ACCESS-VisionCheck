"""Map external dataset scales to 1–5 for machine comparison; preserve raw separately."""

from __future__ import annotations

import math
from typing import Any


def parse_optional_float(val: Any) -> float | None:
    if val is None:
        return None
    if isinstance(val, float) and math.isnan(val):
        return None
    s = str(val).strip()
    if s.upper() in ("", "NA", "N/A", "NULL", "NONE", "-"):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def validate_raw_in_scale(raw: float, scale: str) -> bool:
    """Return False if raw is outside the declared scale (caller may skip or error)."""
    scale = (scale or "").strip()
    if scale in ("0-100", "0_100", "0..100"):
        return 0.0 <= raw <= 100.0
    if scale in ("1-5", "1_5", "1..5"):
        return 1.0 <= raw <= 5.0
    return True


def map_linear_to_1_5(raw: float | None, *, raw_min: float = 0.0, raw_max: float = 100.0) -> float | None:
    if raw is None:
        return None
    if raw_max <= raw_min:
        return None
    x = max(raw_min, min(raw_max, float(raw)))
    t = (x - raw_min) / (raw_max - raw_min)
    return round(1.0 + 4.0 * t, 4)


def map_mos_to_1_5(raw: float | None, mos_scale: str) -> float | None:
    if raw is None:
        return None
    scale = (mos_scale or "0-100").strip().lower()
    if scale in ("1-5", "1_5"):
        return round(float(raw), 4) if 1.0 <= raw <= 5.0 else None
    return map_linear_to_1_5(raw, raw_min=0.0, raw_max=100.0)


def map_noisiness_raw_to_noise_quality_1_5(raw: float | None, attribute_scale: str = "0-100") -> float | None:
    """
    SPAQ noisiness: higher = more noise (worse).
    ACCESS Noise criterion: higher 1–5 = less noise (better).
    Invert on the raw scale before mapping to 1–5.
    """
    if raw is None:
        return None
    scale = (attribute_scale or "0-100").strip().lower()
    if scale in ("1-5", "1_5"):
        inverted = 6.0 - float(raw)
        return round(inverted, 4) if 1.0 <= inverted <= 5.0 else None
    inverted = 100.0 - float(raw)
    return map_linear_to_1_5(inverted, raw_min=0.0, raw_max=100.0)


def apply_derived_mapped_columns(row: dict[str, Any]) -> dict[str, Any]:
    """Fill *_mapped_1_5 from raw fields; leave missing as empty. Does not mutate unavailable attrs."""
    mos_scale = str(row.get("mos_scale") or "0-100")
    attr_scale = str(row.get("attribute_scale") or mos_scale)

    missing: list[str] = []
    for attr in (
        "mos_quality_raw",
        "attr_sharpness_raw",
        "attr_brightness_raw",
        "attr_noisiness_raw",
        "attr_contrast_raw",
        "attr_colorfulness_raw",
    ):
        if parse_optional_float(row.get(attr)) is None:
            missing.append(attr.replace("attr_", "").replace("mos_quality", "mos"))

    row["missing_dimensions"] = "|".join(missing) if missing else ""

    mos = parse_optional_float(row.get("mos_quality_raw"))
    row["overall_documentation_mapped_1_5"] = _fmt(map_mos_to_1_5(mos, mos_scale))

    sharp = parse_optional_float(row.get("attr_sharpness_raw"))
    row["sharpness_blur_mapped_1_5"] = _fmt(map_linear_to_1_5(sharp) if attr_scale.startswith("0") else map_mos_to_1_5(sharp, attr_scale))

    bright = parse_optional_float(row.get("attr_brightness_raw"))
    row["exposure_mapped_1_5"] = _fmt(map_linear_to_1_5(bright) if attr_scale.startswith("0") else map_mos_to_1_5(bright, attr_scale))

    noise = parse_optional_float(row.get("attr_noisiness_raw"))
    row["noise_quality_mapped_1_5"] = _fmt(map_noisiness_raw_to_noise_quality_1_5(noise, attr_scale))

    contrast = parse_optional_float(row.get("attr_contrast_raw"))
    row["contrast_quality_mapped_1_5"] = _fmt(map_linear_to_1_5(contrast) if attr_scale.startswith("0") else map_mos_to_1_5(contrast, attr_scale))

    color = parse_optional_float(row.get("attr_colorfulness_raw"))
    row["color_balance_mapped_1_5"] = _fmt(map_linear_to_1_5(color) if attr_scale.startswith("0") else map_mos_to_1_5(color, attr_scale))

    return row


def _fmt(v: float | None) -> str:
    return "" if v is None else str(v)
