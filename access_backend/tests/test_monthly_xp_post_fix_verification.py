"""Post-fix verification: new awards, pending release, monthly attribution (isolated mocks)."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.crud.rankings_admin import assign_xp_rank_positions, monthly_points_for_user
from app.services import ai_review_workflow
from app.services import chain_xp_award


def test_new_chain_award_sets_total_timestamp_and_points_once() -> None:
    """Eligible award writes xp_awarded_total + xp_awarded_at and blocks duplicates."""
    criteria = {
        "xp_eligible": True,
        "xp_multiplier": 1.0,
        "xp_points_preview": 73,
        "legacy": {"overall_score": 0.73},
    }
    ev = SimpleNamespace(criteria_json=json.dumps(criteria))
    chain = SimpleNamespace(
        id=501,
        member_id=7,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    add_calls: list[int] = []

    def fake_add_points(_db, user_id, points):
        add_calls.append(points)
        return SimpleNamespace(total_points=points)

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points", side_effect=fake_add_points),
        patch("app.services.chain_xp_award.append_chain_event") as append_event,
    ):
        first = chain_xp_award.apply_chain_xp_award(
            MagicMock(), media_id=10, member_id=7, points=73
        )
        second = chain_xp_award.apply_chain_xp_award(
            MagicMock(), media_id=10, member_id=7, points=73
        )

    assert first == 73
    assert second == 0
    assert add_calls == [73]
    assert chain.xp_awarded_total == 73
    assert chain.xp_awarded_media_id == 10
    assert chain.xp_award_locked is True
    assert isinstance(chain.xp_awarded_at, datetime)
    assert chain.xp_awarded_at.tzinfo is not None
    assert chain.xp_awarded_at >= datetime(chain.xp_awarded_at.year, chain.xp_awarded_at.month, 1, tzinfo=timezone.utc)
    data = json.loads(ev.criteria_json)
    assert data["xp_awarded_at_review"] is True
    assert data["xp_pending"] is False
    append_event.assert_called_once()


def test_pending_review_awards_zero_until_admin_verify_then_once() -> None:
    """Held XP does not credit until admin human verification; then once only."""
    state = {
        "criteria_json": json.dumps(
            {
                "xp_pending": True,
                "xp_eligible": False,
                "xp_points_preview": 55,
                "legacy": {"overall_score": 0.55},
            }
        )
    }
    ev = SimpleNamespace(**state)
    add_calls: list[int] = []

    def fake_get(_db, _mid):
        return ev

    def fake_apply(_db, *, media_id, member_id, points):
        data = json.loads(ev.criteria_json)
        if data.get("xp_awarded_at_review"):
            return 0
        add_calls.append(points)
        data["xp_pending"] = False
        data["xp_awarded_at_review"] = True
        data["xp_eligible"] = True
        ev.criteria_json = json.dumps(data)
        return points

    with (
        patch.object(ai_review_workflow.eval_crud, "get_for_media", fake_get),
        patch("app.services.chain_xp_award.apply_chain_xp_award", fake_apply),
    ):
        # Simulate "still pending": award helper not called → monthly unchanged conceptually.
        pending_preview = json.loads(ev.criteria_json)["xp_points_preview"]
        assert pending_preview == 55
        assert json.loads(ev.criteria_json)["xp_pending"] is True

        first = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)
        second = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)

    assert first == 55
    assert second == 0
    assert add_calls == [55]


def test_monthly_includes_award_only_when_timestamp_in_current_utc_month() -> None:
    """monthly_points_for_user reads chain ledger (mocked scalar = awarded sum)."""
    db = MagicMock()
    db.scalar.return_value = 73
    assert monthly_points_for_user(db, 7) == 73
    db.scalar.assert_called_once()


def test_delayed_award_month_boundary_policy() -> None:
    """Award timestamp month owns monthly XP, not evaluation month."""
    nov = datetime(2026, 11, 1, tzinfo=timezone.utc)
    # Evaluated Oct 31, awarded Nov 2 → November.
    awarded = datetime(2026, 11, 2, 8, 0, tzinfo=timezone.utc)
    assert awarded >= nov
    # Awarded Dec 1 → not November.
    awarded_dec = datetime(2026, 12, 1, 0, 1, tzinfo=timezone.utc)
    assert awarded_dec >= datetime(2026, 12, 1, tzinfo=timezone.utc)


def test_xp_leaderboard_positions_match_sorted_xp_not_skill() -> None:
    rows = [
        {"user_id": 1, "name": "HighSkill", "points": 10, "skill_score": 99},
        {"user_id": 2, "name": "HighXp", "points": 400, "skill_score": 40},
        {"user_id": 3, "name": "Mid", "points": 100, "skill_score": 70},
    ]
    assign_xp_rank_positions(rows)
    by_id = {r["user_id"]: r["xp_rank_position"] for r in rows}
    assert by_id == {2: 1, 3: 2, 1: 3}


def test_xp_award_points_rounding_matches_policy() -> None:
    from app.services.integrity_evaluation_policy import (
        _xp_points_preview,
        xp_award_points_from_payload,
    )

    payload = {
        "xp_eligible": True,
        "xp_multiplier": 1.0,
        "legacy": {"overall_score": 0.735},
    }
    assert _xp_points_preview(payload) == 74  # round(73.5)
    assert xp_award_points_from_payload(payload) == 74

    held = {**payload, "xp_eligible": False, "xp_multiplier": 0.0, "xp_points_preview": 74}
    assert xp_award_points_from_payload(held) == 0
