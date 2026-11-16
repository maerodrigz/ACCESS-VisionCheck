"""Explainable diagnostics for the quality sandbox (research-only).

Computes *supplementary* measurements and plain-language explanations.
Does NOT alter criterion badges, quality_0_1 values, or detector thresholds.

EfficientNet-B0: only surfaces the model's continuous head outputs and the
production badge mapping. No fabricated internal-reasoning claims.

Classical: reuses scoring raw values from combined-v1 when present; adds
diagnostic-only stats from a single grayscale pass.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

from tools.quality_validation.experimental_quality_engine import RESIZE_CAP, _resize_longest

CRITERIA_NAMES = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)

_MEASURES_WHAT = {
    "Sharpness": (
        "How strong and crisp local edges appear (focus / fine detail energy)."
    ),
    "Blur": (
        "How free the image is from focus or motion blur, using Laplacian energy "
        "as a blur proxy (higher classical badge = less blur)."
    ),
    "Noise": (
        "Estimated residual grain in relatively homogeneous regions "
        "(higher classical badge = cleaner)."
    ),
    "Brightness": (
        "Overall exposure balance: mean luminance plus clipping of shadows/highlights."
    ),
    "Contrast": (
        "Global tonal separation (RMS luminance contrast), reduced when clipping is high."
    ),
    "Blocking Artifacts": (
        "Evidence of 8×8 JPEG lattice steps on flat neighboring tiles "
        "(higher classical badge = cleaner / less blocking)."
    ),
    "Ringing Artifacts": (
        "Edge overshoot / oscillation near strong edges "
        "(higher classical badge = cleaner / less ringing)."
    ),
}


def compute_supplementary_diagnostics(bgr: np.ndarray) -> dict[str, Any]:
    """Single-pass diagnostic measurements. Never used to recompute badges."""
    if cv2 is None:
        return {"available": False, "reason": "OpenCV not available"}
    if bgr is None or getattr(bgr, "size", 0) == 0:
        return {"available": False, "reason": "Empty image"}

    work = _resize_longest(bgr, RESIZE_CAP)
    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    gray_f = gray.astype(np.float64)
    h, w = gray.shape

    # Exposure / luminance distribution (diagnostic; shadow/highlight match v2 cutoffs)
    mean = float(np.mean(gray_f))
    std = float(np.std(gray_f))
    p5, p25, p50, p75, p95 = [float(x) for x in np.percentile(gray_f, [5, 25, 50, 75, 95])]
    shadow_clip = float(np.mean(gray_f < 8.0))
    highlight_clip = float(np.mean(gray_f > 247.0))
    dark_region = float(np.mean(gray_f < 64.0))
    bright_region = float(np.mean(gray_f > 192.0))

    # Edge / focus diagnostics
    gx = cv2.Sobel(gray_f, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray_f, cv2.CV_64F, 0, 1, ksize=3)
    grad_mag = np.sqrt(gx * gx + gy * gy)
    grad_mean = float(np.mean(grad_mag))
    edge_frac = float(np.mean(grad_mag > 30.0))
    strong_edge_frac = float(np.mean(grad_mag > 80.0))

    lap = cv2.Laplacian(gray, cv2.CV_64F)
    lap_var = float(np.var(lap))

    # Low-texture / dark residual noise probe (diagnostic only)
    blur = cv2.GaussianBlur(gray_f, (5, 5), 0)
    residual = gray_f - blur
    local_std = cv2.blur((residual * residual), (9, 9))
    local_std = np.sqrt(np.maximum(local_std, 0.0))
    low_tex = local_std < float(np.percentile(local_std, 30))
    dark = gray_f < 64.0
    dark_low = dark & low_tex
    noise_low_tex = float(np.std(residual[low_tex])) if np.any(low_tex) else None
    noise_dark_low = float(np.std(residual[dark_low])) if np.any(dark_low) else None
    dark_low_frac = float(np.mean(dark_low))

    return {
        "available": True,
        "resize_cap": RESIZE_CAP,
        "analysis_size": {"width": int(w), "height": int(h)},
        "luminance_mean_0_255": round(mean, 3),
        "luminance_mean_0_1": round(mean / 255.0, 4),
        "luminance_std": round(std, 3),
        "percentile_p5": round(p5, 2),
        "percentile_p25": round(p25, 2),
        "percentile_p50": round(p50, 2),
        "percentile_p75": round(p75, 2),
        "percentile_p95": round(p95, 2),
        "percentile_spread_p5_p95": round(p95 - p5, 2),
        "shadow_clip_frac": round(shadow_clip, 4),
        "highlight_clip_frac": round(highlight_clip, 4),
        "dark_region_frac": round(dark_region, 4),
        "bright_region_frac": round(bright_region, 4),
        "gradient_mean": round(grad_mean, 4),
        "edge_pixel_fraction": round(edge_frac, 4),
        "strong_edge_pixel_fraction": round(strong_edge_frac, 4),
        "laplacian_variance_diagnostic": round(lap_var, 4),
        "noise_residual_std_low_texture": (
            round(noise_low_tex, 4) if noise_low_tex is not None else None
        ),
        "noise_residual_std_dark_low_texture": (
            round(noise_dark_low, 4) if noise_dark_low is not None else None
        ),
        "dark_low_texture_fraction": round(dark_low_frac, 4),
    }


def build_criterion_explanations(
    *,
    engine_a: dict[str, Any] | None,
    engine_b: dict[str, Any] | None,
    diagnostics: dict[str, Any],
    combined_source: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Assemble per-criterion explanation blocks for the UI."""
    map_a = {c["name"]: c for c in (engine_a or {}).get("criteria") or []}
    map_b = {c["name"]: c for c in (engine_b or {}).get("criteria") or []}
    raw = {}
    if combined_source and isinstance(combined_source.get("raw"), dict):
        raw = combined_source["raw"]
    elif engine_b and isinstance(engine_b.get("raw_metrics"), dict):
        raw = engine_b["raw_metrics"]
    blocking = (combined_source or {}).get("blocking_v3") or {}
    ringing = (combined_source or {}).get("ringing_v3") or {}
    quality: dict[str, Any] = {}
    if combined_source and isinstance(combined_source.get("quality_0_1"), dict):
        quality = dict(combined_source["quality_0_1"])
    elif engine_b:
        key_map = {
            "Sharpness": "sharpness",
            "Blur": "blur",
            "Noise": "noise",
            "Brightness": "brightness",
            "Contrast": "contrast",
            "Blocking Artifacts": "blocking_artifacts",
            "Ringing Artifacts": "ringing_artifacts",
        }
        for c in engine_b.get("criteria") or []:
            key = key_map.get(c["name"])
            if key and c.get("quality_0_1") is not None:
                quality[key] = c["quality_0_1"]

    out: list[dict[str, Any]] = []
    for name in CRITERIA_NAMES:
        ca = map_a.get(name) or {}
        cb = map_b.get(name) or {}
        block = _explain_one(
            name=name,
            ca=ca,
            cb=cb,
            raw=raw,
            quality=quality,
            diagnostics=diagnostics,
            blocking=blocking,
            ringing=ringing,
            engine_a_available=bool((engine_a or {}).get("engine_available")),
            engine_b_available=bool((engine_b or {}).get("engine_available")),
        )
        out.append(block)
    return out


def _meas(
    key: str,
    value: Any,
    *,
    unit: str = "",
    role: str = "diagnostic_only",
    note: str | None = None,
) -> dict[str, Any] | None:
    if value is None:
        return None
    try:
        if isinstance(value, (float, np.floating)):
            value = round(float(value), 4)
        elif isinstance(value, (int, np.integer)):
            value = int(value)
    except (TypeError, ValueError):
        return None
    item = {"key": key, "value": value, "unit": unit, "role": role}
    if note:
        item["note"] = note
    return item


def _compact(items: list[dict[str, Any] | None]) -> list[dict[str, Any]]:
    return [x for x in items if x is not None]


def _pct(frac: float | None) -> str:
    if frac is None:
        return "unavailable"
    return f"{100.0 * float(frac):.1f}%"


def _explain_one(
    *,
    name: str,
    ca: dict[str, Any],
    cb: dict[str, Any],
    raw: dict[str, Any],
    quality: dict[str, Any],
    diagnostics: dict[str, Any],
    blocking: dict[str, Any],
    ringing: dict[str, Any],
    engine_a_available: bool,
    engine_b_available: bool,
) -> dict[str, Any]:
    diag_ok = bool(diagnostics.get("available"))

    enet = {
        "badge": ca.get("badge"),
        "badge_label": ca.get("badge_label"),
        "raw_model_output": ca.get("raw_value"),
        "raw_key": ca.get("raw_key"),
        "available": engine_a_available and ca.get("badge") is not None,
        "explanation": (
            "EfficientNet-B0 reports a continuous head value in [0, 1] for this "
            "criterion, then production `_soft_score` / `_brightness_metric` maps "
            "it to a 1–5 badge. The network's internal features are not "
            "inspectable here; this sandbox does not invent causal explanations "
            "for why the model produced that number."
        ),
        "limitation": (
            ca.get("limitation")
            or ca.get("warning")
            or (
                "Model estimate only. Soft-score mapping compresses the badge "
                "range (badge 1 is effectively unreachable for metrics in [0,1])."
            )
        ),
        "measurements": _compact([
            _meas(
                ca.get("raw_key") or "model_output",
                ca.get("raw_value"),
                unit="model head [0,1]",
                role="model_output",
                note="Not a physical sensor measurement.",
            )
        ]),
    }

    classical_builder = {
        "Sharpness": _classical_sharpness,
        "Blur": _classical_blur,
        "Noise": _classical_noise,
        "Brightness": _classical_brightness,
        "Contrast": _classical_contrast,
        "Blocking Artifacts": _classical_blocking,
        "Ringing Artifacts": _classical_ringing,
    }[name]

    classical = classical_builder(
        cb=cb,
        raw=raw,
        quality=quality,
        diagnostics=diagnostics if diag_ok else {},
        blocking=blocking,
        ringing=ringing,
        available=engine_b_available and cb.get("badge") is not None,
    )

    disagreement = _disagreement_note(name, ca.get("badge"), cb.get("badge"))

    return {
        "name": name,
        "measures": _MEASURES_WHAT[name],
        "efficientnet": enet,
        "classical": classical,
        "disagreement_note": disagreement,
    }


def _disagreement_note(name: str, a: int | None, b: int | None) -> str | None:
    if a is None or b is None:
        if a is None and b is not None:
            return (
                f"{name}: EfficientNet-B0 unavailable; only the classical rating "
                "is shown. No agreement comparison."
            )
        if b is None and a is not None:
            return (
                f"{name}: classical engine unavailable; only EfficientNet-B0 is shown."
            )
        return None
    delta = abs(int(a) - int(b))
    if delta == 0:
        return f"{name}: both engines agree at {a}/5 (agreement does not prove accuracy)."
    if delta == 1:
        return (
            f"{name}: engines differ by 1 badge (ENET {a}/5 vs classical {b}/5). "
            "Small gaps are common because mappings differ (_soft_score vs equal_bin)."
        )
    return (
        f"{name}: engines disagree by {delta} badges (ENET {a}/5 vs classical {b}/5). "
        "Inspect classical measurements below; do not assume either score is ground truth."
    )


def _classical_sharpness(**kw: Any) -> dict[str, Any]:
    cb, raw, diag = kw["cb"], kw["raw"], kw["diagnostics"]
    ten = raw.get("tenengrad")
    edge = diag.get("edge_pixel_fraction")
    strong = diag.get("strong_edge_pixel_fraction")
    grad = diag.get("gradient_mean")
    q = cb.get("quality_0_1")
    interpretation_parts = []
    if ten is not None:
        interpretation_parts.append(
            f"Tenengrad edge energy is {float(ten):.2f} (scoring input for classical Sharpness)."
        )
    if edge is not None:
        interpretation_parts.append(
            f"About {_pct(edge)} of pixels exceed a moderate gradient threshold "
            f"and {_pct(strong)} look like strong edges (diagnostic only)."
        )
    if edge is not None and float(edge) < 0.02 and ten is not None and float(ten) < 20:
        interpretation_parts.append(
            "Low edge density with low Tenengrad suggests softness or limited detail, "
            "not necessarily sensor noise."
        )
    elif edge is not None and float(edge) > 0.15 and ten is not None and float(ten) < 25:
        interpretation_parts.append(
            "Many weak edges with modest Tenengrad can indicate noisy or textured "
            "content rather than crisp subject focus."
        )
    elif not interpretation_parts:
        interpretation_parts.append("Sharpness measurements unavailable for interpretation.")

    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v2",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": cb.get("status") or "adopted_research",
        "measurements": _compact([
            _meas("tenengrad", ten, unit="gradient energy", role="scoring_input"),
            _meas("sharpness_quality_0_1", q, unit="[0,1] quality", role="scoring_input"),
            _meas("edge_pixel_fraction", edge, unit="fraction", role="diagnostic_only"),
            _meas("strong_edge_pixel_fraction", strong, unit="fraction", role="diagnostic_only"),
            _meas("gradient_mean", grad, unit="mean |∇|", role="diagnostic_only"),
        ]),
        "interpretation": " ".join(interpretation_parts),
        "limitation": (
            "Tenengrad responds to any high-frequency energy, including noise and "
            "texture. It is not a validated perceptual sharpness meter for ACCESS."
        ),
        "warning": cb.get("warning"),
    }


def _classical_blur(**kw: Any) -> dict[str, Any]:
    cb, raw, diag = kw["cb"], kw["raw"], kw["diagnostics"]
    lap = raw.get("laplacian_var")
    lap_d = diag.get("laplacian_variance_diagnostic")
    edge = diag.get("edge_pixel_fraction")
    q = cb.get("quality_0_1")
    parts = []
    if lap is not None:
        parts.append(
            f"Laplacian variance (scoring blur proxy) is {float(lap):.2f}; "
            "classical Blur badge rises with log1p(Laplacian variance)."
        )
    if edge is not None and float(edge) < 0.03:
        parts.append(
            "Very few edge pixels: low Laplacian energy may reflect a naturally "
            "smooth scene (sky, wall) rather than focus blur."
        )
    elif edge is not None and float(edge) > 0.08 and lap is not None and float(lap) < 50:
        parts.append(
            "Edges are present but Laplacian variance is modest, which is more "
            "consistent with softness or mild blur than with an empty smooth field."
        )
    if not parts:
        parts.append("Blur measurements unavailable for interpretation.")
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v2",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": cb.get("status") or "adopted_research",
        "measurements": _compact([
            _meas("laplacian_var", lap, unit="variance", role="scoring_input"),
            _meas("blur_quality_0_1", q, unit="[0,1] freedom-from-blur", role="scoring_input"),
            _meas(
                "laplacian_variance_diagnostic",
                lap_d,
                unit="variance",
                role="diagnostic_only",
                note="Recomputed on the diagnostic resize; may differ slightly from scoring resize path.",
            ),
            _meas("edge_pixel_fraction", edge, unit="fraction", role="diagnostic_only"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Laplacian blur proxies confuse smooth content with blur. "
            "They do not separate motion blur from defocus."
        ),
        "warning": cb.get("warning"),
    }


def _classical_noise(**kw: Any) -> dict[str, Any]:
    cb, raw, diag = kw["cb"], kw["raw"], kw["diagnostics"]
    homog = raw.get("homogeneous_residual_std")
    low = diag.get("noise_residual_std_low_texture")
    dark = diag.get("noise_residual_std_dark_low_texture")
    dark_frac = diag.get("dark_low_texture_fraction")
    q = cb.get("quality_0_1")
    parts = [
        "Noise estimate is UNVALIDATED against the ACCESS human pilot "
        "(classical Noise v2 was wrong-signed; treat as diagnostic only)."
    ]
    if homog is not None:
        parts.append(
            f"Homogeneous-region residual std (scoring input) is {float(homog):.4f}."
        )
    if low is not None:
        parts.append(
            f"Diagnostic residual std on low-texture regions is {float(low):.4f}."
        )
    if dark is not None and dark_frac is not None:
        parts.append(
            f"In dark+low-texture regions ({_pct(dark_frac)} of pixels), residual std "
            f"is {float(dark):.4f}; elevated values can suggest shadow noise, but this "
            "is not a validated detector."
        )
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v2",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": "UNVALIDATED_on_pilot",
        "measurements": _compact([
            _meas("homogeneous_residual_std", homog, unit="std", role="scoring_input"),
            _meas("noise_quality_0_1", q, unit="[0,1] cleanliness", role="scoring_input"),
            _meas("noise_residual_std_low_texture", low, unit="std", role="diagnostic_only"),
            _meas(
                "noise_residual_std_dark_low_texture",
                dark,
                unit="std",
                role="diagnostic_only",
            ),
            _meas("dark_low_texture_fraction", dark_frac, unit="fraction", role="diagnostic_only"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Texture, compression, and demosaic patterns can inflate residual std. "
            "Existence of a measurement does not make the badge accurate."
        ),
        "warning": cb.get("warning")
        or "Noise v2 UNVALIDATED (pilot rho negative). Not promoted.",
    }


def _classical_brightness(**kw: Any) -> dict[str, Any]:
    cb, raw, diag = kw["cb"], kw["raw"], kw["diagnostics"]
    mean01 = raw.get("brightness_mean")
    if mean01 is None:
        mean01 = diag.get("luminance_mean_0_1")
    shadow = raw.get("shadow_frac")
    if shadow is None:
        shadow = diag.get("shadow_clip_frac")
    highlight = raw.get("highlight_frac")
    if highlight is None:
        highlight = diag.get("highlight_clip_frac")
    clip = raw.get("exposure_clip_frac")
    dark_r = diag.get("dark_region_frac")
    bright_r = diag.get("bright_region_frac")
    q = cb.get("quality_0_1")
    parts = []
    if mean01 is not None:
        parts.append(f"Mean luminance is {float(mean01):.3f} on a 0–1 scale.")
    parts.append(
        f"Shadow clipping (<8/255): {_pct(shadow)}; "
        f"highlight clipping (>247/255): {_pct(highlight)}."
    )
    parts.append(
        f"Broader dark region (<64): {_pct(dark_r)}; bright region (>192): {_pct(bright_r)} "
        "(diagnostic bands, not scoring cutoffs)."
    )
    if dark_r is not None and bright_r is not None and float(dark_r) > 0.25 and float(bright_r) > 0.25:
        parts.append(
            "Both large dark and bright regions are present, which can indicate "
            "uneven lighting or high dynamic range content that a global mean misses."
        )
    elif shadow is not None and highlight is not None and float(shadow) + float(highlight) > 0.05:
        parts.append(
            "Non-trivial clipping fractions reduce the classical exposure quality term."
        )
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v2",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": cb.get("status") or "adopted_research",
        "measurements": _compact([
            _meas("brightness_mean", mean01, unit="luminance [0,1]", role="scoring_input"),
            _meas("shadow_clip_frac", shadow, unit="fraction <8/255", role="scoring_input"),
            _meas("highlight_clip_frac", highlight, unit="fraction >247/255", role="scoring_input"),
            _meas("exposure_clip_frac", clip, unit="shadow+highlight", role="scoring_input"),
            _meas("dark_region_frac", dark_r, unit="fraction <64/255", role="diagnostic_only"),
            _meas("bright_region_frac", bright_r, unit="fraction >192/255", role="diagnostic_only"),
            _meas(
                "luminance_mean_0_255",
                diag.get("luminance_mean_0_255"),
                unit="0–255",
                role="diagnostic_only",
            ),
            _meas("brightness_quality_0_1", q, unit="[0,1]", role="scoring_input"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Global mean exposure cannot fully describe mixed lighting, backlighting, "
            "or subject-specific underexposure."
        ),
        "warning": cb.get("warning"),
    }


def _classical_contrast(**kw: Any) -> dict[str, Any]:
    cb, raw, diag = kw["cb"], kw["raw"], kw["diagnostics"]
    rms = raw.get("contrast_rms_over_72")
    spread = diag.get("percentile_spread_p5_p95")
    p5 = diag.get("percentile_p5")
    p95 = diag.get("percentile_p95")
    std = diag.get("luminance_std")
    q = cb.get("quality_0_1")
    parts = []
    if rms is not None:
        parts.append(
            f"RMS contrast quality term (std/72, scoring input) is {float(rms):.4f}."
        )
    if spread is not None and p5 is not None and p95 is not None:
        parts.append(
            f"Luminance percentile spread p5–p95 is {float(spread):.1f} "
            f"(p5={float(p5):.1f}, p95={float(p95):.1f}) on 0–255."
        )
    parts.append(
        "Global contrast metrics flatten local subject/background separation and "
        "can look high on harsh clipped scenes unless clipping gates are applied."
    )
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v2",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": cb.get("status") or "adopted_research",
        "measurements": _compact([
            _meas("contrast_rms_over_72", rms, unit="quality term", role="scoring_input"),
            _meas("contrast_quality_0_1", q, unit="[0,1]", role="scoring_input"),
            _meas("luminance_std", std, unit="0–255 std", role="diagnostic_only"),
            _meas("percentile_p5", p5, unit="0–255", role="diagnostic_only"),
            _meas("percentile_p95", p95, unit="0–255", role="diagnostic_only"),
            _meas("percentile_spread_p5_p95", spread, unit="0–255", role="diagnostic_only"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Global RMS / percentile spread is not local contrast and is not a "
            "perceptual contrast MOA for ACCESS documentation photos."
        ),
        "warning": cb.get("warning"),
    }


def _classical_blocking(**kw: Any) -> dict[str, Any]:
    cb, raw, blocking = kw["cb"], kw["raw"], kw["blocking"]
    amount = raw.get("blocking_amount_v3", blocking.get("blocking_amount"))
    v_ex = raw.get("blocking_vertical_excess_v3", blocking.get("vertical_excess"))
    h_ex = raw.get("blocking_horizontal_excess_v3", blocking.get("horizontal_excess"))
    n_v = blocking.get("n_flat_seams_v")
    n_h = blocking.get("n_flat_seams_h")
    used_fb = blocking.get("used_fallback")
    q = cb.get("quality_0_1")
    parts = []
    if amount is not None:
        parts.append(
            f"Blocking amount v3 (lattice excess on flat tiles) is {float(amount):.4f}."
        )
    if n_v is not None and n_h is not None:
        parts.append(
            f"Flat 8×8 seam pairs scored: vertical={int(n_v)}, horizontal={int(n_h)}."
        )
        if int(n_v) + int(n_h) < 8:
            parts.append(
                "Few flat seams were available, so blocking evidence is weak; "
                "natural edges are intentionally down-weighted by the flat-tile gate."
            )
        elif amount is not None and float(amount) < 0.5:
            parts.append(
                "Low lattice excess on flat tiles suggests little meaningful 8×8 "
                "blocking evidence (not a claim of perceptual perfection)."
            )
        elif amount is not None and float(amount) >= 1.0:
            parts.append(
                "Elevated boundary-vs-interior excess on flat tiles is consistent "
                "with JPEG blocking structure rather than ordinary texture edges."
            )
    if used_fb:
        parts.append(
            "Estimator used a global fallback because too few flat seams were found."
        )
    if not parts:
        parts.append("Blocking measurements unavailable.")
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v3",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": cb.get("status") or "lightweight_pass_only",
        "measurements": _compact([
            _meas("blocking_amount_v3", amount, unit="lattice excess", role="scoring_input"),
            _meas("blocking_vertical_excess_v3", v_ex, unit="excess", role="scoring_input"),
            _meas("blocking_horizontal_excess_v3", h_ex, unit="excess", role="scoring_input"),
            _meas("n_flat_seams_v", n_v, unit="count", role="scoring_input"),
            _meas("n_flat_seams_h", n_h, unit="count", role="scoring_input"),
            _meas(
                "used_fallback",
                (1 if used_fb else 0) if used_fb is not None else None,
                unit="0/1",
                role="scoring_input",
                note="1 means global fallback path.",
            ),
            _meas("blocking_quality_0_1", q, unit="[0,1] cleanliness", role="scoring_input"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Blocking v3 passed lightweight synthetic gates only. Human pilot "
            "validation is still limited; flat-tile gating reduces but does not "
            "eliminate false structure."
        ),
        "warning": cb.get("warning"),
    }


def _classical_ringing(**kw: Any) -> dict[str, Any]:
    cb, raw, ringing, diag = kw["cb"], kw["raw"], kw["ringing"], kw["diagnostics"]
    amount = raw.get("ringing_amount_v3", ringing.get("ringing_amount"))
    over = raw.get("ringing_median_overshoot_v3", ringing.get("median_overshoot"))
    osc = raw.get("ringing_median_oscillation_v3", ringing.get("median_oscillation"))
    n_scored = ringing.get("n_scored")
    strong = diag.get("strong_edge_pixel_fraction")
    q = cb.get("quality_0_1")
    parts = [
        "Ringing estimate is UNVALIDATED for ACCESS production use. "
        "Sharp natural edges and textures can create false positives."
    ]
    if amount is not None:
        parts.append(f"Ringing amount v3 is {float(amount):.4f}.")
    if over is not None and osc is not None:
        parts.append(
            f"Median overshoot={float(over):.4f}, median oscillation={float(osc):.4f}."
        )
    if n_scored is not None:
        parts.append(f"Edge probes scored: {int(n_scored)}.")
        if int(n_scored) == 0:
            parts.append("No scored edge probes; ringing amount may be a floor/empty result.")
    if strong is not None and float(strong) > 0.05 and amount is not None and float(amount) > 0.2:
        parts.append(
            "Strong-edge fraction is non-trivial; halo-like scores may partly reflect "
            "crisp legitimate edges rather than compression ringing."
        )
    return {
        "badge": cb.get("badge"),
        "badge_label": cb.get("badge_label"),
        "version": cb.get("version") or "v3",
        "available": kw["available"],
        "quality_0_1": q,
        "reliability": "UNVALIDATED_on_pilot",
        "measurements": _compact([
            _meas("ringing_amount_v3", amount, unit="halo amount", role="scoring_input"),
            _meas("ringing_median_overshoot_v3", over, unit="overshoot", role="scoring_input"),
            _meas("ringing_median_oscillation_v3", osc, unit="oscillation", role="scoring_input"),
            _meas("n_scored", n_scored, unit="count", role="scoring_input"),
            _meas(
                "strong_edge_pixel_fraction",
                strong,
                unit="fraction",
                role="diagnostic_only",
                note="Context for false-positive risk; not a ringing score input.",
            ),
            _meas("ringing_quality_0_1", q, unit="[0,1] cleanliness", role="scoring_input"),
        ]),
        "interpretation": " ".join(parts),
        "limitation": (
            "Edge-halo proxies confuse sharpening, texture, and true ringing. "
            "Measurement presence does not imply accuracy."
        ),
        "warning": cb.get("warning")
        or "Ringing UNVALIDATED. Not promoted for production.",
    }
