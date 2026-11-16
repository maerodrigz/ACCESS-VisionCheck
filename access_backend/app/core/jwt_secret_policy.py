"""JWT_SECRET strength checks — never log or return the secret value."""

from __future__ import annotations

# Documented / historical placeholders that must never be accepted at runtime.
INSECURE_JWT_SECRETS = frozenset(
    {
        "",
        "change_this_secret",
        "access_visioncheck_dev_secret",
        "secret",
        "jwt_secret",
        "your-secret-key",
        "dev-secret",
    }
)

# 32+ chars of high-entropy material (e.g. urlsafe token / hex).
MIN_JWT_SECRET_LENGTH = 32

JWT_SECRET_REQUIREMENTS_MESSAGE = (
    "JWT_SECRET is missing or insecure. Set JWT_SECRET in access_backend/.env to a "
    f"random secret of at least {MIN_JWT_SECRET_LENGTH} characters. "
    "Do not use documented placeholders (change_this_secret, access_visioncheck_dev_secret). "
    "Generate one locally (PowerShell): "
    "[Convert]::ToBase64String((1..48|ForEach-Object{Get-Random -Max 256}) -as [byte[]])"
)


def is_insecure_jwt_secret(secret: str | None) -> bool:
    value = (secret or "").strip()
    if len(value) < MIN_JWT_SECRET_LENGTH:
        return True
    return value.lower() in {s.lower() for s in INSECURE_JWT_SECRETS if s}


def validate_jwt_secret(secret: str | None) -> str:
    """Return stripped secret or raise ValueError with safe operator guidance."""
    value = (secret or "").strip()
    if is_insecure_jwt_secret(value):
        raise ValueError(JWT_SECRET_REQUIREMENTS_MESSAGE)
    return value
