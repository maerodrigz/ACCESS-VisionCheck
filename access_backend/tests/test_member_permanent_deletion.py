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

    with pytest.raises(RuntimeError, match="queued for retry"):
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
    db.scalars.return_value.all.return_value = []
    db.scalars.side_effect = [
        MagicMock(all=MagicMock(return_value=[])),  # chains in delete_submission_chains - patched
    ]

    with patch(
        "app.services.member_permanent_deletion._media_ids_for_permanent_delete",
        return_value=[10],
    ), patch("app.services.member_permanent_deletion.media_crud.delete_media_row_only") as mock_row:
        stats = delete_owned_media_for_user(db, 50, include_event_gallery=True)

    mock_storage.assert_called_once_with("supabase-ref:access-media/path/file.jpg")
    mock_row.assert_called_once_with(db, media)
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
    mock_storage.return_value = StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)

    db = MagicMock()
    pending_rows = MagicMock()
    pending_rows.__iter__ = lambda _self: iter([pending])
    db.scalars.return_value = pending_rows

    with patch("app.services.member_permanent_deletion.media_crud.get", return_value=media), patch(
        "app.services.member_permanent_deletion.media_crud.delete_media_row_only"
    ) as mock_row:
        stats = retry_pending_storage_for_user(db, 50)

    mock_row.assert_called_once_with(db, media)
    db.delete.assert_called_with(pending)
    assert stats.media_deleted == 1
    assert stats.storage_deleted == 1


def test_permanent_delete_api_returns_409_on_storage_incomplete() -> None:
    from fastapi.testclient import TestClient

    from app.api.deps import require_admin
    from app.database import get_db
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

    with patch("app.api.routes.admin_members.user_crud.get_by_id", return_value=member), patch(
        "app.api.routes.admin_members.user_crud.permanently_delete_member",
        side_effect=RuntimeError("storage object(s) queued for retry"),
    ):
        client = TestClient(app, base_url="http://127.0.0.1")
        resp = client.post(
            "/api/admin/members/88/delete",
            json={"confirmation_email": "del@test.local", "delete_uploads": True},
            headers={"Authorization": "Bearer test"},
        )

    app.dependency_overrides.clear()
    assert resp.status_code == 409
