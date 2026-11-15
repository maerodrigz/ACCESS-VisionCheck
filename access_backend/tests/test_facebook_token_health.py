"""Facebook Page token health: cached vs live check, admin-only, no secrets in payload."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core.security import create_access_token, hash_password
from app.crud import session as session_crud
from app.database import Base, get_db
from app.models.facebook_page_token_health import FacebookPageTokenHealth
from app.models.role import Role
from app.models.user import User
from app.services.facebook_token_health import build_status_payload, sanitize_facebook_error
from main import app


@pytest.fixture()
def db() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def client(db: Session) -> TestClient:
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _role(db: Session, name: str) -> Role:
    existing = db.scalar(select(Role).where(Role.role_name == name))
    if existing is not None:
        return existing
    row = Role(role_name=name)
    db.add(row)
    db.flush()
    return row


def _user(db: Session, *, email: str, role_name: str) -> User:
    role = _role(db, role_name)
    user = User(
        email=email,
        fullname=email.split("@")[0],
        password=hash_password("TestPass123!"),
        role_id=role.id,
        status="approved",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(db: Session, user: User) -> dict[str, str]:
    token = create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": user.role.role_name,
        }
    )
    session_crud.create_session(db, user.id, token)
    return {"Authorization": f"Bearer {token}"}


def test_sanitize_redacts_eaa_tokens() -> None:
    raw = "Invalid OAuth access token EAABxyz123ABC and access_token=secretvalue"
    out = sanitize_facebook_error(raw) or ""
    assert "EAABxyz123ABC" not in out
    assert "secretvalue" not in out
    assert "[redacted" in out.lower() or "[redacted-token]" in out


def test_cached_status_does_not_call_graph(db: Session) -> None:
    with (
        patch(
            "app.services.facebook_token_health.facebook_credentials",
            return_value=("1202339146306816", "EAA-fake-not-printed"),
        ),
        patch("app.services.facebook_token_health.settings_crud.settings_payload", return_value={"enable_facebook_publishing": True}),
        patch("app.services.facebook_token_health.inspect_page_token") as inspect_mock,
    ):
        payload = build_status_payload(db, live=False)
        inspect_mock.assert_not_called()
    assert payload["live_check"] is False
    assert payload["access_token_set"] is True
    assert payload["page_id_set"] is True
    assert payload["health"]["expiry_label"] == "Expiration not confirmed"
    assert payload["health"]["connection_status"] == "unknown"
    blob = str(payload)
    assert "EAA-fake-not-printed" not in blob


def test_missing_token_live_check(db: Session) -> None:
    with (
        patch(
            "app.services.facebook_token_health.facebook_credentials",
            return_value=("1202339146306816", ""),
        ),
        patch("app.services.facebook_token_health.settings_crud.settings_payload", return_value={"enable_facebook_publishing": True}),
        patch("app.services.facebook_token_health.inspect_page_token") as inspect_mock,
    ):
        payload = build_status_payload(db, live=True)
        inspect_mock.assert_not_called()
    assert payload["verified_now"] is True
    assert payload["page_token_valid"] is False
    assert payload["health"]["connection_status"] == "disconnected"
    assert "FACEBOOK_PAGE_ACCESS_TOKEN" in payload["missing"]


def test_valid_token_live_check_persists_health(db: Session) -> None:
    with (
        patch(
            "app.services.facebook_token_health.facebook_credentials",
            return_value=("1202339146306816", "EAA-fake"),
        ),
        patch("app.services.facebook_token_health.settings_crud.settings_payload", return_value={"enable_facebook_publishing": True}),
        patch(
            "app.services.facebook_token_health.inspect_page_token",
            return_value={
                "ok": True,
                "token_subject_id": "1202339146306816",
                "token_subject_name": "ACCESS Page",
            },
        ),
        patch("app.services.facebook_token_health.resolve_page_album_id", return_value="album-1"),
        patch(
            "app.services.facebook_token_health.list_page_albums",
            return_value=[{"id": "album-1", "name": "Photos"}],
        ),
    ):
        payload = build_status_payload(db, live=True)

    assert payload["configured"] is True
    assert payload["page_token_valid"] is True
    assert payload["health"]["connection_status"] == "connected"
    assert payload["health"]["page_name"] == "ACCESS Page"
    assert payload["health"]["expiry_visibility"] == "unknown"
    assert payload["health"]["last_ok"] is True
    row = db.get(FacebookPageTokenHealth, 1)
    assert row is not None
    assert row.last_ok is True
    assert row.page_name == "ACCESS Page"


def test_invalid_token_live_check(db: Session) -> None:
    with (
        patch(
            "app.services.facebook_token_health.facebook_credentials",
            return_value=("1202339146306816", "EAA-fake"),
        ),
        patch("app.services.facebook_token_health.settings_crud.settings_payload", return_value={"enable_facebook_publishing": True}),
        patch(
            "app.services.facebook_token_health.inspect_page_token",
            return_value={"ok": False, "reason": "Error validating access token: EAAshouldgo"},
        ),
    ):
        payload = build_status_payload(db, live=True)

    assert payload["configured"] is False
    assert payload["page_token_valid"] is False
    assert payload["health"]["connection_status"] == "needs_attention"
    assert "EAAshouldgo" not in (payload["health"]["last_error"] or "")


def test_admin_only_status_and_check(client: TestClient, db: Session) -> None:
    member = _user(db, email="fb-member@example.com", role_name="Member")
    admin = _user(db, email="fb-admin@example.com", role_name="Admin")

    unauth = client.get("/api/admin/event-media/facebook/status")
    assert unauth.status_code == 401

    denied = client.get(
        "/api/admin/event-media/facebook/status",
        headers=_bearer(db, member),
    )
    assert denied.status_code == 403

    with (
        patch(
            "app.services.facebook_token_health.facebook_credentials",
            return_value=("1202339146306816", "EAA-fake"),
        ),
        patch("app.services.facebook_token_health.settings_crud.settings_payload", return_value={"enable_facebook_publishing": True}),
        patch("app.services.facebook_token_health.inspect_page_token") as inspect_mock,
    ):
        cached = client.get(
            "/api/admin/event-media/facebook/status",
            headers=_bearer(db, admin),
        )
        assert cached.status_code == 200, cached.text
        inspect_mock.assert_not_called()
        body = cached.json()
        assert "health" in body
        assert body.get("live_check") is False
        assert "EAA-fake" not in str(body)

        inspect_mock.return_value = {
            "ok": True,
            "token_subject_id": "1202339146306816",
            "token_subject_name": "ACCESS",
        }
        with (
            patch("app.services.facebook_token_health.resolve_page_album_id", return_value=None),
            patch("app.services.facebook_token_health.list_page_albums", return_value=[]),
        ):
            live = client.post(
                "/api/admin/event-media/facebook/status/check",
                headers=_bearer(db, admin),
            )
        assert live.status_code == 200, live.text
        assert inspect_mock.called
        live_body = live.json()
        assert live_body.get("verified_now") is True
        assert live_body["health"]["expiry_label"] == "Expiration not confirmed"
        assert "EAA-fake" not in str(live_body)
        for key in live_body.keys():
            assert "access_token" not in key or key == "access_token_set"
