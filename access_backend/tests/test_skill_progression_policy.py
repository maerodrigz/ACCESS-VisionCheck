"""Balanced skill progression policy v2 (inactive in production by default)."""

from __future__ import annotations

from datetime import date, datetime, timezone
from unittest.mock import MagicMock, patch
from zoneinfo import ZoneInfo

from app.services.skill_evaluation_eligibility import (
    eligible_upload_calendar_date,
    practice_evaluation_eligible_for_skill,
)
from app.services.skill_progression import build_skill_progression_snapshot
from app.services.skill_progression_policy import (
    POLICY_V2,
    V2_TIER_REQUIREMENTS,
    apply_grandfather_floor_v2,
    balanced_skill_tier_v2,
    next_tier_progress_v2,
)


def test_balanced_intermediate_requires_three_evals_two_days() -> None:
    assert (
        balanced_skill_tier_v2(skill_score_pct=65, eligible_count=3, distinct_upload_days=2)
        == "Intermediate"
    )
    assert (
        balanced_skill_tier_v2(skill_score_pct=65, eligible_count=3, distinct_upload_days=1)
        == "Beginner"
    )


def test_balanced_advanced_requires_twelve_evals_ten_days() -> None:
    assert (
        balanced_skill_tier_v2(skill_score_pct=80, eligible_count=12, distinct_upload_days=10)
        == "Advanced"
    )
    assert (
        balanced_skill_tier_v2(skill_score_pct=80, eligible_count=12, distinct_upload_days=9)
        == "Intermediate"
    )


def test_balanced_expert_requires_twenty_four_each() -> None:
    assert (
        balanced_skill_tier_v2(skill_score_pct=92, eligible_count=24, distinct_upload_days=24)
        == "Expert"
    )
    assert (
        balanced_skill_tier_v2(skill_score_pct=92, eligible_count=24, distinct_upload_days=23)
        == "Advanced"
    )


def test_high_quality_insufficient_count_stays_beginner() -> None:
    assert (
        balanced_skill_tier_v2(skill_score_pct=95, eligible_count=2, distinct_upload_days=2)
        == "Beginner"
    )


def test_grandfather_floor_when_quality_supports_tier() -> None:
    computed = balanced_skill_tier_v2(skill_score_pct=85, eligible_count=5, distinct_upload_days=5)
    assert computed == "Intermediate"
    floored = apply_grandfather_floor_v2(
        computed_v2=computed,
        grandfather_floor="Advanced",
        skill_score_pct=85,
    )
    assert floored == "Advanced"


def test_grandfather_does_not_block_quality_demotion() -> None:
    computed = balanced_skill_tier_v2(skill_score_pct=55, eligible_count=20, distinct_upload_days=20)
    floored = apply_grandfather_floor_v2(
        computed_v2=computed,
        grandfather_floor="Expert",
        skill_score_pct=55,
    )
    assert floored == "Beginner"


def test_manila_upload_calendar_date_boundary() -> None:
    utc_late = datetime(2026, 6, 1, 18, 30, tzinfo=timezone.utc)
    with patch("app.services.skill_evaluation_eligibility.settings") as mock_settings:
        mock_settings.evaluation_daily_timezone = "Asia/Manila"
        assert eligible_upload_calendar_date(utc_late) == date(2026, 6, 2)


def test_pending_review_not_eligible() -> None:
    assert not practice_evaluation_eligible_for_skill(
        criteria_json='{"member_scores_released": false}',
        review_status="pending_review",
        overall_score=0.8,
    )


def test_next_tier_progress_v2_remaining() -> None:
    p = next_tier_progress_v2(
        skill_score_pct=70,
        eligible_count=2,
        distinct_upload_days=1,
        current_effective_tier="Beginner",
    )
    assert p.next_tier_name == "Intermediate"
    assert p.remaining_eligible_evaluations == 1
    assert p.remaining_distinct_upload_days == 1


def test_snapshot_uses_v1_when_policy_v1(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.skill_progression.active_skill_progression_policy",
        lambda: "v1",
    )
    db = MagicMock()
    with patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        return_value=MagicMock(count=12, average_score=0.8, distinct_upload_days=10),
    ):
        db.scalar.return_value = None
        snap = build_skill_progression_snapshot(db, 1)
    assert snap.policy_version == "v1"
    assert snap.computed_tier_active == snap.computed_tier_v1
    assert snap.next_tier_required_days is None
    assert snap.computed_tier_v2 != snap.computed_tier_v1 or snap.computed_tier_v1 == "Advanced"
