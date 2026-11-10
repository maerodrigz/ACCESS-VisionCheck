"""Member-aligned quality display (1–5 and percent). Does not change stored DB polarity."""

from __future__ import annotations

import json
from typing import Any

# Member app: high 1–5 = better quality for every listed criterion, including Noise and Blur.
QUALITY_CRITERION_NAMES = (
    "Sharpness",
    "Blur",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Color Balance",
    "Color Saturation",
    "Flickering",
    "Motion Stability",
    # Historical names (still displayed when present in older criteria_json).
    "Noise",
    "Ringing Artifacts",
)

# media_evaluations.noise_score is stored as 1 - (Noise / 5). Other columns are criterion/5.
DB_INVERTED_QUALITY_COLUMNS = frozenset({"noise_score"})


def parse_criteria_json(raw: str | None) -> dict[str, Any] | None:
    if not raw or not str(raw).strip():
        return None
    try:
        data = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def evaluation_failed(payload: dict[str, Any] | None) -> bool:
    if not payload:
        return False
    status = str(payload.get("evaluation_status") or "").strip().lower()
    if status in {"failed", "unavailable", "error"}:
        return True
    return payload.get("evaluation_available") is False


def score_1_5_to_percent(score: float) -> float:
    return round(max(0.0, min(5.0, float(score))) / 5.0 * 1000) / 10


def quality_01_to_percent(value: float) -> float:
    return round(max(0.0, min(1.0, float(value))) * 1000) / 10


def noise_db_to_quality_01(noise_score: float | None) -> float | None:
    """Convert stored noise_score (high = more noise) to quality 0–1 (high = cleaner)."""
    if noise_score is None:
        return None
    return max(0.0, min(1.0, 1.0 - float(noise_score)))


def criteria_by_name(payload: dict[str, Any] | None) -> dict[str, int]:
    out: dict[str, int] = {}
    if not payload:
        return out
    rows = payload.get("criteria")
    if not isinstance(rows, list):
        return out
    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("available") is False:
            continue
        name = str(row.get("name") or "").strip()
        if not name:
            continue
        try:
            score = int(row.get("score"))
        except (TypeError, ValueError):
            continue
        if 1 <= score <= 5:
            out[name] = score
    return out


def quality_display_from_evaluation(
    *,
    criteria_json: str | None,
    sharpness_score: float | None = None,
    brightness_score: float | None = None,
    contrast_score: float | None = None,
    blur_score: float | None = None,
    noise_score: float | None = None,
    overall_score: float | None = None,
) -> dict[str, Any]:
    payload = parse_criteria_json(criteria_json)
    if evaluation_failed(payload):
        payload = payload or {}
        return {
            "available": False,
            "status": str(payload.get("evaluation_status") or "failed"),
            "criteria": [],
            "overall_percent": None,
            "quality_engine": None,
            "opencv_fallback": False,
        }

    by_name = criteria_by_name(payload)
    analysis = (
        payload.get("analysis")
        if isinstance(payload, dict) and isinstance(payload.get("analysis"), dict)
        else {}
    )
    criteria_out: list[dict[str, Any]] = []
    raw_rows = (
        payload.get("criteria")
        if isinstance(payload, dict) and isinstance(payload.get("criteria"), list)
        else []
    )
    raw_by_name = {
        str(r.get("name")): r
        for r in raw_rows
        if isinstance(r, dict) and str(r.get("name") or "").strip()
    }
    if by_name or raw_by_name:
        for name in QUALITY_CRITERION_NAMES:
            row = raw_by_name.get(name)
            if row is not None and row.get("available") is False:
                criteria_out.append(
                    {
                        "name": name,
                        "score": None,
                        "percent": None,
                        "higher_is_better": True,
                        "available": False,
                        "label": "N/A",
                    }
                )
                continue
            if name not in by_name:
                continue
            score = by_name[name]
            criteria_out.append(
                {
                    "name": name,
                    "score": score,
                    "percent": score_1_5_to_percent(score),
                    "higher_is_better": True,
                    "available": True,
                }
            )
        overall_percent = None
        raw_overall = payload.get("overall_score")
        if isinstance(raw_overall, (int, float)) and float(raw_overall) > 0:
            overall_percent = score_1_5_to_percent(float(raw_overall))
        elif isinstance(overall_score, (int, float)) and float(overall_score) > 0:
            o = float(overall_score)
            overall_percent = score_1_5_to_percent(o) if o > 1 else quality_01_to_percent(o)
        return {
            "available": True,
            "status": "ok",
            "criteria": criteria_out,
            "overall_percent": overall_percent,
            "quality_engine": analysis.get("quality_engine"),
            "opencv_fallback": bool(analysis.get("opencv_fallback")),
        }

    if all(v is None for v in (sharpness_score, brightness_score, contrast_score, blur_score, noise_score, overall_score)):
        return {
            "available": False,
            "status": "unavailable",
            "criteria": [],
            "overall_percent": None,
            "quality_engine": None,
            "opencv_fallback": False,
        }

    col_map = [
        ("Sharpness", sharpness_score, False),
        ("Blur", blur_score, False),
        ("Noise", noise_score, True),
        ("Brightness", brightness_score, False),
        ("Contrast", contrast_score, False),
    ]
    for name, raw, inverted in col_map:
        if raw is None:
            continue
        quality_01 = noise_db_to_quality_01(raw) if inverted else max(0.0, min(1.0, float(raw)))
        if quality_01 is None:
            continue
        criteria_out.append(
            {
                "name": name,
                "score": int(round(quality_01 * 5)) or None,
                "percent": quality_01_to_percent(quality_01),
                "higher_is_better": True,
            }
        )
    overall_percent = None
    if overall_score is not None:
        o = float(overall_score)
        overall_percent = score_1_5_to_percent(o) if o > 1 else quality_01_to_percent(o)
    return {
        "available": True,
        "status": "ok",
        "criteria": criteria_out,
        "overall_percent": overall_percent,
        "quality_engine": None,
        "opencv_fallback": False,
    }


def failed_evaluation_payload(*, media_type: str, reason: str) -> dict[str, Any]:
    return {
        "evaluation_status": "failed",
        "evaluation_available": False,
        "media_type": media_type,
        "criteria": [],
        "overall_score": None,
        "quality_level": None,
        "recommendation": None,
        "ai_feedback": reason,
        "scoring_engine": None,
        "scoring_model": None,
        "xp_eligible": False,
        "xp_multiplier": 0.0,
        "analysis": {
            "quality_engine": None,
            "opencv_fallback": False,
            "failed": True,
            "fail_reason": reason,
        },
    }
