"""user_sessions and login_history."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.login_history import LoginHistory
from app.models.user_session import UserSession


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


def revoke_sessions_for_user(db: Session, user_id: int) -> None:
    rows = db.scalars(select(UserSession).where(UserSession.user_id == user_id)).all()
    for row in rows:
        db.delete(row)
    db.commit()
