"""
SMS forgot-password must update the hash so authenticate() accepts the new password.

Isolated DB only: ACCESS_PYTEST_DB=access_waverep_test
Does not touch production user passwords.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import text

pytestmark = pytest.mark.skipif(
    os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test",
    reason="Set ACCESS_PYTEST_DB=access_waverep_test",
)


def _prepare_schema(engine) -> None:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ"))
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS password_reset_sms_otps (
                    id SERIAL PRIMARY KEY,
                    phone_e164 VARCHAR(20) NOT NULL,
                    code_hash VARCHAR(128) NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    attempt_count INTEGER NOT NULL DEFAULT 0,
                    last_sent_at TIMESTAMPTZ NOT NULL,
                    consumed_at TIMESTAMPTZ NULL,
                    created_at TIMESTAMPTZ NOT NULL
                )
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS phone_verification_otps (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    phone_e164 VARCHAR(20) NOT NULL,
                    code_hash VARCHAR(128) NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    attempt_count INTEGER NOT NULL DEFAULT 0,
                    last_sent_at TIMESTAMPTZ NOT NULL,
                    consumed_at TIMESTAMPTZ NULL,
                    created_at TIMESTAMPTZ NOT NULL
                )
                """
            )
        )


@pytest.fixture()
def db_session(monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "log")
    from app.config import settings

    settings.sms_provider = "log"
    from app.database import SessionLocal, engine
    from app.services import sms_rate_limit

    _prepare_schema(engine)
    sms_rate_limit.reset_for_tests()
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _role_id(db, name: str) -> int:
    from app.models.role import Role
    from sqlalchemy import select

    row = db.scalar(select(Role).where(Role.role_name == name))
    assert row is not None, f"role {name} missing in isolated DB"
    return row.id


def _insert_user(db, *, role_name: str, email: str, phone: str, password: str):
    from app.core.security import hash_password
    from app.models.enums import UserStatus
    from app.models.user import User

    user = User(
        fullname=f"SMS Reset {role_name}",
        email=email,
        password=hash_password(password),
        role_id=_role_id(db, role_name),
        status=UserStatus.APPROVED,
        contact_number=phone,
        phone_verified_at=datetime.now(timezone.utc),
        is_active=True,
        failed_login_count=0,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _cleanup(db, user_id: int, phone: str) -> None:
    # Raw SQL avoids ORM loading optional ranking columns missing on older waverep schemas.
    db.execute(text("DELETE FROM password_reset_sms_otps WHERE phone_e164 = :p"), {"p": phone})
    db.execute(text("DELETE FROM user_sessions WHERE user_id = :id"), {"id": user_id})
    db.execute(text("DELETE FROM login_history WHERE user_id = :id"), {"id": user_id})
    db.execute(text("DELETE FROM member_rankings WHERE user_id = :id"), {"id": user_id})
    db.execute(text("DELETE FROM users WHERE id = :id"), {"id": user_id})
    db.commit()


@pytest.mark.parametrize("role_name", ["Member", "Organization"])
def test_sms_otp_reset_then_authenticate(db_session, role_name: str):
    from app.core.security import verify_password
    from app.crud import password_reset_sms_otp as reset_otp_crud
    from app.crud import user as user_crud
    from app.crud.sms_otp_common import hash_otp, utcnow
    from app.models.password_reset_sms_otp import PasswordResetSmsOtp
    from app.services.phone_normalize import normalize_ph_mobile
    from app.services.security_policy import clear_login_failures
    from app.crud import session as session_crud

    phone_local = "0917" + f"{uuid.uuid4().int % 10_000_000:07d}"
    phone = normalize_ph_mobile(phone_local)
    email = f"sms-reset-{role_name.lower()}-{uuid.uuid4().hex[:8]}@waverep.example.com"
    old_password = "OldPassphrase1"
    new_password = "NewPassphrase2"
    code = "424242"

    user = _insert_user(
        db_session, role_name=role_name, email=email, phone=phone, password=old_password
    )
    user_id = user.id
    old_hash = user.password

    try:
        assert user_crud.authenticate(db_session, email, old_password) is not None

        now = utcnow()
        db_session.add(
            PasswordResetSmsOtp(
                phone_e164=phone,
                code_hash=hash_otp(code),
                expires_at=now + timedelta(minutes=10),
                attempt_count=0,
                last_sent_at=now,
                created_at=now,
            )
        )
        db_session.commit()

        reset_otp_crud.verify_and_consume(db_session, phone, code)
        user_crud.set_password(db_session, user, new_password, clear_lockout=True)
        fresh = user_crud.get_by_id(db_session, user_id)
        assert fresh is not None
        assert fresh.password != old_hash
        assert verify_password(new_password, fresh.password)
        assert not verify_password(old_password, fresh.password)
        clear_login_failures(db_session, fresh)
        session_crud.revoke_sessions_for_user(db_session, user_id)

        assert user_crud.authenticate(db_session, email, new_password) is not None
        assert user_crud.authenticate(db_session, email, old_password) is None

        with pytest.raises(ValueError):
            reset_otp_crud.verify_and_consume(db_session, phone, code)
    finally:
        _cleanup(db_session, user_id, phone)


def test_sms_reset_clears_active_lockout_then_login(db_session):
    """Prior failed sign-ins that locked the account must not block login after SMS reset."""
    from app.core.security import verify_password
    from app.crud import password_reset_sms_otp as reset_otp_crud
    from app.crud import user as user_crud
    from app.crud.sms_otp_common import hash_otp, utcnow
    from app.models.password_reset_sms_otp import PasswordResetSmsOtp
    from app.services.phone_normalize import normalize_ph_mobile
    from app.services.security_policy import (
        is_account_locked,
        lockout_detail_message,
        lockout_remaining_minutes,
        record_failed_login,
        security_config,
    )

    phone_local = "0919" + f"{uuid.uuid4().int % 10_000_000:07d}"
    phone = normalize_ph_mobile(phone_local)
    email = f"sms-lock-{uuid.uuid4().hex[:8]}@waverep.example.com"
    old_password = "LockedOldPass1"
    new_password = "LockedNewPass2"
    code = "135790"

    user = _insert_user(
        db_session, role_name="Member", email=email, phone=phone, password=old_password
    )
    user_id = user.id
    try:
        cfg = security_config(db_session)
        assert cfg["account_lockout_minutes"] >= 1
        assert cfg["max_login_attempts"] >= 1

        for _ in range(cfg["max_login_attempts"]):
            record_failed_login(db_session, user)
            db_session.refresh(user)

        assert is_account_locked(user)
        assert user.locked_until is not None
        remaining = lockout_remaining_minutes(user)
        assert remaining is not None and remaining >= 1
        detail = lockout_detail_message(user)
        assert "temporarily locked" in detail.lower()
        assert "invalid credentials" not in detail.lower()
        assert str(remaining) in detail

        # Login gate: locked accounts are rejected before password checks.
        assert is_account_locked(user_crud.get_by_email(db_session, email))

        now = utcnow()
        db_session.add(
            PasswordResetSmsOtp(
                phone_e164=phone,
                code_hash=hash_otp(code),
                expires_at=now + timedelta(minutes=10),
                attempt_count=0,
                last_sent_at=now,
                created_at=now,
            )
        )
        db_session.commit()

        reset_otp_crud.verify_and_consume(db_session, phone, code)
        user_crud.set_password(db_session, user, new_password, clear_lockout=True)
        fresh = user_crud.get_by_id(db_session, user_id)
        assert fresh is not None
        assert not is_account_locked(fresh)
        assert fresh.locked_until is None
        assert int(fresh.failed_login_count or 0) == 0
        assert verify_password(new_password, fresh.password)
        assert user_crud.authenticate(db_session, email, new_password) is not None
        assert user_crud.authenticate(db_session, email, old_password) is None
    finally:
        _cleanup(db_session, user_id, phone)


@pytest.mark.parametrize("role_name", ["Member", "Organization"])
def test_sms_reset_unlocks_requestor_and_member(db_session, role_name: str):
    from app.crud import password_reset_sms_otp as reset_otp_crud
    from app.crud import user as user_crud
    from app.crud.sms_otp_common import hash_otp, utcnow
    from app.models.password_reset_sms_otp import PasswordResetSmsOtp
    from app.services.phone_normalize import normalize_ph_mobile
    from app.services.security_policy import is_account_locked

    phone_local = "0920" + f"{uuid.uuid4().int % 10_000_000:07d}"
    phone = normalize_ph_mobile(phone_local)
    email = f"sms-unlock-{role_name.lower()}-{uuid.uuid4().hex[:8]}@waverep.example.com"
    code = "246810"
    user = _insert_user(
        db_session,
        role_name=role_name,
        email=email,
        phone=phone,
        password="RoleOldPass1",
    )
    user_id = user.id
    try:
        user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=30)
        user.failed_login_count = 2
        db_session.commit()
        db_session.refresh(user)
        assert is_account_locked(user)

        now = utcnow()
        db_session.add(
            PasswordResetSmsOtp(
                phone_e164=phone,
                code_hash=hash_otp(code),
                expires_at=now + timedelta(minutes=10),
                attempt_count=0,
                last_sent_at=now,
                created_at=now,
            )
        )
        db_session.commit()
        reset_otp_crud.verify_and_consume(db_session, phone, code)
        user_crud.set_password(db_session, user, "RoleNewPass2", clear_lockout=True)
        fresh = user_crud.get_by_id(db_session, user_id)
        assert fresh is not None
        assert not is_account_locked(fresh)
        assert fresh.failed_login_count == 0
        assert user_crud.authenticate(db_session, email, "RoleNewPass2") is not None
    finally:
        _cleanup(db_session, user_id, phone)


def test_send_otp_log_provider_then_complete(db_session, monkeypatch):
    from app.core.security import verify_password
    from app.crud import password_reset_sms_otp as reset_otp_crud
    from app.crud import user as user_crud
    from app.services.phone_normalize import normalize_ph_mobile

    phone_local = "0918" + f"{uuid.uuid4().int % 10_000_000:07d}"
    phone = normalize_ph_mobile(phone_local)
    email = f"sms-send-{uuid.uuid4().hex[:8]}@waverep.example.com"
    old_password = "SendOldPass1"
    new_password = "SendNewPass2"

    user = _insert_user(
        db_session, role_name="Member", email=email, phone=phone, password=old_password
    )
    user_id = user.id
    try:
        code = reset_otp_crud.send_otp(
            db_session,
            phone,
            fullname=user.fullname,
            client_ip="127.0.0.1",
            actually_deliver=True,
        )
        assert code.isdigit() and len(code) == 6
        reset_otp_crud.verify_and_consume(db_session, phone, code)
        user_crud.set_password(db_session, user, new_password, clear_lockout=True)
        fresh = user_crud.get_by_id(db_session, user_id)
        assert fresh is not None
        assert verify_password(new_password, fresh.password)
        assert user_crud.authenticate(db_session, email, new_password) is not None
    finally:
        _cleanup(db_session, user_id, phone)
