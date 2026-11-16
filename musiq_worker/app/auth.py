"""Bearer-token auth for private worker routes."""

from __future__ import annotations

import hmac

from fastapi import Header, HTTPException, status

from app.config import get_settings


def require_worker_token(
    authorization: str | None = Header(default=None),
) -> None:
    settings = get_settings()
    expected = (settings.musiq_worker_token or "").strip()
    if not expected:
        if settings.allow_insecure_empty_token:
            return
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Worker token not configured",
        )
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    provided = authorization.split(" ", 1)[1].strip()
    if not hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
