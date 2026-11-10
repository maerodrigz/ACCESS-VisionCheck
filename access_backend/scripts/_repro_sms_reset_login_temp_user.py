"""
Disposable repro on the CURRENT app DB settings (dev). Creates a temp user,
SMS-resets password via CRUD/API helpers, asserts login, then deletes the user.
Does not modify other accounts. Does not print secrets.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text

from app.core.security import verify_password
from app.crud import password_reset_sms_otp as reset_otp_crud
from app.crud import user as user_crud
from app.database import SessionLocal, engine
from app.models.enums import UserStatus
from app.models.password_reset_sms_otp import PasswordResetSmsOtp
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.services.phone_normalize import normalize_ph_mobile
from app.services import sms_rate_limit


def main() -> None:
    sms_rate_limit.reset_for_tests()
    # Ensure additive column exists on this DB (no drop).
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ"))

    # Valid PH mobile: 09 + 9 digits
    phone_local = "0917" + f"{uuid.uuid4().int % 10_000_000:07d}"
    phone = normalize_ph_mobile(phone_local)
    email = f"temp-sms-repro-{uuid.uuid4().hex[:8]}@example.invalid"
    old_password = "TempOldPass1"
    new_password = "TempNewPass2"

    db = SessionLocal()
    user_id = None
    try:
        role = db.scalar(select(Role).where(Role.role_name == "Member"))
        if not role:
            raise RuntimeError("Member role missing")
        user = user_crud.create_user(
            db,
            name="Temp SMS Repro",
            email=email,
            password=old_password,
            role="Member",
            status=UserStatus.APPROVED,
            contact_number=phone,
        )
        user.phone_verified_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user)
        user_id = user.id
        old_hash = user.password

        assert user_crud.authenticate(db, email, old_password) is not None

        code = reset_otp_crud.send_otp(
            db, phone, fullname=user.fullname, client_ip="127.0.0.1", actually_deliver=True
        )
        reset_otp_crud.verify_and_consume(db, phone, code)
        # Mirror forgot_password_complete order exactly.
        from app.crud import session as session_crud
        from app.services.security_policy import assert_password_meets_policy, clear_login_failures

        assert_password_meets_policy(db, new_password)
        user_crud.set_password(db, user, new_password)
        clear_login_failures(db, user)
        session_crud.revoke_sessions_for_user(db, user.id)

        db.expire_all()
        refreshed = user_crud.get_by_id(db, user_id)
        assert refreshed is not None
        assert refreshed.password != old_hash
        assert verify_password(new_password, refreshed.password)
        assert not verify_password(old_password, refreshed.password)
        assert user_crud.authenticate(db, email, new_password) is not None
        assert user_crud.authenticate(db, email, old_password) is None
        print("repro_backend_ok")
    finally:
        if user_id is not None:
            db.query(PasswordResetSmsOtp).filter(PasswordResetSmsOtp.phone_e164 == phone).delete()
            db.query(UserSession).filter(UserSession.user_id == user_id).delete()
            row = db.get(User, user_id)
            if row:
                db.delete(row)
            db.commit()
        db.close()


if __name__ == "__main__":
    main()
