"""Member presence: heartbeat, online window, admin fields, authz."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core.security import create_access_token, hash_password
from app.crud import session as session_crud
from app.database import Base, get_db
from app.models.role import Role
from app.models.user import User
from app.services import member_presence as presence
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


def _user(db: Session, *, email: str, role_name: str = "Member", active: bool = True) -> User:
    role = _role(db, role_name)
    user = User(
        email=email,
        fullname=email.split("@")[0],
        password=hash_password("TestPass123!"),
        role_id=role.id,
        status="approved",
        is_active=active,
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


def test_online_only_within_two_minutes() -> None:
    now = datetime(2026, 11, 15, 12, 0, tzinfo=timezone.utc)
    assert presence.is_online(now - timedelta(seconds=90), now=now) is True
    assert presence.is_online(now - timedelta(minutes=3), now=now) is False
    assert presence.is_online(None, now=now) is False


def test_inactive_thirty_days_and_disabled() -> None:
    now = datetime(2026, 11, 15, 12, 0, tzinfo=timezone.utc)
    assert (
        presence.is_inactive(
            last_seen_at=now - timedelta(days=31),
            last_login_at=now - timedelta(days=40),
            is_active=True,
            now=now,
        )
        is True
    )
    assert (
        presence.is_inactive(
            last_seen_at=now - timedelta(days=31),
            last_login_at=None,
            is_active=False,
            now=now,
        )
        is False
    )
    # Online overrides inactive
    assert (
        presence.is_inactive(
            last_seen_at=now - timedelta(seconds=30),
            last_login_at=now - timedelta(days=40),
            is_active=True,
            now=now,
        )
        is False
    )


def test_heartbeat_updates_own_last_seen(client: TestClient, db: Session) -> None:
    member = _user(db, email="pulse-member@example.com")
    other = _user(db, email="pulse-other@example.com")
    headers = _bearer(db, member)

    r = client.post("/api/presence/heartbeat", headers=headers)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["ok"] is True
    assert body["presence"] == "Online"
    assert "token" not in body

    db.refresh(member)
    db.refresh(other)
    assert member.last_seen_at is not None
    assert other.last_seen_at is None


def test_heartbeat_rejects_admin_and_unauth(client: TestClient, db: Session) -> None:
    admin = _user(db, email="pulse-admin@example.com", role_name="Admin")
    assert client.post("/api/presence/heartbeat").status_code == 401
    assert client.post("/api/presence/heartbeat", headers=_bearer(db, admin)).status_code == 403


def test_admin_users_list_includes_presence_not_fabricated(client: TestClient, db: Session) -> None:
    admin = _user(db, email="pulse-list-admin@example.com", role_name="Admin")
    online = _user(db, email="pulse-online@example.com")
    offline = _user(db, email="pulse-offline@example.com")
    disabled = _user(db, email="pulse-disabled@example.com", active=False)

    now = presence.utc_now()
    online.last_seen_at = now
    online.last_login_at = now - timedelta(hours=1)
    offline.last_seen_at = now - timedelta(days=2)
    offline.last_login_at = now - timedelta(days=3)
    disabled.last_login_at = now - timedelta(days=10)
    db.commit()

    r = client.get("/api/users", headers=_bearer(db, admin))
    assert r.status_code == 200, r.text
    rows = {row["email"]: row for row in r.json()}
    assert rows["pulse-online@example.com"]["presence"] == "Online"
    assert rows["pulse-online@example.com"]["is_online"] is True
    assert rows["pulse-offline@example.com"]["presence"] == "Offline"
    assert rows["pulse-disabled@example.com"]["account_status"] == "Disabled"
    assert rows["pulse-online@example.com"]["last_seen_at"] is not None
    assert "EAA" not in str(r.json())


def test_member_cannot_list_users(client: TestClient, db: Session) -> None:
    member = _user(db, email="pulse-member-list@example.com")
    r = client.get("/api/users", headers=_bearer(db, member))
    assert r.status_code == 403


def test_jwt_alone_does_not_imply_online() -> None:
    """Valid session without last_seen_at is Offline."""
    fields = presence.presence_fields(
        is_active=True,
        last_seen_at=None,
        last_login_at=datetime.now(timezone.utc),
    )
    assert fields["presence"] == "Offline"
    assert fields["is_online"] is False
    assert fields["account_status"] == "Active"


def test_member_profile_account_status_matches_is_active(
    client: TestClient, db: Session
) -> None:
    """Profile account_status mirrors Admin (is_active), not registration alone."""
    active = _user(db, email="profile-active@example.com", active=True)
    active.last_seen_at = None
    db.commit()

    r = client.get("/api/member/profile", headers=_bearer(db, active))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["is_active"] is True
    assert body["account_status"] == "Active"
    assert body["presence"] == "Offline"
    assert body["is_online"] is False
    assert body["status"] == "approved"
