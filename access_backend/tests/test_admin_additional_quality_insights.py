"""Admin API serializes supplementary quality insights from stored criteria_json."""

from __future__ import annotations

import json

from app.api.routes import admin as admin_routes


def test_extract_additional_quality_insights_from_criteria() -> None:
    criteria = {
        "media_type": "video",
        "additional_quality_insights": {
            "feedback_only": True,
            "color_balance": {
                "status": "neutral",
                "headline": "Balanced",
                "feedback": "Sampled frames look balanced.",
            },
            "motion_stability": {
                "status": "stable_smooth",
                "headline": "Stable / Smooth Motion",
                "feedback": "Motion looks steady.",
            },
        },
    }
    block = admin_routes._additional_quality_insights_from_criteria_json(json.dumps(criteria))
    assert block is not None
    assert block["motion_stability"]["status"] == "stable_smooth"


def test_extract_returns_none_when_missing() -> None:
    assert admin_routes._additional_quality_insights_from_criteria_json(None) is None
    assert admin_routes._additional_quality_insights_from_criteria_json("{}") is None
