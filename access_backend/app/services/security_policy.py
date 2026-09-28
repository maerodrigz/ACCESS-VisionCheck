"""Security policy helpers — reads system_settings and enforces login/password rules."""

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.crud import system_settings as settings_crud
from app.models.user import User

SECURITY_DEFAULTS = {
    "min_password_length": 8,
    "session_timeout_minutes": 60,
    "max_login_attempts": 5,
    "account_lockout_minutes": 30,
}


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


def is_account_locked(user: User) -> bool:
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return False
    now = datetime.now(timezone.utc)
    if locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=timezone.utc)
    return locked_until > now


def record_failed_login(db: Session, user: User) -> None:
    cfg = security_config(db)
    user.failed_login_count = int(getattr(user, "failed_login_count", 0) or 0) + 1
    if user.failed_login_count >= cfg["max_login_attempts"]:
        user.locked_until = datetime.now(timezone.utc) + timedelta(
            minutes=cfg["account_lockout_minutes"]
        )
        user.failed_login_count = 0
    db.commit()


def clear_login_failures(db: Session, user: User) -> None:
    user.failed_login_count = 0
    user.locked_until = None
    db.commit()
