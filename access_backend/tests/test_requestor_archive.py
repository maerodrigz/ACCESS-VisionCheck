"""Requestor archive/restore visibility preference (not workflow status)."""

from datetime import date, datetime, timezone
from types import SimpleNamespace

import pytest

from app.crud import documentation_request as req_crud


class _FakeDb:
    def __init__(self):
        self.committed = False

    def commit(self):
        self.committed = True

    def refresh(self, row):
        return row


def _row(*, status: str, archived: datetime | None = None):
    return SimpleNamespace(
        id=7,
        status=status,
        requestor_archived_at=archived,
    )


def test_requestor_archive_completed_sets_timestamp():
    db = _FakeDb()
    row = _row(status="completed")
    out = req_crud.requestor_archive_request(db, row)
    assert out.requestor_archived_at is not None
    assert db.committed is True


def test_requestor_archive_rejected_allowed():
    db = _FakeDb()
    row = _row(status="rejected")
    out = req_crud.requestor_archive_request(db, row)
    assert out.requestor_archived_at is not None


def test_requestor_archive_pending_rejected():
    db = _FakeDb()
    row = _row(status="pending")
    with pytest.raises(ValueError, match="completed or declined"):
        req_crud.requestor_archive_request(db, row)
    assert db.committed is False


def test_requestor_archive_idempotent():
    db = _FakeDb()
    stamped = datetime(2026, 1, 1, tzinfo=timezone.utc)
    row = _row(status="completed", archived=stamped)
    out = req_crud.requestor_archive_request(db, row)
    assert out.requestor_archived_at == stamped
    assert db.committed is False


def test_requestor_restore_clears_timestamp():
    db = _FakeDb()
    row = _row(
        status="completed",
        archived=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )
    out = req_crud.requestor_restore_request(db, row)
    assert out.requestor_archived_at is None
    assert db.committed is True


def test_requestor_restore_idempotent():
    db = _FakeDb()
    row = _row(status="completed", archived=None)
    out = req_crud.requestor_restore_request(db, row)
    assert out.requestor_archived_at is None
    assert db.committed is False


def test_admin_archive_still_completed_only():
    db = _FakeDb()
    row = SimpleNamespace(id=1, status="rejected", archived_at=None)
    with pytest.raises(ValueError, match="Only completed"):
        req_crud.archive_request(db, row)
