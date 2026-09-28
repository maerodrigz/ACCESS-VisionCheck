"""CRUD for system-wide settings."""

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.models.system_settings import (
    DEFAULT_ACADEMIC_YEAR,
    DEFAULT_ORGANIZATION_EMAIL,
    SETTINGS_ROW_ID,
    SystemSettings,
)

NOTIFICATION_PREF_KEYS = (
    "notify_new_documentation_request",
    "notify_request_approved",
    "notify_request_rejected",
    "notify_new_documentation_assignment",
    "notify_evaluation_completed",
    "notify_new_announcement",
    "notify_system_alerts",
)

DEFAULTS = {
    "organization_email": DEFAULT_ORGANIZATION_EMAIL,
    "academic_year": DEFAULT_ACADEMIC_YEAR,
    "allow_late_media_uploads": True,
    "max_upload_period_days": 7,
    "require_event_album_before_upload": True,
    "enable_facebook_publishing": True,
    "enable_ai_detection": True,
    "ai_confidence_threshold": 0.75,
    "auto_generate_review_alerts": True,
    "require_manual_verification_before_warning": True,
    "enable_ai_media_evaluation": True,
    "max_evaluation_uploads_per_day": 5,
    "event_max_upload_mb": None,
    "evaluation_max_upload_mb": None,
    "event_allowed_image_formats": None,
    "event_allowed_video_formats": None,
    "evaluation_allowed_image_formats": None,
    "evaluation_allowed_video_formats": None,
    "notify_new_documentation_request": True,
    "notify_request_approved": True,
    "notify_request_rejected": True,
    "notify_new_documentation_assignment": True,
    "notify_evaluation_completed": False,
    "notify_new_announcement": True,
    "notify_system_alerts": True,
    "min_password_length": 8,
    "session_timeout_minutes": 60,
    "max_login_attempts": 5,
    "account_lockout_minutes": 30,
    "two_factor_enabled": False,
}


def get_or_create(db: Session) -> SystemSettings:
    row = db.get(SystemSettings, SETTINGS_ROW_ID)
    if not row:
        row = SystemSettings(id=SETTINGS_ROW_ID)
        db.add(row)
        db.flush()
    return row


def _row_safe(db: Session) -> SystemSettings | None:
    try:
        return db.get(SystemSettings, SETTINGS_ROW_ID)
    except Exception:
        db.rollback()
        return None


def _resolved(row: SystemSettings | None) -> dict:
    def _bool(key: str) -> bool:
        if row is None or not hasattr(row, key):
            return bool(DEFAULTS[key])
        return bool(getattr(row, key))

    def _int(key: str) -> int:
        if row is None or not hasattr(row, key):
            return int(DEFAULTS[key])
        return int(getattr(row, key))

    def _float(key: str) -> float:
        if row is None or not hasattr(row, key):
            return float(DEFAULTS[key])
        return float(getattr(row, key))

    def _str(key: str, default: str) -> str:
        if row is None or not hasattr(row, key):
            return default
        val = getattr(row, key)
        return (val.strip() if isinstance(val, str) else val) or default

    def _opt_int(key: str) -> int | None:
        if row is None or not hasattr(row, key):
            return DEFAULTS.get(key)
        return getattr(row, key)

    def _opt_str(key: str) -> str | None:
        if row is None or not hasattr(row, key):
            return DEFAULTS.get(key)
        val = getattr(row, key)
        if val is None:
            return None
        return str(val).strip() or None

    return {
        "organization_email": _str("organization_email", DEFAULT_ORGANIZATION_EMAIL),
        "academic_year": _str("academic_year", DEFAULT_ACADEMIC_YEAR),
        "allow_late_media_uploads": _bool("allow_late_media_uploads"),
        "max_upload_period_days": _int("max_upload_period_days"),
        "require_event_album_before_upload": _bool("require_event_album_before_upload"),
        "enable_facebook_publishing": _bool("enable_facebook_publishing"),
        "enable_ai_detection": _bool("enable_ai_detection"),
        "ai_confidence_threshold": _float("ai_confidence_threshold"),
        "auto_generate_review_alerts": _bool("auto_generate_review_alerts"),
        "require_manual_verification_before_warning": _bool(
            "require_manual_verification_before_warning"
        ),
        "enable_ai_media_evaluation": _bool("enable_ai_media_evaluation"),
        "max_evaluation_uploads_per_day": _int("max_evaluation_uploads_per_day"),
        "event_max_upload_mb": _opt_int("event_max_upload_mb"),
        "evaluation_max_upload_mb": _opt_int("evaluation_max_upload_mb"),
        "event_allowed_image_formats": _opt_str("event_allowed_image_formats"),
        "event_allowed_video_formats": _opt_str("event_allowed_video_formats"),
        "evaluation_allowed_image_formats": _opt_str("evaluation_allowed_image_formats"),
        "evaluation_allowed_video_formats": _opt_str("evaluation_allowed_video_formats"),
        **{key: _bool(key) for key in NOTIFICATION_PREF_KEYS},
        "min_password_length": _int("min_password_length"),
        "session_timeout_minutes": _int("session_timeout_minutes"),
        "max_login_attempts": _int("max_login_attempts"),
        "account_lockout_minutes": _int("account_lockout_minutes"),
        "two_factor_enabled": _bool("two_factor_enabled"),
        "updated_at": row.updated_at.isoformat() if row and row.updated_at else None,
    }


def settings_payload(db: Session) -> dict:
    row = _row_safe(db)
    return _resolved(row)


def notification_prefs(db: Session) -> dict[str, bool]:
    payload = settings_payload(db)
    return {key: bool(payload.get(key, DEFAULTS[key])) for key in NOTIFICATION_PREF_KEYS}


def is_notification_enabled(db: Session, key: str) -> bool:
    if key not in NOTIFICATION_PREF_KEYS:
        return True
    return notification_prefs(db).get(key, True)


def is_ai_media_evaluation_enabled(db: Session) -> bool:
    return bool(settings_payload(db).get("enable_ai_media_evaluation", True))


def max_evaluation_uploads_per_day(db: Session) -> int:
    return int(settings_payload(db).get("max_evaluation_uploads_per_day", 5))


def update_section(
    db: Session,
    *,
    user_id: int | None,
    fields: dict,
) -> SystemSettings:
    row = get_or_create(db)
    for key, value in fields.items():
        if hasattr(row, key):
            setattr(row, key, value)
    row.updated_by = user_id
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row
