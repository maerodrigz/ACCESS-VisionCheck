"""JWT tokens and password hashing (bcrypt)."""

from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt

from app.config import settings


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    if not plain or not hashed:
        return False
    stored = hashed.strip()
    if stored.startswith("$2"):
        try:
            return bcrypt.checkpw(plain.encode("utf-8"), stored.encode("utf-8"))
        except (ValueError, TypeError):
            return False
    # Legacy dev rows stored plain text; treat as valid once, then re-hash on login.
    return plain == stored


def password_hash_is_legacy(stored: str) -> bool:
    return not (stored or "").strip().startswith("$2")


def create_access_token(data: dict, *, expire_minutes: int | None = None) -> str:
    to_encode = data.copy()
    minutes = expire_minutes if expire_minutes is not None else settings.jwt_expire_minutes
    expire = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None
