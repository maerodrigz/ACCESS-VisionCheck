"""Future XP award tracking: missing-chain recovery, idempotency, pending, failures."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.models.media_constants import MEDIA_CATEGORY_EVALUATION, MEDIA_CATEGORY_EVENT
from app.services import chain_xp_award


def _eval(criteria: dict) -> SimpleNamespace:
    return SimpleNamespace(criteria_json=json.dumps(criteria))


def test_normal_chain_award_records_amount_timestamp_member_and_event() -> None:
    criteria = {"xp_pending": True, "xp_points_preview": 61, "xp_eligible": True}
    ev = _eval(criteria)
    chain = SimpleNamespace(
        id=9,
        member_id=0,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    events: list[dict] = []

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points") as add_points,
        patch(
            "app.services.chain_xp_award.append_chain_event",
            side_effect=lambda *args, **kw: events.append(dict(kw)),
        ),
    ):
        awarded = chain_xp_award.apply_chain_xp_award(
            MagicMock(), media_id=100, member_id=42, points=61
        )

    assert awarded == 61
    assert chain.xp_awarded_total == 61
    assert chain.xp_awarded_media_id == 100
    assert chain.member_id == 42
    assert isinstance(chain.xp_awarded_at, datetime)
    assert chain.xp_awarded_at.tzinfo is not None
    add_points.assert_called_once()
    assert events and events[0]["event_type"] == "chain_xp_awarded"
    assert events[0]["payload"]["member_id"] == 42
    assert events[0]["payload"]["points"] == 61
    data = json.loads(ev.criteria_json)
    assert data["xp_awarded_at_review"] is True
    assert data["xp_chain_id"] == 9


def test_missing_chain_recovers_via_ensure_then_tracks_award() -> None:
    criteria = {"xp_eligible": True, "xp_points_preview": 50}
    ev = _eval(criteria)
    media = SimpleNamespace(
        id=55,
        media_category=MEDIA_CATEGORY_EVALUATION,
        replaces_media_id=None,
        uploaded_by=7,
        submission_chain_id=None,
    )
    created = SimpleNamespace(
        id=77,
        member_id=7,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    db = MagicMock()
    db.get.return_value = media

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=None),
        patch(
            "app.services.chain_xp_award.ensure_submission_chain_for_evaluation",
            return_value=created,
        ) as ensure,
        patch("app.services.chain_xp_award.lock_chain", return_value=created),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points"),
        patch("app.services.chain_xp_award.append_chain_event"),
    ):
        awarded = chain_xp_award.apply_chain_xp_award(
            db, media_id=55, member_id=7, points=50
        )

    assert awarded == 50
    ensure.assert_called_once()
    assert created.xp_awarded_total == 50
    assert created.xp_awarded_at is not None


def test_missing_chain_ensure_creates_when_ensure_returns_none_for_evaluation() -> None:
    criteria = {"xp_eligible": True, "xp_points_preview": 40}
    ev = _eval(criteria)
    media = MagicMock()
    media.id = 88
    media.media_category = MEDIA_CATEGORY_EVALUATION
    media.replaces_media_id = None
    media.uploaded_by = 3
    media.submission_chain_id = None

    created_holder: dict = {}

    def fake_add(obj):
        created_holder["chain"] = obj
        obj.id = 901
        obj.xp_award_locked = False
        obj.xp_awarded_total = 0
        obj.xp_awarded_media_id = None
        obj.xp_awarded_at = None

    db = MagicMock()
    db.get.return_value = media
    db.add.side_effect = fake_add
    db.flush.side_effect = lambda: None

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=None),
        patch(
            "app.services.chain_xp_award.ensure_submission_chain_for_evaluation",
            return_value=None,
        ),
        patch(
            "app.services.chain_xp_award.lock_chain",
            side_effect=lambda _db, cid: created_holder["chain"],
        ),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points"),
        patch("app.services.chain_xp_award.append_chain_event"),
    ):
        awarded = chain_xp_award.apply_chain_xp_award(
            db, media_id=88, member_id=3, points=40
        )

    assert awarded == 40
    chain = created_holder["chain"]
    assert chain.root_media_id == 88
    assert chain.member_id == 3
    assert chain.xp_awarded_total == 40
    assert chain.xp_awarded_at is not None
    assert media.submission_chain_id == 901


def test_duplicate_award_attempt_blocked() -> None:
    chain = SimpleNamespace(
        id=1,
        member_id=2,
        xp_award_locked=True,
        xp_awarded_total=40,
        xp_awarded_media_id=5,
        xp_awarded_at=datetime.now(timezone.utc),
    )
    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.ranking_crud.add_points") as add_points,
    ):
        assert (
            chain_xp_award.apply_chain_xp_award(
                MagicMock(), media_id=5, member_id=2, points=40
            )
            == 0
        )
    add_points.assert_not_called()


def test_criteria_already_awarded_blocks_even_if_chain_unlocked() -> None:
    chain = SimpleNamespace(
        id=1,
        member_id=2,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    ev = _eval({"xp_awarded_at_review": True, "xp_points_preview": 40})
    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points") as add_points,
    ):
        assert (
            chain_xp_award.apply_chain_xp_award(
                MagicMock(), media_id=5, member_id=2, points=40
            )
            == 0
        )
    add_points.assert_not_called()


def test_add_points_failure_clears_chain_ledger_markers() -> None:
    chain = SimpleNamespace(
        id=3,
        member_id=2,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    ev = _eval({"xp_eligible": True, "xp_points_preview": 22})
    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch(
            "app.services.chain_xp_award.ranking_crud.add_points",
            side_effect=RuntimeError("db down"),
        ),
        patch("app.services.chain_xp_award.append_chain_event") as append_event,
    ):
        with pytest.raises(RuntimeError, match="db down"):
            chain_xp_award.apply_chain_xp_award(
                MagicMock(), media_id=11, member_id=2, points=22
            )

    assert chain.xp_awarded_total == 0
    assert chain.xp_awarded_at is None
    assert chain.xp_award_locked is False
    data = json.loads(ev.criteria_json)
    assert data.get("xp_awarded_at_review") is False
    append_event.assert_not_called()


def test_event_media_without_chain_uses_legacy_not_forced_chain() -> None:
    media = MagicMock()
    media.id = 1
    media.media_category = MEDIA_CATEGORY_EVENT
    media.replaces_media_id = None
    media.uploaded_by = 9
    ev = _eval({"xp_eligible": True})

    db = MagicMock()
    db.get.return_value = media

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=None),
        patch(
            "app.services.chain_xp_award.ensure_submission_chain_for_evaluation",
            return_value=None,
        ),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points") as add_points,
    ):
        awarded = chain_xp_award.apply_chain_xp_award(
            db, media_id=1, member_id=9, points=10
        )

    assert awarded == 10
    add_points.assert_called_once()
    data = json.loads(ev.criteria_json)
    assert data.get("xp_award_path") == "legacy_untracked"
    assert data.get("xp_awarded_at")


def test_month_boundary_award_timestamp_is_utc_now() -> None:
    chain = SimpleNamespace(
        id=4,
        member_id=1,
        xp_award_locked=False,
        xp_awarded_total=0,
        xp_awarded_media_id=None,
        xp_awarded_at=None,
    )
    ev = _eval({"xp_eligible": True})
    fixed = datetime(2026, 12, 1, 0, 5, tzinfo=timezone.utc)

    with (
        patch("app.services.chain_xp_award.get_chain_for_media", return_value=chain),
        patch("app.services.chain_xp_award.lock_chain", return_value=chain),
        patch("app.services.chain_xp_award.eval_crud.get_for_media", return_value=ev),
        patch("app.services.chain_xp_award.ranking_crud.add_points"),
        patch("app.services.chain_xp_award.append_chain_event"),
        patch("app.services.chain_xp_award.datetime") as dt_mod,
    ):
        dt_mod.now.return_value = fixed
        awarded = chain_xp_award.apply_chain_xp_award(
            MagicMock(), media_id=1, member_id=1, points=15
        )

    assert awarded == 15
    assert chain.xp_awarded_at == fixed
