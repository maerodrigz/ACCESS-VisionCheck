"""Admin competency override vs four-level member skill tiers.

Isolate from local SKILL_PROGRESSION_ACTIVE_POLICY / MagicMock DB activation seals.
Override behavior is policy-agnostic; computed Expert uses v1 gates (score + count).
"""

from unittest.mock import MagicMock, patch

from app.crud.rankings_admin import resolve_member_skill_level

_ELIGIBLE = MagicMock(count=10, distinct_upload_days=10, average_score=0.92)


def _db() -> MagicMock:
    db = MagicMock()
    db.scalar.return_value = None
    return db


def test_override_caps_display_not_expert_band() -> None:
    skill_payload = {
        "skill_score": 92.0,
        "skill_level": "Expert",
        "media_quality_score": 92.0,
        "ai_authenticity_score": 100.0,
    }
    with patch(
        "app.services.skill_progression.resolve_effective_skill_progression_policy",
        return_value=("v1", None),
    ), patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        return_value=_ELIGIBLE,
    ):
        effective, recommended, computed = resolve_member_skill_level(
            _db(),
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
    with patch(
        "app.services.skill_progression.resolve_effective_skill_progression_policy",
        return_value=("v1", None),
    ), patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        return_value=_ELIGIBLE,
    ):
        effective, recommended, computed = resolve_member_skill_level(
            _db(),
            1,
            skill_payload=skill_payload,
            evaluation_count=10,
            level_override=None,
        )
    assert computed == "Expert"
    assert effective == "Expert"
    assert recommended == "Advanced"
