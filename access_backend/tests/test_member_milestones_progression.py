"""Tier milestone notifications respect progression policy and computed tier changes."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.services import member_milestones as milestones


def test_eval_gate_keys_differ_by_policy(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.skill_progression.active_skill_progression_policy",
        lambda: "v1",
    )
    assert milestones._eval_gate_milestone_key(6) == "6"
    monkeypatch.setattr(
        "app.services.skill_progression.active_skill_progression_policy",
        lambda: "v2",
    )
    assert milestones._eval_gate_milestone_key(12) == "v2:12"


def test_skill_tier_notification_uses_computed_not_override_only() -> None:
    db = MagicMock()
    with patch.object(milestones, "_award") as award:
        milestones.on_skill_level_recalculated(
            db,
            1,
            old_level="Beginner",
            new_level="Advanced",
            old_computed_tier="Beginner",
            new_computed_tier="Beginner",
        )
        award.assert_not_called()


def test_skill_tier_notification_on_computed_promotion() -> None:
    db = MagicMock()
    with patch.object(milestones, "_award") as award:
        milestones.on_skill_level_recalculated(
            db,
            1,
            old_level="Intermediate",
            new_level="Advanced",
            old_computed_tier="Intermediate",
            new_computed_tier="Advanced",
        )
        award.assert_called_once()
        assert award.call_args.kwargs["milestone_key"] == "Advanced"
