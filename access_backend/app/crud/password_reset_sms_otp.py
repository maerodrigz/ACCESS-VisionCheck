"""CRUD for password reset SMS OTP."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.crud.sms_otp_common import ensure_aware, generate_otp_code, hash_otp, utcnow
from app.models.password_reset_sms_otp import PasswordResetSmsOtp
from app.models.phone_verification_otp import PhoneVerificationOtp
from app.services import sms_delivery
from app.services import sms_rate_limit


def _daily_send_count(db: Session) -> int:
    start = utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    reset_n = db.scalar(
        select(func.count()).select_from(PasswordResetSmsOtp).where(PasswordResetSmsOtp.last_sent_at >= start)
    ) or 0
    verify_n = db.scalar(
        select(func.count()).select_from(PhoneVerificationOtp).where(PhoneVerificationOtp.last_sent_at >= start)
    ) or 0
    return int(reset_n) + int(verify_n)


def _daily_phone_count(db: Session, phone_e164: str) -> int:
    start = utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    reset_n = db.scalar(
        select(func.count())
        .select_from(PasswordResetSmsOtp)
        .where(
            PasswordResetSmsOtp.phone_e164 == phone_e164,
            PasswordResetSmsOtp.last_sent_at >= start,
        )
    ) or 0
    verify_n = db.scalar(
        select(func.count())
        .select_from(PhoneVerificationOtp)
        .where(
            PhoneVerificationOtp.phone_e164 == phone_e164,
            PhoneVerificationOtp.last_sent_at >= start,
        )
    ) or 0
    return int(reset_n) + int(verify_n)


def enforce_send_budgets(db: Session, phone_e164: str, *, client_ip: str | None) -> None:
    if _daily_send_count(db) >= settings.sms_daily_budget_global:
        raise ValueError("SMS service is temporarily unavailable. Please try again later.")
    if _daily_phone_count(db, phone_e164) >= settings.sms_daily_budget_per_phone:
        raise ValueError("Too many SMS requests for this number. Please try again later.")
    ip = (client_ip or "unknown").strip() or "unknown"
    sms_rate_limit.check_and_record(
        key=f"ip:{ip}",
        limit=settings.sms_rate_limit_per_ip_hour,
        window_s=3600.0,
    )
    sms_rate_limit.check_and_record(
        key=f"phone:{phone_e164}",
        limit=settings.sms_rate_limit_per_phone_hour,
        window_s=3600.0,
    )


def send_otp(
    db: Session,
    phone_e164: str,
    *,
    fullname: str = "",
    client_ip: str | None = None,
    actually_deliver: bool = True,
) -> str:
    """
    Create a hashed OTP row. When actually_deliver is False (enumeration / unverified),
    still consume rate budgets lightly via cooldown simulation? No — caller decides.
    Returns plaintext code only for log-provider dev_code path; callers must not log it.
    """
    now = utcnow()
    row = db.scalar(
        select(PasswordResetSmsOtp)
        .where(PasswordResetSmsOtp.phone_e164 == phone_e164)
        .order_by(PasswordResetSmsOtp.id.desc())
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
        PasswordResetSmsOtp(
            phone_e164=phone_e164,
            code_hash=hash_otp(code),
            expires_at=expires,
            attempt_count=0,
            last_sent_at=now,
            created_at=now,
        )
    )
    db.commit()

    if actually_deliver:
        name = (fullname or "").strip() or "there"
        body = (
            f"ACCESS VisionCheck password reset code: {code}. "
            f"Expires in {settings.sms_reset_otp_expire_minutes} minutes. Do not share."
        )
        # name reserved for future personalization; avoid unused warning
        _ = name
        ok = sms_delivery.send_sms(to_e164=phone_e164, message=body)
        if not ok:
            raise ValueError("Could not send SMS right now. Please try again later.")

    return code


def verify_and_consume(db: Session, phone_e164: str, code: str) -> None:
    now = utcnow()
    row = db.scalar(
        select(PasswordResetSmsOtp)
        .where(
            PasswordResetSmsOtp.phone_e164 == phone_e164,
            PasswordResetSmsOtp.consumed_at.is_(None),
        )
        .order_by(PasswordResetSmsOtp.id.desc())
        .limit(1)
    )
    if not row:
        raise ValueError("No active reset code for this number. Request a new code.")
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
