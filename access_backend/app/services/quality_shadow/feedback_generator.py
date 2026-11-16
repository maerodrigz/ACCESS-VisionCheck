"""Research-only hybrid rule-based feedback generator.

Does not call or modify production media_evaluator feedback, Gemini, XP, or UI.
Does not interpret MUSIQ OPQ as criterion feedback.
"""

from __future__ import annotations

from typing import Any

from app.services.quality_shadow.feedback_rules import (
    CRITERION_RULE_TEMPLATES,
    FEEDBACK_RULESET_VERSION,
    RAW_KEYS,
    band_from_color_badge,
    band_from_q,
    threshold_for_band,
)

Q_CRITERIA = (
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
)
COLOR_CRITERIA = ("color_balance", "color_saturation")


def _unavailable_observation(criterion: str, *, reason: str) -> dict[str, Any]:
    return {
        "criterion": criterion,
        "raw_measurement": None,
        "raw_key": RAW_KEYS.get(criterion),
        "q_value": None,
        "rule_id": f"{criterion}_unavailable_v1",
        "rule_description": f"Measurement unavailable for {criterion}",
        "threshold": {"metric": "availability", "op": "==", "value": False},
        "observation": (
            f"No reliable {criterion.replace('_', ' ')} measurement was available. "
            "No conclusion was generated."
        ),
        "suggested_improvement": "No action recommended from this criterion.",
        "observation_kind": "unavailable",
        "confidence": "unavailable",
        "uncertainty_note": reason,
        "suppressed": False,
    }


def _observation_from_band(
    *,
    criterion: str,
    band: str,
    raw_measurement: Any,
    q_value: float | None,
    kind: str,
) -> dict[str, Any]:
    templates = CRITERION_RULE_TEMPLATES[criterion][band]
    thr = threshold_for_band(band, kind=kind)
    return {
        "criterion": criterion,
        "raw_measurement": raw_measurement,
        "raw_key": RAW_KEYS.get(criterion),
        "q_value": q_value,
        "rule_id": f"{criterion}_{band}_v1",
        "rule_description": (
            f"{criterion} hybrid band={band} using {thr['metric']} {thr['op']} {thr['value']}"
        ),
        "threshold": thr,
        "observation": templates["observation"],
        "suggested_improvement": templates["suggested_improvement"],
        "observation_kind": "no_issue" if band == "no_issue" else "issue",
        "confidence": "research_unvalidated",
        "uncertainty_note": (
            "Experimental hybrid rule. Not independently validated for ACCESS documentation."
        ),
        "suppressed": False,
        "severity": band,
    }


def _suppress_as_duplicate(obs: dict[str, Any], *, reason: str) -> dict[str, Any]:
    out = dict(obs)
    out["observation_kind"] = "suppressed_duplicate"
    out["suppressed"] = True
    out["suppression_reason"] = reason
    out["observation"] = (
        "Suppressed to avoid duplicate/contradictory focus feedback. "
        "Sharpness and blur share the same Laplacian quality axis."
    )
    out["suggested_improvement"] = "See the sharpness / focus observation."
    out["confidence"] = "suppressed_duplicate"
    return out


def generate_hybrid_feedback(
    *,
    criteria_q: dict[str, Any] | None,
    criteria_raw: dict[str, Any] | None,
    color: dict[str, Any] | None,
    musiq_opq_raw: float | None = None,
    musiq_status: str | None = None,
) -> dict[str, Any]:
    """Build experimental observations from hybrid measurements.

    MUSIQ is recorded as context only and never drives criterion text.
    """
    observations: list[dict[str, Any]] = []
    q = criteria_q or {}
    raw = criteria_raw or {}
    color = color or {}

    # --- Focus axis: emit sharpness; suppress blur issue duplicates ---
    sharp_q = q.get("sharpness")
    blur_q = q.get("blur")
    if sharp_q is None:
        observations.append(
            _unavailable_observation("sharpness", reason="missing criteria_q.sharpness")
        )
    else:
        band = band_from_q(float(sharp_q))
        assert band is not None
        observations.append(
            _observation_from_band(
                criterion="sharpness",
                band=band,
                raw_measurement=raw.get("sharpness_laplacian_var"),
                q_value=float(sharp_q),
                kind="q",
            )
        )

    if blur_q is None:
        observations.append(
            _unavailable_observation("blur", reason="missing criteria_q.blur")
        )
    else:
        band = band_from_q(float(blur_q))
        assert band is not None
        blur_obs = _observation_from_band(
            criterion="blur",
            band=band,
            raw_measurement=raw.get("blur_inv_laplacian"),
            q_value=float(blur_q),
            kind="q",
        )
        # Always suppress blur issue/no_issue text when sharpness was scored on the
        # same axis (including when bands match). Keeps one focus message.
        if sharp_q is not None:
            blur_obs = _suppress_as_duplicate(
                blur_obs,
                reason=(
                    "shared_laplacian_axis_with_sharpness; "
                    f"sharpness_q={float(sharp_q):.4f} blur_q={float(blur_q):.4f}"
                ),
            )
        observations.append(blur_obs)

    for criterion in ("brightness", "contrast", "blocking_artifacts"):
        val = q.get(criterion)
        if val is None:
            observations.append(
                _unavailable_observation(criterion, reason=f"missing criteria_q.{criterion}")
            )
            continue
        band = band_from_q(float(val))
        assert band is not None
        observations.append(
            _observation_from_band(
                criterion=criterion,
                band=band,
                raw_measurement=raw.get(RAW_KEYS[criterion]),
                q_value=float(val),
                kind="q",
            )
        )

    for criterion in COLOR_CRITERIA:
        block = color.get(criterion) if isinstance(color.get(criterion), dict) else {}
        available = bool(block.get("available"))
        badge = block.get("badge")
        band = band_from_color_badge(
            int(badge) if badge is not None else None,
            available=available,
        )
        if band == "unavailable" or band is None:
            observations.append(
                _unavailable_observation(
                    criterion,
                    reason=block.get("estimate_kind")
                    or "color heuristic unavailable (mono/extreme exposure gate)",
                )
            )
            continue
        observations.append(
            _observation_from_band(
                criterion=criterion,
                band=band,
                raw_measurement=badge,
                q_value=None,
                kind="color",
            )
        )

    issue_obs = [
        o
        for o in observations
        if o.get("observation_kind") == "issue" and not o.get("suppressed")
    ]
    summary_parts = [o["observation"] for o in issue_obs]
    experimental_summary = (
        " ".join(summary_parts)
        if summary_parts
        else "No hybrid criterion issues were flagged by research rules."
    )

    return {
        "feedback_ruleset_version": FEEDBACK_RULESET_VERSION,
        "research_only": True,
        "production_feedback_mutated": False,
        "musiq_excluded_from_criterion_feedback": True,
        "musiq_context": {
            "musiq_opq_raw": musiq_opq_raw,
            "musiq_status": musiq_status,
            "note": (
                "MUSIQ overall perceptual quality is logged separately and is not used "
                "to generate criterion observations."
            ),
        },
        "observations": observations,
        "issue_count": len(issue_obs),
        "experimental_summary": experimental_summary,
        "disclaimer": (
            "Experimental research feedback. Not independently validated. "
            "Not shown to members or admins."
        ),
    }
