"""CRUD for password reset email OTP."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.password_reset_email_otp import PasswordResetEmailOtp


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_email(email: str) -> str:
    return (email or "").strip().lower()


def _hash_value(value: str) -> str:
    pepper = settings.jwt_secret or "access_otp_pepper"
    return hashlib.sha256(f"{pepper}:{value}".encode()).hexdigest()


def _generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def send_otp(db: Session, email: str, *, fullname: str = "") -> str:
    from app.services.password_reset_email import deliver_password_reset_otp_async

    addr = _normalize_email(email)
    now = _utcnow()
    row = db.scalar(
        select(PasswordResetEmailOtp)
        .where(PasswordResetEmailOtp.email == addr)
        .order_by(PasswordResetEmailOtp.id.desc())
        .limit(1)
    )
    if row and row.last_sent_at:
        last = row.last_sent_at
        if last.tzinfo is None:
            last = last.replace(tzinfo=timezone.utc)
        cooldown = timedelta(seconds=settings.email_otp_resend_seconds)
        elapsed = now - last
        if elapsed < cooldown:
            wait = int((cooldown - elapsed).total_seconds())
            raise ValueError(f"Please wait {max(wait, 1)} seconds before requesting another code.")

    code = _generate_code()
    expires = now + timedelta(minutes=settings.email_otp_expire_minutes)
    db.add(
        PasswordResetEmailOtp(
            email=addr,
            code_hash=_hash_value(code),
            expires_at=expires,
            attempt_count=0,
            last_sent_at=now,
            created_at=now,
        )
    )
    db.commit()
    deliver_password_reset_otp_async(to_email=addr, code=code, fullname=fullname)
    return code


def verify_and_consume(db: Session, email: str, code: str) -> None:
    addr = _normalize_email(email)
    now = _utcnow()
    row = db.scalar(
        select(PasswordResetEmailOtp)
        .where(
            PasswordResetEmailOtp.email == addr,
            PasswordResetEmailOtp.consumed_at.is_(None),
        )
        .order_by(PasswordResetEmailOtp.id.desc())
        .limit(1)
    )
    if not row:
        raise ValueError("No active reset code for this email. Request a new code.")
    expires = row.expires_at if row.expires_at.tzinfo else row.expires_at.replace(tzinfo=timezone.utc)
    if now > expires:
        raise ValueError("Verification code expired. Request a new code.")
    if row.attempt_count >= settings.email_otp_max_attempts:
        raise ValueError("Too many failed attempts. Request a new code.")

    normalized_code = (code or "").strip()
    if not normalized_code.isdigit() or len(normalized_code) != 6:
        row.attempt_count += 1
        db.commit()
        raise ValueError("Enter the 6-digit code from your email.")

    if _hash_value(normalized_code) != row.code_hash:
        row.attempt_count += 1
        db.commit()
        raise ValueError("Incorrect verification code.")

    row.consumed_at = now
    row.attempt_count = 0
    db.commit()
