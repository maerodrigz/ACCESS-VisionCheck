"""Permanent member deletion: storage order, blocks, and idempotent retry (mocked storage)."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.models.enums import RoleName, UserStatus
from app.services.storage_deletion import StorageDeleteOutcome, StorageDeleteResult


def _member_user(user_id: int = 50) -> MagicMock:
    user = MagicMock()
    user.id = user_id
    user.email = "member@test.local"
    user.role = MagicMock()
    user.role.role_name = RoleName.MEMBER
    user.status = UserStatus.APPROVED
    user.is_active = True
    return user


@patch("app.crud.session.revoke_sessions_for_user")
@patch("app.services.member_permanent_deletion.cleanup_member_assignments", return_value=0)
@patch("app.services.member_permanent_deletion.delete_owned_media_for_user")
def test_permanent_delete_succeeds_when_media_clean(mock_media, mock_assign, mock_revoke) -> None:
    from app.crud import user as user_crud
    from app.services.member_permanent_deletion import PermanentDeletionStats

    mock_media.return_value = PermanentDeletionStats(media_deleted=2, storage_deleted=2)
    user = _member_user()
    db = MagicMock()

    stats = user_crud.permanently_delete_member(db, user, acting_admin_id=1, delete_uploads=True)

    assert stats.media_deleted == 2
    mock_revoke.assert_called_once_with(db, 50)
    db.delete.assert_called_once_with(user)
    db.commit.assert_called()


@patch("app.crud.session.revoke_sessions_for_user")
@patch("app.services.member_permanent_deletion.cleanup_member_assignments", return_value=0)
@patch("app.services.member_permanent_deletion.delete_owned_media_for_user")
def test_permanent_delete_blocked_when_storage_queued(mock_media, mock_assign, mock_revoke) -> None:
    from app.crud import user as user_crud
    from app.services.member_permanent_deletion import PermanentDeletionStats

    mock_media.return_value = PermanentDeletionStats(
        media_failed=1, storage_queued=1, media_deleted=0
    )
    user = _member_user()
    db = MagicMock()

    with pytest.raises(Exception, match="Retry storage cleanup") as ei:
        user_crud.permanently_delete_member(db, user, acting_admin_id=1)

    from app.services.member_permanent_deletion import PermanentDeletionIncompleteError

    assert isinstance(ei.value, PermanentDeletionIncompleteError)
    assert ei.value.stats.storage_queued == 1
    db.delete.assert_not_called()


@patch("app.crud.session.revoke_sessions_for_user")
@patch("app.services.member_permanent_deletion.cleanup_member_assignments", return_value=0)
@patch("app.services.member_permanent_deletion.delete_owned_media_for_user")
def test_permanent_delete_blocked_when_row_fails_without_queue(
    mock_media, mock_assign, mock_revoke
) -> None:
    from app.crud import user as user_crud
    from app.services.member_permanent_deletion import (
        PermanentDeletionIncompleteError,
        PermanentDeletionStats,
    )

    mock_media.return_value = PermanentDeletionStats(
        media_failed=3,
        storage_queued=0,
        storage_deleted=3,
        media_deleted=0,
        row_block_reasons=["media_id=1: linked"],
    )
    user = _member_user()
    db = MagicMock()

    with pytest.raises(PermanentDeletionIncompleteError, match="Do not use storage cleanup retry"):
        user_crud.permanently_delete_member(db, user, acting_admin_id=1)

    db.delete.assert_not_called()


@patch("app.services.member_permanent_deletion.delete_storage_for_file_url")
@patch("app.services.member_permanent_deletion.media_crud.get")
@patch("app.services.member_permanent_deletion.delete_submission_chains_for_member", return_value=1)
def test_delete_owned_media_storage_first_then_row(mock_chains, mock_get, mock_storage) -> None:
    from app.services.member_permanent_deletion import delete_owned_media_for_user

    media = MagicMock()
    media.id = 10
    media.uploaded_by = 50
    media.file_url = "supabase-ref:access-media/path/file.jpg"
    mock_get.return_value = media
    mock_storage.return_value = StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)

    db = MagicMock()

    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[10],
    ), patch(
        "app.services.member_permanent_deletion._clear_root_chain_for_media"
    ), patch("app.services.member_permanent_deletion.media_crud.delete_media_row_only") as mock_row:
        stats = delete_owned_media_for_user(db, 50, include_event_gallery=True)

    mock_storage.assert_called_once_with("supabase-ref:access-media/path/file.jpg")
    mock_row.assert_called_once()
    assert mock_row.call_args.kwargs.get("commit") is False
    assert stats.media_deleted == 1
    assert stats.storage_deleted == 1


@patch("app.services.member_permanent_deletion.delete_storage_for_file_url")
@patch("app.services.member_permanent_deletion.media_crud.get")
@patch("app.services.member_permanent_deletion.delete_submission_chains_for_member", return_value=0)
def test_delete_owned_media_keeps_row_when_storage_fails(mock_chains, mock_get, mock_storage) -> None:
    from app.services.member_permanent_deletion import delete_owned_media_for_user

    media = MagicMock()
    media.id = 11
    media.uploaded_by = 50
    media.file_url = "https://example.supabase.co/storage/v1/object/public/b/x"
    mock_get.return_value = media
    mock_storage.return_value = StorageDeleteResult(
        outcome=StorageDeleteOutcome.FAILED,
        error="network",
        bucket="b",
        object_path="x",
    )

    db = MagicMock()
    db.scalar.return_value = None

    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[11],
    ), patch("app.services.member_permanent_deletion.media_crud.delete_media_row_only") as mock_row:
        stats = delete_owned_media_for_user(db, 50, include_event_gallery=True)

    mock_row.assert_not_called()
    assert stats.storage_queued == 1
    assert stats.media_failed == 1
    db.add.assert_called()


@patch("app.services.member_permanent_deletion.delete_storage_for_file_url")
@patch("app.services.member_permanent_deletion.media_crud.get")
@patch("app.services.member_permanent_deletion.delete_submission_chains_for_member", return_value=0)
def test_missing_storage_object_still_deletes_row(mock_chains, mock_get, mock_storage) -> None:
    from app.services.member_permanent_deletion import delete_owned_media_for_user

    media = MagicMock()
    media.id = 12
    media.uploaded_by = 50
    media.file_url = "/uploads/gone.jpg"
    mock_get.return_value = media
    mock_storage.return_value = StorageDeleteResult(outcome=StorageDeleteOutcome.NOT_APPLICABLE)

    db = MagicMock()
    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[12],
    ), patch(
        "app.services.member_permanent_deletion._clear_root_chain_for_media"
    ), patch("app.services.member_permanent_deletion.media_crud.delete_media_row_only") as mock_row:
        stats = delete_owned_media_for_user(db, 50, include_event_gallery=True)

    mock_row.assert_called_once()
    assert stats.media_deleted == 1
    assert stats.media_failed == 0
    assert stats.storage_queued == 0


@patch("app.services.member_permanent_deletion.delete_storage_for_file_url")
@patch("app.services.member_permanent_deletion.media_crud.get")
@patch("app.services.member_permanent_deletion.delete_submission_chains_for_member", return_value=1)
def test_row_integrity_failure_does_not_queue_storage(mock_chains, mock_get, mock_storage) -> None:
    from app.services.member_permanent_deletion import delete_owned_media_for_user

    media = MagicMock()
    media.id = 13
    media.uploaded_by = 50
    media.file_url = "supabase-ref:b/p.jpg"
    mock_get.return_value = media
    mock_storage.return_value = StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)

    db = MagicMock()
    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[13],
    ), patch(
        "app.services.member_permanent_deletion._clear_root_chain_for_media"
    ), patch(
        "app.services.member_permanent_deletion.media_crud.delete_media_row_only",
        side_effect=RuntimeError("linked to other records"),
    ):
        stats = delete_owned_media_for_user(db, 50, include_event_gallery=True)

    assert stats.media_failed == 1
    assert stats.storage_queued == 0
    assert stats.storage_deleted == 1
    assert stats.row_block_reasons


def test_requestor_with_documentation_requests_blocked() -> None:
    from app.services.member_permanent_deletion import assert_requestor_permanent_delete_allowed

    user = MagicMock()
    user.id = 3
    user.role = MagicMock()
    user.role.role_name = RoleName.ORGANIZATION
    db = MagicMock()
    db.scalar.return_value = 2

    with pytest.raises(RuntimeError, match="documentation request"):
        assert_requestor_permanent_delete_allowed(db, user)


@patch("app.services.member_permanent_deletion.delete_storage_for_file_url")
def test_retry_pending_storage_removes_row_on_success(mock_storage) -> None:
    from app.models.pending_storage_deletion import PendingStorageDeletion
    from app.services.member_permanent_deletion import retry_pending_storage_for_user

    pending = MagicMock(spec=PendingStorageDeletion)
    pending.media_id = 99
    pending.file_url = "supabase-ref:b/p"
    pending.attempts = 1

    media = MagicMock()
    media.file_url = "supabase-ref:b/p"
    mock_storage.return_value = StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)

    db = MagicMock()
    pending_rows = MagicMock()
    pending_rows.__iter__ = lambda _self: iter([pending])
    db.scalars.return_value = pending_rows

    with patch("app.services.member_permanent_deletion.media_crud.get", return_value=media), patch(
        "app.services.member_permanent_deletion._clear_root_chain_for_media"
    ), patch(
        "app.services.member_permanent_deletion.media_crud.delete_media_row_only"
    ) as mock_row:
        stats = retry_pending_storage_for_user(db, 50)

    mock_row.assert_called_once()
    db.delete.assert_called_with(pending)
    assert stats.media_deleted == 1
    assert stats.storage_deleted == 1


def test_format_incomplete_cleanup_distinguishes_queue_vs_row_block() -> None:
    from app.services.member_permanent_deletion import (
        PermanentDeletionStats,
        format_incomplete_cleanup_error,
    )

    queued = format_incomplete_cleanup_error(
        PermanentDeletionStats(media_failed=2, storage_queued=2)
    )
    assert "Retry storage cleanup" in queued
    assert "still active" in queued

    row_only = format_incomplete_cleanup_error(
        PermanentDeletionStats(media_failed=3, storage_queued=0, storage_deleted=3)
    )
    assert "Do not use storage cleanup retry" in row_only
    assert "still active" in row_only

    from app.services.member_permanent_deletion import incomplete_cleanup_http_detail

    payload = incomplete_cleanup_http_detail(
        PermanentDeletionStats(media_failed=3, storage_queued=0, storage_deleted=3)
    )
    assert payload["can_retry_storage"] is False
    assert payload["account_deleted"] is False
    assert payload["storage_queued"] == 0


def test_permanent_delete_api_returns_structured_409_on_incomplete() -> None:
    from fastapi.testclient import TestClient

    from app.api.deps import require_admin
    from app.database import get_db
    from app.services.member_permanent_deletion import (
        PermanentDeletionIncompleteError,
        PermanentDeletionStats,
    )
    from main import app

    admin = MagicMock()
    admin.id = 1
    admin.role = MagicMock()
    admin.role.role_name = RoleName.ADMIN

    member = _member_user(88)
    member.email = "del@test.local"

    def override_db():
        yield MagicMock()

    app.dependency_overrides[require_admin] = lambda: admin
    app.dependency_overrides[get_db] = override_db

    blocked = PermanentDeletionIncompleteError(
        PermanentDeletionStats(media_failed=3, storage_queued=0, storage_deleted=3)
    )
    with patch("app.api.routes.admin_members.user_crud.get_by_id", return_value=member), patch(
        "app.api.routes.admin_members.user_crud.permanently_delete_member",
        side_effect=blocked,
    ):
        client = TestClient(app, base_url="http://127.0.0.1")
        resp = client.post(
            "/api/admin/members/88/delete",
            json={"confirmation_email": "del@test.local", "delete_uploads": True},
            headers={"Authorization": "Bearer test"},
        )

    app.dependency_overrides.clear()
    body = resp.json()
    assert resp.status_code == 409, body
    detail = body.get("detail", body)
    assert detail["can_retry_storage"] is False
    assert detail["storage_queued"] == 0
    assert detail["account_deleted"] is False
    assert "Do not use storage cleanup retry" in detail["message"]


def test_delete_media_row_only_clears_ai_review_history_before_media() -> None:
    """Regression: ORM delete of detection rows must not NULL ai_review_history.ai_detection_id."""
    from app.crud import media as media_crud
    from app.models.ai_review_history import AiReviewHistory

    db = MagicMock()
    nested = MagicMock()
    nested.__enter__ = MagicMock(return_value=None)
    nested.__exit__ = MagicMock(return_value=False)
    db.begin_nested.return_value = nested
    media = MagicMock()
    media.id = 301

    media_crud.delete_media_row_only(db, media, commit=False)

    db.begin_nested.assert_called_once()
    db.commit.assert_not_called()
    assert db.execute.called
    executed = db.execute.call_args[0][0]
    # SQLAlchemy Delete for AiReviewHistory by media_id
    assert executed.table.name == AiReviewHistory.__tablename__
    db.delete.assert_called_once_with(media)


def test_delete_media_row_only_savepoint_mode_does_not_commit() -> None:
    from sqlalchemy.exc import IntegrityError

    from app.crud import media as media_crud

    db = MagicMock()
    nested = MagicMock()
    nested.__enter__ = MagicMock(return_value=None)
    nested.__exit__ = MagicMock(return_value=False)
    db.begin_nested.return_value = nested
    media = MagicMock()
    media.id = 1

    media_crud.delete_media_row_only(db, media, commit=False)
    db.begin_nested.assert_called_once()
    db.commit.assert_not_called()
    db.delete.assert_called_once_with(media)

    db2 = MagicMock()
    nested2 = MagicMock()
    nested2.__enter__ = MagicMock(return_value=None)
    nested2.__exit__ = MagicMock(return_value=False)
    db2.begin_nested.return_value = nested2
    media2 = MagicMock()
    media2.id = 2
    # Fail on media delete flush after history delete succeeds
    db2.flush.side_effect = [None, IntegrityError("stmt", {}, Exception("fk"))]
    with pytest.raises(RuntimeError, match="linked"):
        media_crud.delete_media_row_only(db2, media2, commit=False)
    db2.rollback.assert_not_called()


def test_three_media_with_review_history_delete_order_ok_mocked() -> None:
    """Three owned media: storage OK, review history cleared, rows deleted, nothing queued."""
    from app.services.member_permanent_deletion import delete_owned_media_for_user

    medias = []
    for mid in (304, 303, 302):
        m = MagicMock()
        m.id = mid
        m.uploaded_by = 80
        m.file_url = f"supabase-ref:b/{mid}.jpg"
        medias.append(m)

    by_id = {m.id: m for m in medias}

    db = MagicMock()
    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[304, 303, 302],
    ), patch(
        "app.services.member_permanent_deletion.delete_submission_chains_for_member",
        return_value=0,
    ), patch(
        "app.services.member_permanent_deletion.delete_storage_for_file_url",
        return_value=StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED),
    ), patch(
        "app.services.member_permanent_deletion._clear_root_chain_for_media",
    ), patch(
        "app.services.member_permanent_deletion.media_crud.get",
        side_effect=lambda _db, mid: by_id[mid],
    ), patch(
        "app.services.member_permanent_deletion.media_crud.delete_media_row_only",
    ) as mock_row:
        stats = delete_owned_media_for_user(db, 80, include_event_gallery=True)

    assert mock_row.call_count == 3
    assert stats.media_deleted == 3
    assert stats.storage_deleted == 3
    assert stats.media_failed == 0
    assert stats.storage_queued == 0
