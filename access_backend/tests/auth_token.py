"""Issue JWTs that are also registered in user_sessions (required by deps)."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.crud import session as session_crud
from app.models.user import User


def issue_bearer_token(
    db: Session,
    user: User,
    *,
    expire_minutes: int | None = None,
) -> str:
    role = user.role.role_name if user.role is not None else "member"
    token = create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": role,
        },
        expire_minutes=expire_minutes,
    )
    session_crud.create_session(db, user.id, token, expire_minutes=expire_minutes)
    return token
