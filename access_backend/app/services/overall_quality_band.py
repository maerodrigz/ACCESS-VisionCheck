"""Overall quality labels for the displayed 0–100 score.

Criterion scores stay on the 1–5 scale. This mapping is only for the final
overall score shown to members and administrators.

Poor: 0–59, Fair: 60–74, Good: 75–89, Excellent: 90–100.
"""

from __future__ import annotations


def overall_percent_from_five_point(overall: float) -> int:
    """Convert a 1–5 overall score to the integer percent shown in the UI."""
    percent = int(round((float(overall) / 5.0) * 100))
    return max(0, min(100, percent))


def overall_quality_label_from_percent(percent: int) -> str:
    value = max(0, min(100, int(percent)))
    if value >= 90:
        return "Excellent"
    if value >= 75:
        return "Good"
    if value >= 60:
        return "Fair"
    return "Poor"


def overall_quality_label_from_five_point(overall: float) -> str:
    return overall_quality_label_from_percent(overall_percent_from_five_point(overall))
