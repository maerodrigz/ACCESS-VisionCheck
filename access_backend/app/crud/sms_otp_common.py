"""Shared helpers for SMS OTP hashing and code generation."""

from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timezone

from app.config import settings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def hash_otp(value: str) -> str:
    pepper = settings.jwt_secret or "access_otp_pepper"
    return hashlib.sha256(f"{pepper}:{value}".encode()).hexdigest()


def generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt
