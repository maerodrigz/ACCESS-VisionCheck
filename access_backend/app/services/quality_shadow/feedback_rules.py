"""Documented interpretation rules for hybrid (research) criterion feedback.

These thresholds apply to Phase 1/2 hybrid continuous q in [0,1] (higher = better)
and to color heuristic badges. They are **not** EfficientNet `_soft_score` cut points
and were not fitted on the 30-image human pilot.

MUSIQ OPQ is intentionally excluded: overall perceptual quality stays separate from
criterion-specific feedback.
"""

from __future__ import annotations

from typing import Any, TypedDict

FEEDBACK_RULESET_VERSION = "hybrid_feedback_rules_v1"

# Continuous q thresholds (higher = better). Documented a priori research bands.
Q_SEVERE = 0.25
Q_MODERATE = 0.45
Q_MILD = 0.65

# Color heuristic badges (1–5, higher = better). Research interpretation only.
COLOR_BADGE_SEVERE_MAX = 2
COLOR_BADGE_MODERATE = 3


class RuleDef(TypedDict):
    rule_id: str
    criterion: str
    severity: str  # severe | moderate | mild | no_issue | unavailable
    metric: str
    op: str
    threshold: float | int | None
    observation: str
    suggested_improvement: str
    confidence: str
    uncertainty_note: str


# ---------------------------------------------------------------------------
# Per-criterion issue / no-issue templates keyed by severity band.
# ---------------------------------------------------------------------------

CRITERION_RULE_TEMPLATES: dict[str, dict[str, dict[str, str]]] = {
    "sharpness": {
        "severe": {
            "observation": (
                "Fine detail looks severely soft on the Laplacian focus signal. "
                "Edges and texture are hard to resolve for documentation."
            ),
            "suggested_improvement": (
                "Tap to focus on the main subject, hold the camera steady, and avoid "
                "digital zoom when possible."
            ),
        },
        "moderate": {
            "observation": (
                "Detail looks moderately soft. Important edges may lack crispness "
                "for documentation review."
            ),
            "suggested_improvement": (
                "Refocus on the subject and brace your elbows or use a firmer stance."
            ),
        },
        "mild": {
            "observation": (
                "Slight softness is present on the focus/detail signal. The frame may "
                "still be usable but is not fully crisp."
            ),
            "suggested_improvement": (
                "Confirm focus lock before capture and keep the shutter press gentle."
            ),
        },
        "no_issue": {
            "observation": (
                "Focus/detail energy looks adequate on the hybrid Laplacian signal "
                "for documentation."
            ),
            "suggested_improvement": "Maintain this focus technique for future submissions.",
        },
    },
    "blur": {
        # Blur shares the Laplacian axis with sharpness (Phase 9 duplication).
        # Generator suppresses blur issues when sharpness already spoke.
        "severe": {
            "observation": (
                "Blur/softness is severe on the shared focus axis (same signal as sharpness)."
            ),
            "suggested_improvement": (
                "Hold steady, tap to focus, and avoid motion during capture."
            ),
        },
        "moderate": {
            "observation": (
                "Moderate blur/softness on the shared focus axis (same signal as sharpness)."
            ),
            "suggested_improvement": "Brace the camera and re-check focus before shooting.",
        },
        "mild": {
            "observation": (
                "Mild blur/softness on the shared focus axis (same signal as sharpness)."
            ),
            "suggested_improvement": "Keep the camera steadier at the moment of capture.",
        },
        "no_issue": {
            "observation": "Blur signal does not indicate a separate issue beyond focus/detail.",
            "suggested_improvement": "Maintain steady capture technique.",
        },
    },
    "brightness": {
        "severe": {
            "observation": (
                "Exposure looks poorly balanced (far from mid-gray or clipped). "
                "Subject detail may be lost in shadows or highlights."
            ),
            "suggested_improvement": (
                "Move to more even lighting, avoid strong backlight, or adjust exposure "
                "compensation."
            ),
        },
        "moderate": {
            "observation": (
                "Exposure is noticeably off mid-tone balance or shows clipping risk."
            ),
            "suggested_improvement": (
                "Adjust exposure or relocate so the subject is evenly lit."
            ),
        },
        "mild": {
            "observation": "Exposure is slightly away from a balanced mid-tone target.",
            "suggested_improvement": "Fine-tune exposure or lighting for more even brightness.",
        },
        "no_issue": {
            "observation": "Brightness looks reasonably balanced for documentation.",
            "suggested_improvement": "Maintain this lighting/exposure approach.",
        },
    },
    "contrast": {
        "severe": {
            "observation": (
                "Tonal contrast looks very low after hybrid RMS mapping. The subject "
                "may appear flat."
            ),
            "suggested_improvement": (
                "Add directional light or avoid heavy haze/backlight that flattens tones."
            ),
        },
        "moderate": {
            "observation": "Contrast looks limited; subject-background separation may be weak.",
            "suggested_improvement": "Improve lighting direction or avoid flat overcast washout.",
        },
        "mild": {
            "observation": "Contrast is a bit soft but may still be usable.",
            "suggested_improvement": "Slightly stronger directional light can improve separation.",
        },
        "no_issue": {
            "observation": "Contrast looks adequate for documentation.",
            "suggested_improvement": "Maintain this tonal range when possible.",
        },
    },
    "blocking_artifacts": {
        "severe": {
            "observation": (
                "Strong 8x8 boundary energy suggests visible compression blocking."
            ),
            "suggested_improvement": (
                "Export or capture at higher quality and avoid aggressive recompression."
            ),
        },
        "moderate": {
            "observation": "Moderate blocking-boundary energy; compression blocks may show.",
            "suggested_improvement": "Prefer higher JPEG/WebP quality settings before upload.",
        },
        "mild": {
            "observation": "Mild elevation in blocking-boundary energy.",
            "suggested_improvement": "Avoid extra re-encode steps when sharing documentation photos.",
        },
        "no_issue": {
            "observation": "Blocking-boundary energy looks within a typical range.",
            "suggested_improvement": "Maintain current export quality settings.",
        },
    },
    "color_balance": {
        "severe": {
            "observation": (
                "Strong color cast detected by the heuristic white-balance estimate."
            ),
            "suggested_improvement": (
                "Set a custom white balance or correct the cast if true-to-life color matters."
            ),
        },
        "moderate": {
            "observation": "Noticeable color cast on the heuristic balance estimate.",
            "suggested_improvement": "Adjust white balance if natural subject colors are required.",
        },
        "mild": {
            "observation": "Mild color tint present; often intentional indoor/warm light.",
            "suggested_improvement": "Correct white balance only if documentation needs neutrality.",
        },
        "no_issue": {
            "observation": "Color balance looks reasonably neutral for documentation.",
            "suggested_improvement": "Maintain this white-balance approach.",
        },
    },
    "color_saturation": {
        "severe": {
            "observation": (
                "Saturation looks extreme (heavily oversaturated or washed out) on the "
                "heuristic estimate."
            ),
            "suggested_improvement": (
                "Dial vibrance/saturation toward natural documentation color."
            ),
        },
        "moderate": {
            "observation": "Saturation looks outside a typical documentation range.",
            "suggested_improvement": "Adjust vibrance slightly toward a more natural look.",
        },
        "mild": {
            "observation": "Saturation is moderately elevated or muted.",
            "suggested_improvement": "Keep saturation moderate unless the event look requires stronger color.",
        },
        "no_issue": {
            "observation": "Saturation looks within a typical documentation range.",
            "suggested_improvement": "Maintain this color intensity for future submissions.",
        },
    },
}


RAW_KEYS: dict[str, str] = {
    "sharpness": "sharpness_laplacian_var",
    "blur": "blur_inv_laplacian",
    "brightness": "brightness_mean",
    "contrast": "contrast_rms",
    "blocking_artifacts": "blocking_boundary_ratio",
    "color_balance": "color_balance_badge",
    "color_saturation": "color_saturation_badge",
}


def band_from_q(q: float | None) -> str | None:
    if q is None:
        return None
    if q < Q_SEVERE:
        return "severe"
    if q < Q_MODERATE:
        return "moderate"
    if q < Q_MILD:
        return "mild"
    return "no_issue"


def band_from_color_badge(badge: int | None, *, available: bool) -> str | None:
    if not available:
        return "unavailable"
    if badge is None:
        return "unavailable"
    if badge <= COLOR_BADGE_SEVERE_MAX:
        return "severe"
    if badge == COLOR_BADGE_MODERATE:
        return "moderate"
    # badges 4–5 → no_issue (mild tint paths are encoded inside heuristic score 3/4)
    if badge == 4:
        return "mild"
    return "no_issue"


def threshold_for_band(band: str, *, kind: str) -> dict[str, Any]:
    if kind == "q":
        mapping = {
            "severe": {"metric": "q", "op": "<", "value": Q_SEVERE},
            "moderate": {"metric": "q", "op": "<", "value": Q_MODERATE},
            "mild": {"metric": "q", "op": "<", "value": Q_MILD},
            "no_issue": {"metric": "q", "op": ">=", "value": Q_MILD},
        }
        return mapping[band]
    mapping = {
        "severe": {"metric": "color_badge", "op": "<=", "value": COLOR_BADGE_SEVERE_MAX},
        "moderate": {"metric": "color_badge", "op": "==", "value": COLOR_BADGE_MODERATE},
        "mild": {"metric": "color_badge", "op": "==", "value": 4},
        "no_issue": {"metric": "color_badge", "op": ">=", "value": 5},
        "unavailable": {"metric": "color_available", "op": "==", "value": False},
    }
    return mapping[band]


def build_rule_catalog() -> list[dict[str, Any]]:
    """Flat catalog for docs / evaluation templates."""
    rows: list[dict[str, Any]] = []
    for criterion, bands in CRITERION_RULE_TEMPLATES.items():
        kind = "color_badge" if criterion.startswith("color_") else "q"
        for severity, texts in bands.items():
            thr = threshold_for_band(severity, kind=kind if kind == "q" else "color")
            rows.append(
                {
                    "rule_id": f"{criterion}_{severity}_v1",
                    "criterion": criterion,
                    "severity": severity,
                    "threshold": thr,
                    "observation": texts["observation"],
                    "suggested_improvement": texts["suggested_improvement"],
                    "confidence": "research_unvalidated",
                    "notes": (
                        "Sharpness and blur share one Laplacian quality axis; "
                        "generator emits a single focus observation."
                        if criterion in ("sharpness", "blur")
                        else ""
                    ),
                }
            )
    return rows
