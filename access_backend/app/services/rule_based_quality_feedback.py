"""Deterministic, metric-grounded photo quality feedback (Gemini-independent).

Produces the same structured shape as Gemini mentor JSON:
explanation, strengths, improvements, tips, closing_message.

Does not change scoring formulas or invent measurements for N/A criteria.
"""

from __future__ import annotations

import re
from typing import Any

from app.services.overall_quality_band import overall_quality_label_from_five_point

# Member-facing narrative must not expose scores, percents, or raw measurements.
_NARRATIVE_MEASUREMENT_RE = re.compile(
    r"""
    \b\d+(?:\.\d+)?\s*/\s*(?:5|100)\b   # 3/5, 70/100
    | \b\d+(?:\.\d+)?\s*%              # 70%
    | \b\d+(?:\.\d+)?\s*/\s*5\b
    | \(\s*\d+(?:\.\d+)?\s*/\s*5\s*\)  # (3/5)
    | \bscored\s+\d+(?:\.\d+)?\b
    | \baround\s+\d+(?:\.\d+)?\s*/\s*5\b
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Primary photo quality criteria (VisionCheck seven).
PHOTO_QUALITY_METRICS = (
    "Sharpness",
    "Blur",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Color Balance",
    "Color Saturation",
)

_STRENGTH_MIN = 4
_WEAK_MAX = 2
_FAIR = 3
_MAX_STRENGTHS = 3
_MAX_IMPROVEMENTS = 3
_MAX_TIPS = 3


def _as_available_rows(criteria: list[Any] | None) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not isinstance(criteria, list):
        return rows
    for item in criteria:
        if not isinstance(item, dict):
            continue
        if item.get("available") is False:
            continue
        score = item.get("score")
        if score is None:
            continue
        try:
            score_i = int(score)
        except (TypeError, ValueError):
            continue
        if not 1 <= score_i <= 5:
            continue
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        rows.append(
            {
                "name": name,
                "score": score_i,
                "explanation": str(item.get("explanation") or "").strip(),
                "suggestion": str(item.get("suggestion") or "").strip(),
                "label": str(item.get("label") or "").strip(),
            }
        )
    return rows


def _score_map(rows: list[dict[str, Any]]) -> dict[str, int]:
    return {r["name"]: int(r["score"]) for r in rows}


def _text_blob(*parts: str) -> str:
    return " ".join(p for p in parts if p).lower()


def _brightness_direction(row: dict[str, Any] | None, warnings: list[str]) -> str | None:
    """Return 'under', 'over', or None when direction is unknown."""
    blob = _text_blob(
        *(warnings or []),
        (row or {}).get("explanation") or "",
        (row or {}).get("suggestion") or "",
    )
    under_keys = ("underex", "too dark", "quite dark", "under-expos", "needs more light", "increase exposure")
    over_keys = ("overexpos", "too bright", "washed out", "over-expos", "reduce exposure", "highlights")
    under = any(k in blob for k in under_keys)
    over = any(k in blob for k in over_keys)
    if under and not over:
        return "under"
    if over and not under:
        return "over"
    return None


def _saturation_direction(row: dict[str, Any] | None) -> str | None:
    blob = _text_blob((row or {}).get("explanation") or "", (row or {}).get("suggestion") or "")
    if any(k in blob for k in ("oversatur", "too intense", "heavily oversaturated", "quite high")):
        return "over"
    if any(k in blob for k in ("muted", "washed out", "undersatur", "too low", "increase vibrance")):
        return "under"
    return None


def narrative_contains_measurements(text: str) -> bool:
    """True when text exposes score-like or measurement numbers to members."""
    return bool(_NARRATIVE_MEASUREMENT_RE.search(text or ""))


def strip_narrative_measurements(text: str) -> str:
    """Best-effort cleanup of score/percent fragments from member-facing copy."""
    cleaned = _NARRATIVE_MEASUREMENT_RE.sub("", text or "")
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    cleaned = re.sub(r"\s+([,.;:!?)])", r"\1", cleaned)
    cleaned = re.sub(r"\(\s*\)", "", cleaned)
    return cleaned.strip(" :;-")


def _naturalize_criterion_explanation(text: str) -> str:
    expl = (text or "").strip()
    if "heuristic" in expl.lower():
        expl = expl.split("(")[0].strip()
    if expl.lower().startswith("efficientnet"):
        return ""
    return strip_narrative_measurements(expl)


def _strength_line(row: dict[str, Any]) -> str:
    name = row["name"]
    score = row["score"]
    canned = {
        "Sharpness": "Fine detail and edges look crisp enough for clear documentation.",
        "Blur": "Motion and focus blur look well controlled.",
        "Brightness": "Exposure looks well balanced for readable detail.",
        "Contrast": "Tonal separation helps subjects stand out clearly.",
        "Blocking Artifacts": "Compression artifacts look minimal.",
        "Color Balance": "White balance looks acceptable for documentation.",
        "Color Saturation": "Color intensity looks suitable for documentation.",
    }
    base = canned.get(name)
    if row["explanation"] and score >= 4 and len(row["explanation"]) < 160:
        expl = _naturalize_criterion_explanation(row["explanation"])
        if expl:
            return f"{name}: {expl}"
    if base:
        return f"{name}: {base}"
    return f"{name}: this quality aspect looks solid."


def _improvement_line(name: str, score: int, *, clarity_combined: bool = False) -> str:
    del score  # Used only for prioritization upstream; never shown to members.
    if clarity_combined:
        return (
            "Clarity: the photo looks softer than ideal for crisp documentation detail."
        )
    lines = {
        "Sharpness": "Sharpness: fine detail looks softer than ideal.",
        "Blur": "Blur: blur is reducing subject clarity.",
        "Brightness": "Brightness: exposure looks uneven for documentation.",
        "Contrast": "Contrast: tonal separation looks weak or uneven.",
        "Blocking Artifacts": "Blocking Artifacts: compression blocks may be visible.",
        "Color Balance": "Color Balance: a color cast may affect natural appearance.",
        "Color Saturation": "Color Saturation: color intensity may need a conservative adjustment.",
    }
    return lines.get(name, f"{name}: this quality aspect needs improvement.")


def _tip_for(
    name: str,
    score: int,
    row: dict[str, Any] | None,
    *,
    warnings: list[str],
    clarity_combined: bool = False,
) -> str:
    if clarity_combined:
        return (
            "Check focus on the main subject and keep the camera steady to reduce "
            "softness and blur in one step."
        )
    if name == "Sharpness":
        return "Tap to focus on the main subject and keep the camera steady when capturing."
    if name == "Blur":
        return "Reduce camera or subject movement; use a faster shutter or brace your stance."
    if name == "Brightness":
        direction = _brightness_direction(row, warnings)
        if direction == "under":
            return "Add light or raise exposure carefully so important details are easier to see."
        if direction == "over":
            return "Reduce intense light or lower exposure so highlights are less washed out."
        return (
            "Review lighting and exposure. Aim for even light so important details stay visible "
            "without guessing whether the frame is too dark or too bright."
        )
    if name == "Contrast":
        return (
            "Improve tonal separation with gentle directional light when possible. "
            "Avoid assuming that more contrast is always better."
        )
    if name == "Blocking Artifacts":
        return (
            "Avoid heavy compression and repeated low-quality exports. "
            "Save or share at a higher quality setting when you can."
        )
    if name == "Color Balance":
        return (
            "Check lighting and white balance if natural colors are important. "
            "A mild cast can be intentional, so correct it only when true-to-life color is needed."
        )
    if name == "Color Saturation":
        direction = _saturation_direction(row)
        if direction == "over":
            return "Reduce saturation or vibrance slightly if natural documentation color is preferred."
        if direction == "under":
            return "Increase vibrance slightly only if the scene should look more vivid."
        return (
            "Adjust saturation conservatively. Do not push color intensity without checking "
            "how natural the subject looks."
        )
    suggestion = (row or {}).get("suggestion") or ""
    if suggestion:
        return suggestion
    return f"Review capture settings related to {name.lower()} and try another photo."


def _prioritized_weak_names(scores: dict[str, int]) -> list[str]:
    """Return up to 3 weakness themes, combining Sharpness+Blur into Clarity."""
    weak = [(n, s) for n, s in scores.items() if s <= _WEAK_MAX]
    # Also consider a single fair metric only when nothing is critically weak.
    if not weak:
        fair = [(n, s) for n, s in scores.items() if s == _FAIR]
        fair.sort(key=lambda t: t[1])
        return [n for n, _ in fair[:2]]

    weak.sort(key=lambda t: (t[1], t[0]))
    sharp = scores.get("Sharpness")
    blur = scores.get("Blur")
    clarity_issue = (
        sharp is not None
        and blur is not None
        and sharp <= _WEAK_MAX
        and blur <= _WEAK_MAX
    )

    out: list[str] = []
    if clarity_issue:
        out.append("Clarity")
    for name, _score in weak:
        if clarity_issue and name in {"Sharpness", "Blur"}:
            continue
        if name not in out:
            out.append(name)
        if len(out) >= _MAX_IMPROVEMENTS:
            break
    return out[:_MAX_IMPROVEMENTS]


def generate_rule_based_media_feedback(
    criteria: list[Any] | None,
    *,
    media_type: str = "photo",
    overall_score: float | None = None,
    quality_level: str | None = None,
    quality_warnings: list[str] | None = None,
    member_first_name: str | None = None,
) -> dict[str, Any]:
    """Build structured mentor feedback from available criterion scores only."""
    rows = _as_available_rows(criteria)
    scores = _score_map(rows)
    by_name = {r["name"]: r for r in rows}
    warnings = [str(w) for w in (quality_warnings or []) if w]
    media_label = "video" if str(media_type).lower() == "video" else "photo"
    name_prefix = f"{member_first_name.strip()}, " if (member_first_name or "").strip() else ""

    if len(rows) < 2:
        explanation = (
            f"{name_prefix}Thanks for sharing this {media_label}. "
            "Detailed quality feedback is limited because too few technical measures "
            "were available for this submission."
        )
        return sanitize_member_facing_feedback(
            {
                "explanation": explanation.strip(),
                "strengths": [],
                "improvements": [
                    "Detailed quality feedback is limited until more quality measures are available."
                ],
                "tips": [
                    "Try another clear, well-lit capture so more quality checks can run successfully."
                ],
                "closing_message": "Keep practicing and submit again when you can!",
                "source": "rule_based",
                "insufficient_metrics": True,
            }
        )

    strong_rows = sorted(
        [r for r in rows if r["score"] >= _STRENGTH_MIN],
        key=lambda r: (-r["score"], r["name"]),
    )[:_MAX_STRENGTHS]

    themes = _prioritized_weak_names(scores)
    clarity_combined = "Clarity" in themes

    strengths = [_strength_line(r) for r in strong_rows]
    # Avoid contradicting: do not list Sharpness/Blur as strengths if Clarity is a weakness theme.
    if clarity_combined:
        strengths = [s for s in strengths if not s.startswith("Sharpness") and not s.startswith("Blur")]

    improvements: list[str] = []
    tips: list[str] = []
    for theme in themes:
        if theme == "Clarity":
            worst = min(scores.get("Sharpness", 5), scores.get("Blur", 5))
            improvements.append(_improvement_line("Sharpness", worst, clarity_combined=True))
            tip = _tip_for("Sharpness", worst, None, warnings=warnings, clarity_combined=True)
            if tip not in tips:
                tips.append(tip)
            continue
        row = by_name.get(theme)
        score = scores.get(theme, _FAIR)
        improvements.append(_improvement_line(theme, score))
        tip = _tip_for(theme, score, row, warnings=warnings)
        if tip not in tips:
            tips.append(tip)
        if len(tips) >= _MAX_TIPS:
            break

    tips = tips[:_MAX_TIPS]
    improvements = improvements[:_MAX_IMPROVEMENTS]

    all_good = bool(rows) and all(r["score"] >= _STRENGTH_MIN for r in rows)
    if all_good:
        improvements = []
        tips = [
            "Keep using steady focus and even lighting on your next capture.",
            "When exporting, prefer higher quality settings to protect fine detail.",
        ][:_MAX_TIPS]

    # Opening explanation. Prefer caller overall (v2 Clarity formula). Fallback matches v2.
    if overall_score is None and rows:
        clarity = [r["score"] for r in rows if r["name"] in ("Sharpness", "Blur")]
        others = [float(r["score"]) for r in rows if r["name"] not in ("Sharpness", "Blur")]
        factors: list[float] = list(others)
        if clarity:
            factors.append(sum(clarity) / len(clarity))
        overall_score = round(sum(factors) / len(factors), 2) if factors else 0.0
    overall_f = float(overall_score or 0.0)
    # Callers may still pass a stored quality_level. The opening sentence follows
    # the displayed 0–100 band instead of that older 1–5 label.
    _ = quality_level
    level = overall_quality_label_from_five_point(overall_f)

    if all_good:
        strength_names = ", ".join(r["name"].lower() for r in strong_rows) or "technical quality"
        explanation = (
            f"{name_prefix}Great work on this {media_label}! "
            f"Your measured quality looks strong overall ({level}), "
            f"especially in {strength_names}."
        )
    elif strong_rows:
        strength_names = ", ".join(r["name"].lower() for r in strong_rows)
        focus = themes[0] if themes else "a few technical details"
        focus_label = "clarity" if focus == "Clarity" else focus.lower()
        explanation = (
            f"{name_prefix}Nice effort on this {media_label}! "
            f"Overall quality looks {level.lower()}. "
            f"You are already doing well with {strength_names}. "
            f"The most useful next step is improving {focus_label}."
        )
    else:
        explanation = (
            f"{name_prefix}Thank you for sharing this {media_label}. "
            f"Overall quality looks {level.lower()}. "
            "There is clear potential here, and a few focused capture adjustments "
            "should make the next submission stronger."
        )

    if not strengths and not all_good:
        strengths = [
            "You submitted the photo for evaluation, which is a solid step toward better documentation practice."
        ]

    return sanitize_member_facing_feedback(
        {
            "explanation": explanation.strip(),
            "strengths": strengths,
            "improvements": improvements,
            "tips": tips,
            "closing_message": "Keep practicing and submitting. Consistency is how great documenters are made!",
            "source": "rule_based",
            "insufficient_metrics": False,
        }
    )


def sanitize_member_facing_feedback(feedback: dict[str, Any]) -> dict[str, Any]:
    """Strip score-like numbers from narrative fields only (keeps structure)."""
    out = dict(feedback)
    for key in ("explanation", "closing_message"):
        if isinstance(out.get(key), str):
            out[key] = strip_narrative_measurements(out[key])
    for key in ("strengths", "improvements", "tips"):
        raw = out.get(key)
        if isinstance(raw, list):
            out[key] = [
                strip_narrative_measurements(str(item))
                for item in raw
                if str(item).strip()
            ]
    return out


def format_rule_based_ai_feedback(feedback: dict[str, Any]) -> str:
    """Flatten structured rule-based feedback into the legacy ai_feedback string."""
    parts: list[str] = []
    explanation = str(feedback.get("explanation") or "").strip()
    if explanation:
        parts.append(explanation)
    strengths = feedback.get("strengths") or []
    if isinstance(strengths, list) and strengths:
        parts.append("Strengths: " + "; ".join(str(s) for s in strengths if s) + ".")
    improvements = feedback.get("improvements") or []
    if isinstance(improvements, list) and improvements:
        parts.append("Areas to improve: " + "; ".join(str(s) for s in improvements if s) + ".")
    tips = feedback.get("tips") or []
    if isinstance(tips, list) and tips:
        parts.append("Recommendations: " + " ".join(f"• {t}" for t in tips if t))
    closing = str(feedback.get("closing_message") or "").strip()
    if closing:
        parts.append(closing)
    parts.append(
        "Quality ratings are automated estimates and may not reflect artistic intent or human judgment."
    )
    return " ".join(parts)


def format_rule_based_improvement_suggestions(feedback: dict[str, Any]) -> str:
    tips = feedback.get("tips") or []
    if isinstance(tips, list) and tips:
        return "\n".join(f"• {t}" for t in tips if t)
    return "Keep practicing. Every submission builds skill."
