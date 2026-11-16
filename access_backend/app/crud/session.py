"""user_sessions and login_history."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.login_history import LoginHistory
from app.models.user_session import UserSession


def _aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def record_login(
    db: Session,
    user_id: int,
    *,
    ip_address: str | None = None,
    device_info: str | None = None,
) -> LoginHistory:
    row = LoginHistory(
        user_id=user_id,
        ip_address=ip_address,
        device_info=device_info,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def create_session(db: Session, user_id: int, token: str, *, expire_minutes: int | None = None) -> UserSession:
    minutes = expire_minutes if expire_minutes is not None else settings.jwt_expire_minutes
    expires = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    row = UserSession(user_id=user_id, token=token, expires_at=expires)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_active_session(db: Session, token: str) -> UserSession | None:
    """Return the tracked session for this exact JWT if present and not expired."""
    raw = (token or "").strip()
    if not raw:
        return None
    row = db.scalar(select(UserSession).where(UserSession.token == raw))
    if row is None:
        return None
    if _aware_utc(row.expires_at) <= datetime.now(timezone.utc):
        db.delete(row)
        db.commit()
        return None
    return row


def revoke_session_token(db: Session, token: str) -> bool:
    """Delete the session row for one JWT. Returns True if a row was removed."""
    raw = (token or "").strip()
    if not raw:
        return False
    row = db.scalar(select(UserSession).where(UserSession.token == raw))
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def revoke_sessions_for_user(db: Session, user_id: int) -> None:
    rows = db.scalars(select(UserSession).where(UserSession.user_id == user_id)).all()
    for row in rows:
        db.delete(row)
    db.commit()
