"""Upload rules for event documentation vs member AI evaluation (separate workflows)."""

from __future__ import annotations

import re
from typing import Literal

from sqlalchemy.orm import Session

from app.config import settings
from app.crud import system_settings as settings_crud
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION, MEDIA_CATEGORY_EVENT

Workflow = Literal["event_documentation", "member_evaluation"]

DEFAULT_IMAGE_EXTENSIONS: tuple[str, ...] = (".jpg", ".jpeg", ".png", ".gif", ".webp")
DEFAULT_VIDEO_EXTENSIONS: tuple[str, ...] = (".mp4", ".mov", ".avi", ".webm")

_EXT_PATTERN = re.compile(r"^\.[a-z0-9]+$")


def default_event_max_upload_mb() -> int:
    return int(settings.max_upload_mb)


def default_evaluation_max_upload_mb() -> int:
    return int(settings.evaluation_max_upload_mb)


def extensions_to_list(raw: str | None, defaults: tuple[str, ...]) -> list[str]:
    if not raw or not str(raw).strip():
        return list(defaults)
    out: list[str] = []
    for part in str(raw).split(","):
        ext = part.strip().lower()
        if ext and ext not in out:
            out.append(ext)
    return out or list(defaults)


def extensions_to_set(raw: str | None, defaults: tuple[str, ...]) -> frozenset[str]:
    return frozenset(extensions_to_list(raw, defaults))


def normalize_extensions_csv(raw: str) -> str:
    parts: list[str] = []
    for part in raw.split(","):
        ext = part.strip().lower()
        if not ext:
            continue
        if not ext.startswith("."):
            ext = f".{ext}"
        if not _EXT_PATTERN.match(ext):
            raise ValueError(f"Invalid extension '{part.strip()}'. Use values like .jpg, .mp4")
        if ext not in parts:
            parts.append(ext)
    if not parts:
        raise ValueError("At least one file extension is required.")
    return ",".join(parts)


def _cfg(db: Session) -> dict:
    return settings_crud.settings_payload(db)


def event_rules(db: Session) -> dict:
    cfg = _cfg(db)
    env_default = default_event_max_upload_mb()
    max_mb = int(cfg.get("event_max_upload_mb") or env_default)
    return {
        "workflow": MEDIA_CATEGORY_EVENT,
        "max_upload_mb": max_mb,
        "allowed_image_formats": extensions_to_list(
            cfg.get("event_allowed_image_formats"), DEFAULT_IMAGE_EXTENSIONS
        ),
        "allowed_video_formats": extensions_to_list(
            cfg.get("event_allowed_video_formats"), DEFAULT_VIDEO_EXTENSIONS
        ),
    }


def evaluation_rules(db: Session) -> dict:
    cfg = _cfg(db)
    env_default = default_evaluation_max_upload_mb()
    max_mb = int(cfg.get("evaluation_max_upload_mb") or env_default)
    return {
        "workflow": MEDIA_CATEGORY_EVALUATION,
        "max_upload_mb": max_mb,
        "max_files_per_day": int(cfg.get("max_evaluation_uploads_per_day") or 5),
        "allowed_image_formats": extensions_to_list(
            cfg.get("evaluation_allowed_image_formats"), DEFAULT_IMAGE_EXTENSIONS
        ),
        "allowed_video_formats": extensions_to_list(
            cfg.get("evaluation_allowed_video_formats"), DEFAULT_VIDEO_EXTENSIONS
        ),
    }


def rules_for_category(db: Session, media_category: str) -> dict:
    if media_category == MEDIA_CATEGORY_EVALUATION:
        return evaluation_rules(db)
    return event_rules(db)


def is_allowed_extension(db: Session, ext: str, media_category: str) -> bool:
    normalized = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
    rules = rules_for_category(db, media_category)
    allowed = frozenset(rules["allowed_image_formats"]) | frozenset(rules["allowed_video_formats"])
    return normalized in allowed


def is_video_extension(db: Session, ext: str, media_category: str) -> bool:
    normalized = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
    rules = rules_for_category(db, media_category)
    return normalized in frozenset(rules["allowed_video_formats"])


def admin_media_payload(db: Session, *, storage_usage_percent: float | None = None) -> dict:
    cfg = _cfg(db)
    return {
        "event_documentation": {
            **event_rules(db),
            "allow_late_media_uploads": cfg["allow_late_media_uploads"],
            "max_upload_period_days": cfg["max_upload_period_days"],
            "require_event_album_before_upload": cfg["require_event_album_before_upload"],
            "enable_facebook_publishing": cfg["enable_facebook_publishing"],
        },
        "member_evaluation": evaluation_rules(db),
        "defaults": {
            "event_max_upload_mb": default_event_max_upload_mb(),
            "evaluation_max_upload_mb": default_evaluation_max_upload_mb(),
            "max_evaluation_uploads_per_day": 5,
            "allowed_image_formats": list(DEFAULT_IMAGE_EXTENSIONS),
            "allowed_video_formats": list(DEFAULT_VIDEO_EXTENSIONS),
        },
        "storage_usage_percent": storage_usage_percent,
    }
