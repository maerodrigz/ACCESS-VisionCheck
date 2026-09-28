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

    def fake_add_points(_db, _member_id, points):
        add_calls.append(points)

    monkeypatch.setattr(ai_review_workflow.eval_crud, "get_for_media", fake_get_for_media)
    monkeypatch.setattr(ai_review_workflow.ranking_crud, "add_points", fake_add_points)

    first = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)
    assert first == 42
    assert len(add_calls) == 1
    data = json.loads(ev.criteria_json)
    assert data["xp_pending"] is False
    assert data["xp_awarded_at_review"] is True

    second = ai_review_workflow._award_pending_evaluation_xp(None, 99, 7)
    assert second == 0
    assert len(add_calls) == 1
