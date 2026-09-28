"""Shared guards for Facebook publish routes."""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.crud import system_settings as settings_crud


def ensure_facebook_publishing_enabled(db: Session) -> None:
    cfg = settings_crud.settings_payload(db)
    if not cfg.get("enable_facebook_publishing", True):
        raise HTTPException(
            status_code=403,
            detail="Facebook publishing is disabled in System Configuration.",
        )
