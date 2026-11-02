"""Admin competency override vs four-level member skill tiers (behavior unchanged)."""

from unittest.mock import MagicMock, patch

from app.crud.rankings_admin import resolve_member_skill_level


def test_override_caps_display_not_expert_band() -> None:
    skill_payload = {
        "skill_score": 92.0,
        "skill_level": "Expert",
        "media_quality_score": 92.0,
        "ai_authenticity_score": 100.0,
    }
    effective, recommended, computed = resolve_member_skill_level(
        MagicMock(),
        1,
        skill_payload=skill_payload,
        evaluation_count=10,
        level_override="Advanced",
    )
    assert computed == "Expert"
    assert recommended == "Advanced"
    assert effective == "Advanced"


def test_no_override_uses_computed_expert() -> None:
    skill_payload = {
        "skill_score": 92.0,
        "skill_level": "Expert",
        "media_quality_score": 92.0,
        "ai_authenticity_score": 100.0,
    }
    effective, recommended, computed = resolve_member_skill_level(
        MagicMock(),
        1,
        skill_payload=skill_payload,
        evaluation_count=10,
        level_override=None,
    )
    assert computed == "Expert"
    assert effective == "Expert"
    assert recommended == "Advanced"
