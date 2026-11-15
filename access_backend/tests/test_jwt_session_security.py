"""JWT_SECRET policy + user_sessions enforcement (logout / revoke / expiry)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from jose import jwt
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.config import Settings, settings
from app.core import jwt_secret_policy
from app.core.security import create_access_token, hash_password
from app.crud import session as session_crud
from app.database import Base, get_db
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from main import app
from tests.auth_token import issue_bearer_token

_STRONG = "unit-test-jwt-secret-not-for-production-use-01"


@pytest.fixture()
def db() -> Session:
    # StaticPool keeps one shared :memory: DB across TestClient worker threads.
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


def _role(db: Session, name: str = "Member") -> Role:
    existing = db.scalar(select(Role).where(Role.role_name == name))
    if existing is not None:
        return existing
    row = Role(role_name=name)
    db.add(row)
    db.flush()
    return row


def _user(db: Session, *, email: str, role_name: str = "Member", password: str = "TestPass123!") -> User:
    role = _role(db, role_name)
    user = User(
        email=email,
        fullname=email.split("@")[0],
        password=hash_password(password),
        role_id=role.id,
        status="approved",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def test_rejects_empty_and_placeholder_jwt_secrets() -> None:
    for bad in ("", "change_this_secret", "access_visioncheck_dev_secret", "short"):
        assert jwt_secret_policy.is_insecure_jwt_secret(bad)
        with pytest.raises(ValidationError) as exc:
            Settings(_env_file=None, APP_ENV="development", JWT_SECRET=bad)
        assert "JWT_SECRET" in str(exc.value)


def test_accepts_strong_jwt_secret() -> None:
    s = Settings(_env_file=None, APP_ENV="development", JWT_SECRET=_STRONG)
    assert s.jwt_secret == _STRONG


def test_valid_login_creates_session_and_authenticates(client: TestClient, db: Session) -> None:
    password = "TestPass123!"
    user = _user(db, email="jwt-member@example.com", password=password)
    r = client.post("/api/auth/login", json={"email": user.email, "password": password})
    assert r.status_code == 200, r.text
    token = r.json()["token"]
    assert token
    row = db.scalar(select(UserSession).where(UserSession.token == token))
    assert row is not None
    assert row.user_id == user.id

    # Logout requires get_current_user (JWT + active session).
    out = client.post("/api/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert out.status_code == 200, out.text
    assert session_crud.get_active_session(db, token) is None


def test_logout_revokes_session_token(client: TestClient, db: Session) -> None:
    user = _user(db, email="jwt-logout@example.com")
    token = issue_bearer_token(db, user)
    assert session_crud.get_active_session(db, token) is not None

    r = client.post("/api/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    assert session_crud.get_active_session(db, token) is None

    again = client.post("/api/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert again.status_code == 401


def test_revoked_session_cannot_authenticate(client: TestClient, db: Session) -> None:
    user = _user(db, email="jwt-revoke@example.com", role_name="Admin")
    token = issue_bearer_token(db, user)
    session_crud.revoke_sessions_for_user(db, user.id)

    r = client.get(
        "/api/admin/system-settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 401
    assert "revoked" in (r.json().get("detail") or "").lower() or r.status_code == 401


def test_jwt_without_session_row_rejected(client: TestClient, db: Session) -> None:
    user = _user(db, email="jwt-nosession@example.com", role_name="Admin")
    orphan = create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": "Admin",
        }
    )
    r = client.get(
        "/api/admin/system-settings",
        headers={"Authorization": f"Bearer {orphan}"},
    )
    assert r.status_code == 401


def test_expired_jwt_rejected(client: TestClient, db: Session) -> None:
    user = _user(db, email="jwt-expired@example.com", role_name="Admin")
    # Craft an already-expired token with the live signing secret (do not print it).
    payload = {
        "userId": user.id,
        "name": user.fullname,
        "email": user.email,
        "role": "Admin",
        "exp": datetime.now(timezone.utc) - timedelta(minutes=5),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    session_crud.create_session(db, user.id, token, expire_minutes=60)

    r = client.get(
        "/api/admin/system-settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 401


def test_expired_session_row_rejected_even_if_jwt_still_valid(client: TestClient, db: Session) -> None:
    user = _user(db, email="jwt-session-exp@example.com", role_name="Admin")
    token = create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": "Admin",
        },
        expire_minutes=60,
    )
    row = UserSession(
        user_id=user.id,
        token=token,
        expires_at=datetime.now(timezone.utc) - timedelta(minutes=1),
    )
    db.add(row)
    db.commit()

    r = client.get(
        "/api/admin/system-settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 401
    assert session_crud.get_active_session(db, token) is None
