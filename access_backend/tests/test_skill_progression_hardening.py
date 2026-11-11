"""Integration hardening for skill progression v1/v2 (v2 inactive by default)."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.skill_progression import (
    build_skill_progression_snapshot,
    resolve_effective_skill_progression_policy,
)
from app.services.skill_progression_policy import configured_skill_progression_policy
from app.services.skill_progression_grandfather import (
    grandfather_snapshots_complete,
    members_missing_grandfather_snapshot,
)
from app.services.skill_progression_policy import (
    POLICY_V1,
    POLICY_V2,
    next_tier_progress_for_policy,
    next_tier_progress_v1,
)


def test_configured_policy_defaults_v1(monkeypatch) -> None:
    from app.config import settings

    monkeypatch.setattr(settings, "skill_progression_active_policy", "v1")
    assert configured_skill_progression_policy() == POLICY_V1


def test_v1_next_tier_progress_has_no_day_requirement() -> None:
    p = next_tier_progress_v1(
        skill_score_pct=70,
        eligible_count=2,
        current_effective_tier="Beginner",
    )
    assert p.next_tier_name == "Intermediate"
    assert p.required_distinct_upload_days is None
    assert p.remaining_distinct_upload_days == 0
    assert p.remaining_eligible_evaluations == 1


def test_next_tier_for_policy_v1_vs_v2() -> None:
    v1 = next_tier_progress_for_policy(
        POLICY_V1,
        skill_score_pct=80,
        eligible_count=5,
        distinct_upload_days=5,
        current_effective_tier="Intermediate",
    )
    v2 = next_tier_progress_for_policy(
        POLICY_V2,
        skill_score_pct=80,
        eligible_count=5,
        distinct_upload_days=5,
        current_effective_tier="Intermediate",
    )
    assert v1.required_eligible_evaluations == 6
    assert v1.required_distinct_upload_days is None
    assert v2.required_eligible_evaluations == 12
    assert v2.required_distinct_upload_days == 10


def test_snapshot_v1_uses_v1_progress_fields(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.skill_progression.configured_skill_progression_policy",
        lambda: POLICY_V1,
    )
    db = MagicMock()
    with patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        return_value=MagicMock(count=2, average_score=0.7, distinct_upload_days=1),
    ):
        with patch(
            "app.services.skill_progression.resolve_effective_skill_progression_policy",
            return_value=(POLICY_V1, None),
        ):
            db.scalar.return_value = None
            snap = build_skill_progression_snapshot(db, 1)
    assert snap.policy_version == POLICY_V1
    assert snap.next_tier_required_days is None
    assert snap.remaining_distinct_upload_days == 0


def test_v2_env_blocked_without_activation_seal(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    db = MagicMock()
    with patch(
        "app.services.skill_progression_v2_activation.get_sealed_activation",
        return_value=None,
    ):
        policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V1
    assert reason is not None
    assert "sealed" in reason.lower()


def test_build_snapshot_fails_open_to_v1_when_v2_blocked(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    db = MagicMock()
    with patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        return_value=MagicMock(count=12, average_score=0.85, distinct_upload_days=10),
    ):
        with patch(
            "app.services.skill_progression.resolve_effective_skill_progression_policy",
            return_value=(
                POLICY_V1,
                "snapshots incomplete",
            ),
        ):
            db.scalar.return_value = None
            snap = build_skill_progression_snapshot(db, 1)
    assert snap.configured_policy_version == POLICY_V2
    assert snap.policy_version == POLICY_V1
    assert snap.v2_activation_blocked_reason == "snapshots incomplete"
    assert snap.computed_tier_active == snap.computed_tier_v1


def test_grandfather_missing_includes_admin_override_without_floor() -> None:
    db = MagicMock()
    ranking = MagicMock()
    ranking.competency_level_override = "Advanced"
    ranking.skill_tier_grandfather_floor = None
    user = MagicMock(id=5)
    db.scalars.return_value.all.return_value = [user]
    db.scalar.return_value = ranking
    with patch(
        "app.services.skill_progression_v2_activation.get_sealed_activation",
        return_value=None,
    ):
        missing = members_missing_grandfather_snapshot(db)
    assert missing == [5]


def test_grandfather_snapshots_complete_empty_when_all_captured() -> None:
    db = MagicMock()
    with patch(
        "app.services.skill_progression_v2_activation.get_sealed_activation",
        return_value=MagicMock(id=1),
    ), patch(
        "app.services.skill_progression_v2_activation.protected_cohort_members_missing_floors",
        return_value=[],
    ):
        assert grandfather_snapshots_complete(db) is True
