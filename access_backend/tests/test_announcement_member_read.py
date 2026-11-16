"""Per-member announcement read stamps + 24h expiry filtering."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from sqlalchemy.exc import IntegrityError

from app.crud import announcement as announcement_crud
from app.crud import announcement_member_read as read_crud
from app.models.announcement import Announcement
from app.models.announcement_member_read import AnnouncementMemberRead


def test_mark_first_read_is_idempotent_and_sets_24h_window() -> None:
    now = datetime(2026, 11, 15, 1, 0, tzinfo=timezone.utc)
    existing = AnnouncementMemberRead(
        id=1,
        announcement_id=9,
        user_id=3,
        first_read_at=now,
        expires_at=now + timedelta(hours=24),
    )

    db = MagicMock()
    db.scalar.return_value = None
    created = read_crud.mark_first_read(db, announcement_id=9, user_id=3)
    assert db.add.called
    stamped = db.add.call_args[0][0]
    assert isinstance(stamped, AnnouncementMemberRead)
    assert stamped.announcement_id == 9
    assert stamped.user_id == 3
    assert stamped.expires_at - stamped.first_read_at == timedelta(hours=24)
    assert created is stamped

    # Second open returns existing without rewriting timestamps.
    db2 = MagicMock()
    db2.scalar.return_value = existing
    again = read_crud.mark_first_read(db2, announcement_id=9, user_id=3)
    assert again.first_read_at == now
    assert again.expires_at == now + timedelta(hours=24)
    db2.add.assert_not_called()


def test_mark_first_read_concurrent_integrity_error_returns_winner() -> None:
    now = datetime(2026, 11, 15, 2, 0, tzinfo=timezone.utc)
    winner = AnnouncementMemberRead(
        id=2,
        announcement_id=4,
        user_id=8,
        first_read_at=now,
        expires_at=now + timedelta(hours=24),
    )
    db = MagicMock()
    db.scalar.side_effect = [None, winner]
    db.commit.side_effect = IntegrityError("stmt", {}, Exception("unique"))

    out = read_crud.mark_first_read(db, announcement_id=4, user_id=8)
    assert out is winner
    assert out.expires_at == now + timedelta(hours=24)
    db.rollback.assert_called()


def test_list_active_hides_expired_keeps_unread() -> None:
    now = datetime.now(timezone.utc)
    unread = Announcement(id=1, title="A", content="x", posted_by=1)
    unread.created_at = now
    unread.poster = None
    fresh = Announcement(id=2, title="B", content="y", posted_by=1)
    fresh.created_at = now
    fresh.poster = None
    expired = Announcement(id=3, title="C", content="z", posted_by=1)
    expired.created_at = now
    expired.poster = None

    db = MagicMock()
    # list_all path uses db.scalars(...); patch list_all via scalar side effects is hard —
    # call list_active with patched helpers.
    reads = {
        2: AnnouncementMemberRead(
            announcement_id=2,
            user_id=5,
            first_read_at=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=23),
        ),
        3: AnnouncementMemberRead(
            announcement_id=3,
            user_id=5,
            first_read_at=now - timedelta(hours=30),
            expires_at=now - timedelta(hours=6),
        ),
    }

    from unittest.mock import patch

    with (
        patch.object(announcement_crud, "list_all", return_value=[unread, fresh, expired]),
        patch.object(read_crud, "reads_for_user", return_value=reads),
    ):
        active = announcement_crud.list_active_for_member(db, user_id=5)
    ids = [a.id for a, _ in active]
    assert ids == [1, 2]
    assert active[0][1] is None
    assert active[1][1] is not None


def test_is_expired_false_when_never_read() -> None:
    db = MagicMock()
    db.scalar.return_value = None
    assert (
        read_crud.is_expired_for_user(db, announcement_id=1, user_id=2) is False
    )


def test_notification_visibility_helper_keeps_other_categories() -> None:
    from app.api.routes.notifications import _announcement_notification_visible

    db = MagicMock()
    n = SimpleNamespace(
        category="task_assignment",
        action_type="view_assignment",
        action_ref_id=9,
    )
    assert _announcement_notification_visible(db, n, user_id=1) is True


def test_notification_visibility_hides_expired_announcement() -> None:
    from app.api.routes.notifications import _announcement_notification_visible
    from unittest.mock import patch

    db = MagicMock()
    n = SimpleNamespace(
        category="announcement",
        action_type="view_announcement",
        action_ref_id=44,
    )
    with patch(
        "app.crud.announcement_member_read.is_expired_for_user",
        return_value=True,
    ):
        assert _announcement_notification_visible(db, n, user_id=7) is False
