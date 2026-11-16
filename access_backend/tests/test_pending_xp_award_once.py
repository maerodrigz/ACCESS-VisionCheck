"""Mocked test: pending XP awarded at most once on admin human verification."""

import json
from types import SimpleNamespace

import pytest

from app.services import ai_review_workflow


def test_award_pending_evaluation_xp_only_once(monkeypatch):
    state = {
        "criteria_json": json.dumps(
            {"xp_pending": True, "xp_points_preview": 42, "xp_eligible": False}
        ),
    }
    ev = SimpleNamespace(**state)
    add_calls = []

    def fake_get_for_media(_db, _media_id):
        return ev

    def fake_apply_chain_xp_award(_db, *, media_id, member_id, points):
        data = json.loads(ev.criteria_json)
        if data.get("xp_awarded_at_review"):
            return 0
        add_calls.append(points)
        data["xp_pending"] = False
        data["xp_awarded_at_review"] = True
        ev.criteria_json = json.dumps(data)
        return points

    monkeypatch.setattr(ai_review_workflow.eval_crud, "get_for_media", fake_get_for_media)
    monkeypatch.setattr(
        "app.services.chain_xp_award.apply_chain_xp_award",
        fake_apply_chain_xp_award,
    )

    first = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)
    assert first == 42
    assert len(add_calls) == 1
    data = json.loads(ev.criteria_json)
    assert data["xp_pending"] is False
    assert data["xp_awarded_at_review"] is True

    second = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)
    assert second == 0
    assert len(add_calls) == 1
