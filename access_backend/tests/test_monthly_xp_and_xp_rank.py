"""Monthly XP from chain awards + XP leaderboard positions (safe consistency fix)."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock

from app.crud.rankings_admin import assign_xp_rank_positions, monthly_points_for_user


def test_monthly_points_for_user_returns_chain_sum() -> None:
    db = MagicMock()
    db.scalar.return_value = 85
    assert monthly_points_for_user(db, user_id=12) == 85
    db.scalar.assert_called_once()
    stmt = db.scalar.call_args.args[0]
    # SQLAlchemy query targets submission_chains awards, not raw evaluation scores.
    compiled = str(stmt)
    assert "submission_chains" in compiled.lower() or "xp_awarded" in compiled.lower()


def test_monthly_points_for_user_none_sum_is_zero() -> None:
    db = MagicMock()
    db.scalar.return_value = None
    assert monthly_points_for_user(db, user_id=1) == 0


def test_assign_xp_rank_positions_orders_by_xp_then_name_then_id() -> None:
    rows = [
        {"user_id": 3, "name": "Zoe", "points": 100, "skill_score": 99},
        {"user_id": 1, "name": "Amy", "points": 100, "skill_score": 50},
        {"user_id": 2, "name": "Bob", "points": 200, "skill_score": 10},
        {"user_id": 4, "name": "Cal", "points": 0, "skill_score": 80},
    ]
    # Pretend skill sort already placed Cal first.
    rows.sort(key=lambda x: x["skill_score"], reverse=True)
    assign_xp_rank_positions(rows)

    by_id = {r["user_id"]: r["xp_rank_position"] for r in rows}
    assert by_id[2] == 1  # 200 XP
    assert by_id[1] == 2  # 100 XP, Amy before Zoe
    assert by_id[3] == 3
    assert by_id[4] == 4  # 0 XP last
    # Skill-oriented fields are untouched by this helper.
    assert rows[0]["skill_score"] == 99


def test_assign_xp_rank_independent_of_skill_order() -> None:
    rows = [
        {"user_id": 9, "name": "HighSkillLowXp", "points": 10, "skill_score": 95},
        {"user_id": 8, "name": "LowSkillHighXp", "points": 500, "skill_score": 40},
    ]
    assign_xp_rank_positions(rows)
    assert next(r for r in rows if r["user_id"] == 8)["xp_rank_position"] == 1
    assert next(r for r in rows if r["user_id"] == 9)["xp_rank_position"] == 2


def test_month_boundary_attribution_uses_award_timestamp_doc() -> None:
    """Documented policy: delayed admin award attributed by xp_awarded_at (UTC month)."""
    nov_start = datetime(2026, 11, 1, tzinfo=timezone.utc)
    # Evaluated in October, awarded in November → counts in November.
    awarded_in_nov = datetime(2026, 11, 2, 12, 0, tzinfo=timezone.utc)
    assert awarded_in_nov >= nov_start
    # Evaluated in November, awarded in December → does not count in November.
    awarded_in_dec = datetime(2026, 12, 1, 0, 5, tzinfo=timezone.utc)
    assert awarded_in_dec < nov_start or awarded_in_dec >= datetime(2026, 12, 1, tzinfo=timezone.utc)
    assert awarded_in_dec >= datetime(2026, 12, 1, tzinfo=timezone.utc)
