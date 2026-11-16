"""Security policy helpers — reads system_settings and enforces login/password rules."""

from datetime import datetime, timedelta, timezone
import logging

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.crud import system_settings as settings_crud
from app.models.user import User

logger = logging.getLogger(__name__)

SECURITY_DEFAULTS = {
    "min_password_length": 8,
    "session_timeout_minutes": 60,
    "max_login_attempts": 5,
    "account_lockout_minutes": 30,
}


def is_auth_lockout_enforced() -> bool:
    """Whether failed-login lockout gates apply.

    Always True in production (APP_ENV=production|prod), even if
    AUTH_LOCKOUT_ENABLED was somehow set false. Local UI testing may set
    AUTH_LOCKOUT_ENABLED=false under APP_ENV=development|testing.
    """
    from app.config import settings

    if settings.is_production:
        return True
    return bool(settings.auth_lockout_enabled)


def security_config(db: Session) -> dict:
    payload = settings_crud.settings_payload(db)
    return {
        "min_password_length": int(
            payload.get("min_password_length", SECURITY_DEFAULTS["min_password_length"])
        ),
        "session_timeout_minutes": int(
            payload.get("session_timeout_minutes", SECURITY_DEFAULTS["session_timeout_minutes"])
        ),
        "max_login_attempts": int(
            payload.get("max_login_attempts", SECURITY_DEFAULTS["max_login_attempts"])
        ),
        "account_lockout_minutes": int(
            payload.get("account_lockout_minutes", SECURITY_DEFAULTS["account_lockout_minutes"])
        ),
    }


def assert_password_meets_policy(db: Session, password: str) -> None:
    cfg = security_config(db)
    minimum = cfg["min_password_length"]
    if len(password) < minimum:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Password must be at least {minimum} characters.",
        )


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def is_account_locked(user: User) -> bool:
    """True when login must be rejected due to an active lockout.

    When AUTH_LOCKOUT_ENABLED is false in non-production, existing
    ``locked_until`` rows are left untouched but are not enforced.
    """
    if not is_auth_lockout_enforced():
        return False
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return False
    return _as_utc(locked_until) > datetime.now(timezone.utc)


def lockout_remaining_minutes(user: User) -> int | None:
    """Whole minutes left on an active lockout, or None if not locked."""
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return None
    remaining = _as_utc(locked_until) - datetime.now(timezone.utc)
    seconds = remaining.total_seconds()
    if seconds <= 0:
        return None
    return max(1, int((seconds + 59) // 60))


def lockout_detail_message(user: User) -> str:
    minutes = lockout_remaining_minutes(user)
    if minutes is None:
        return (
            "Account temporarily locked due to too many failed sign-in attempts. "
            "Try again later."
        )
    unit = "minute" if minutes == 1 else "minutes"
    return (
        "Account temporarily locked due to too many failed sign-in attempts. "
        f"Try again in about {minutes} {unit}."
    )


def record_failed_login(db: Session, user: User) -> None:
    """Increment failed-login counter; apply lockout only when enforcement is on.

    Always logs the attempt via ``failed_login_count``. Does not clear or rewrite
    an existing ``locked_until`` when lockout is temporarily disabled for local UI work.
    """
    cfg = security_config(db)
    user.failed_login_count = int(getattr(user, "failed_login_count", 0) or 0) + 1
    if is_auth_lockout_enforced() and user.failed_login_count >= cfg["max_login_attempts"]:
        user.locked_until = datetime.now(timezone.utc) + timedelta(
            minutes=cfg["account_lockout_minutes"]
        )
        user.failed_login_count = 0
    elif not is_auth_lockout_enforced():
        logger.info(
            "auth_lockout_disabled: recorded failed login for user_id=%s count=%s (no lock applied)",
            getattr(user, "id", None),
            user.failed_login_count,
        )
    db.commit()


def clear_login_failures(db: Session, user: User) -> None:
    user.failed_login_count = 0
    user.locked_until = None
    db.commit()
