"""CRUD for authenticated phone verification SMS OTP."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.crud.password_reset_sms_otp import enforce_send_budgets
from app.crud.sms_otp_common import ensure_aware, generate_otp_code, hash_otp, utcnow
from app.models.phone_verification_otp import PhoneVerificationOtp
from app.services import sms_delivery


def send_otp(
    db: Session,
    *,
    user_id: int,
    phone_e164: str,
    client_ip: str | None = None,
) -> str:
    now = utcnow()
    row = db.scalar(
        select(PhoneVerificationOtp)
        .where(
            PhoneVerificationOtp.user_id == user_id,
            PhoneVerificationOtp.phone_e164 == phone_e164,
        )
        .order_by(PhoneVerificationOtp.id.desc())
        .limit(1)
    )
    if row and row.last_sent_at:
        last = ensure_aware(row.last_sent_at)
        cooldown = timedelta(seconds=settings.sms_reset_otp_resend_seconds)
        elapsed = now - last
        if elapsed < cooldown:
            wait = int((cooldown - elapsed).total_seconds())
            raise ValueError(f"Please wait {max(wait, 1)} seconds before requesting another code.")

    enforce_send_budgets(db, phone_e164, client_ip=client_ip)

    code = generate_otp_code()
    expires = now + timedelta(minutes=settings.sms_reset_otp_expire_minutes)
    db.add(
        PhoneVerificationOtp(
            user_id=user_id,
            phone_e164=phone_e164,
            code_hash=hash_otp(code),
            expires_at=expires,
            attempt_count=0,
            last_sent_at=now,
            created_at=now,
        )
    )
    db.commit()

    body = (
        f"ACCESS VisionCheck phone verification code: {code}. "
        f"Expires in {settings.sms_reset_otp_expire_minutes} minutes. Do not share."
    )
    ok = sms_delivery.send_sms(to_e164=phone_e164, message=body)
    if not ok:
        raise ValueError("Could not send SMS right now. Please try again later.")
    return code


def verify_and_consume(db: Session, *, user_id: int, phone_e164: str, code: str) -> None:
    now = utcnow()
    row = db.scalar(
        select(PhoneVerificationOtp)
        .where(
            PhoneVerificationOtp.user_id == user_id,
            PhoneVerificationOtp.phone_e164 == phone_e164,
            PhoneVerificationOtp.consumed_at.is_(None),
        )
        .order_by(PhoneVerificationOtp.id.desc())
        .limit(1)
    )
    if not row:
        raise ValueError("No active verification code. Request a new code.")
    expires = ensure_aware(row.expires_at)
    if now > expires:
        raise ValueError("Verification code expired. Request a new code.")
    if row.attempt_count >= settings.sms_reset_otp_max_attempts:
        raise ValueError("Too many failed attempts. Request a new code.")

    normalized_code = (code or "").strip()
    if not normalized_code.isdigit() or len(normalized_code) != 6:
        row.attempt_count += 1
        db.commit()
        raise ValueError("Enter the 6-digit code from your SMS.")

    if hash_otp(normalized_code) != row.code_hash:
        row.attempt_count += 1
        db.commit()
        raise ValueError("Incorrect verification code.")

    row.consumed_at = now
    row.attempt_count = 0
    db.commit()
