"""Account deactivation preserves history; status rejection stays separate."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from app.models.enums import UserStatus


@patch("app.crud.session.revoke_sessions_for_user")
def test_deactivate_account_preserves_approved_status(mock_revoke) -> None:
    from app.crud import user as user_crud

    user = MagicMock()
    user.id = 42
    user.status = UserStatus.APPROVED
    user.is_active = True
    db = MagicMock()

    user_crud.deactivate_account(db, user, removed_by=1, removal_reason="Deactivated by administrator")

    assert user.is_active is False
    assert user.removed_at is not None
    assert isinstance(user.removed_at, datetime)
    assert user.removed_at.tzinfo is not None
    assert user.status == UserStatus.APPROVED
    assert user.removal_reason == "Deactivated by administrator"
    db.commit.assert_called()
    mock_revoke.assert_called_once_with(db, 42)


@patch("app.crud.session.revoke_sessions_for_user")
def test_update_status_approved_reactivates(mock_revoke) -> None:
    from app.crud import user as user_crud

    user = MagicMock()
    user.id = 7
    user.status = UserStatus.APPROVED
    user.is_active = False
    user.removed_at = datetime.now(timezone.utc)
    user.removed_by = 1
    user.removal_reason = "Deactivated by administrator"
    db = MagicMock()

    user_crud.update_status(db, user, UserStatus.APPROVED, approved_by=2)

    assert user.status == UserStatus.APPROVED
    assert user.is_active is True
    assert user.removed_at is None
    assert user.removed_by is None
    assert user.removal_reason is None


@patch("app.crud.media.delete_all_for_uploader")
def test_deactivate_route_does_not_delete_media(mock_delete) -> None:
    from fastapi.testclient import TestClient

    from app.api.deps import require_admin
    from app.database import get_db
    from main import app
    from app.models.enums import RoleName

    admin = MagicMock()
    admin.id = 1
    admin.is_active = True
    admin.role = MagicMock()
    admin.role.role_name = RoleName.ADMIN

    member = MagicMock()
    member.id = 99
    member.email = "member@test.local"
    member.is_active = True
    member.removed_at = None
    member.role = MagicMock()
    member.role.role_name = RoleName.MEMBER
    member.status = UserStatus.APPROVED

    db = MagicMock()

    def override_admin():
        return admin

    def override_db():
        yield db

    app.dependency_overrides[require_admin] = override_admin
    app.dependency_overrides[get_db] = override_db

    with patch("app.api.routes.users.user_crud.get_by_id", return_value=member), patch(
        "app.api.routes.users.user_crud.count_active_admins", return_value=2
    ), patch("app.api.routes.users.user_crud.deactivate_account") as mock_deactivate:
        client = TestClient(app, base_url="http://127.0.0.1")
        resp = client.post(
            "/api/users/99/deactivate",
            json={"removal_reason": "Deactivated by administrator"},
            headers={"Authorization": "Bearer test"},
        )

    app.dependency_overrides.clear()

    assert resp.status_code == 200
    mock_deactivate.assert_called_once()
    mock_delete.assert_not_called()
