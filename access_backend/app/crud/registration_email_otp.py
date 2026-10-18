"""CRUD for registration email OTP."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.registration_email_otp import RegistrationEmailOtp


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
    from app.services.registration_email import deliver_registration_otp_async

    addr = _normalize_email(email)
    now = _utcnow()
    row = db.scalar(
        select(RegistrationEmailOtp)
        .where(RegistrationEmailOtp.email == addr)
        .order_by(RegistrationEmailOtp.id.desc())
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
        RegistrationEmailOtp(
            email=addr,
            code_hash=_hash_value(code),
            expires_at=expires,
            attempt_count=0,
            last_sent_at=now,
            created_at=now,
        )
    )
    db.commit()
    deliver_registration_otp_async(to_email=addr, fullname=fullname, code=code)
    return code


def verify_otp(db: Session, email: str, code: str) -> str:
    addr = _normalize_email(email)
    now = _utcnow()
    row = db.scalar(
        select(RegistrationEmailOtp)
        .where(
            RegistrationEmailOtp.email == addr,
            RegistrationEmailOtp.consumed_at.is_(None),
            RegistrationEmailOtp.verification_token_hash.is_(None),
        )
        .order_by(RegistrationEmailOtp.id.desc())
        .limit(1)
    )
    if not row:
        raise ValueError("No active verification for this email. Request a new code.")
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

    token = secrets.token_urlsafe(32)
    row.verification_token_hash = _hash_value(token)
    row.verification_token_expires_at = now + timedelta(minutes=settings.email_otp_token_minutes)
    row.attempt_count = 0
    db.commit()
    return token


def consume_verification_token(db: Session, email: str, token: str) -> None:
    addr = _normalize_email(email)
    now = _utcnow()
    token_hash = _hash_value(token.strip())
    row = db.scalar(
        select(RegistrationEmailOtp)
        .where(
            RegistrationEmailOtp.email == addr,
            RegistrationEmailOtp.verification_token_hash == token_hash,
        )
        .order_by(RegistrationEmailOtp.id.desc())
        .limit(1)
    )
    if not row or row.consumed_at:
        raise ValueError("Email verification expired or invalid. Verify your email again.")
    exp = row.verification_token_expires_at
    if not exp:
        raise ValueError("Email verification expired or invalid. Verify your email again.")
    exp_utc = exp if exp.tzinfo else exp.replace(tzinfo=timezone.utc)
    if now > exp_utc:
        raise ValueError("Email verification expired. Verify your email again.")
    row.consumed_at = now
    db.commit()
