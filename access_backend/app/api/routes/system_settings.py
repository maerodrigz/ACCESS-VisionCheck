"""Admin: system-wide configuration."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.config import settings
from app.crud import audit_log as audit_crud
from app.crud import system_branding as branding_crud
from app.crud import system_settings as settings_crud
from app.database import get_db
from app.models.media_file import MediaFile
from app.models.system_branding import SystemBranding
from app.models.user import User
from app.services.efficientnet_b0_scorer import MODEL_ID, efficientnet_available
from app.services.media_evaluator import SCORING_ENGINE
from app.services.media_upload_config import admin_media_payload
from app.services.security_policy import SECURITY_DEFAULTS
from app.schemas.system_settings import (
    AiEvaluationSettingsBody,
    GeneralSettingsBody,
    MediaSettingsBody,
    NotificationSettingsBody,
    SecuritySettingsBody,
)

router = APIRouter(prefix="/admin/system-settings", tags=["System Settings"])


def _facebook_status() -> dict:
    page_id_set = bool((settings.facebook_page_id or "").strip())
    token_set = bool((settings.facebook_page_access_token or "").strip())
    missing: list[str] = []
    if not page_id_set:
        missing.append("FACEBOOK_PAGE_ID")
    if not token_set:
        missing.append("FACEBOOK_PAGE_ACCESS_TOKEN")
    return {
        "configured": page_id_set and token_set,
        "page_id_set": page_id_set,
        "access_token_set": token_set,
        "missing": missing,
    }


def _storage_usage_percent(db: Session) -> float:
    media_files = db.scalar(select(func.count()).select_from(MediaFile)) or 0
    users = db.scalar(select(func.count()).select_from(User)) or 1
    estimated = ((media_files * 2.5 + users * 0.1) / 1000 * 100)
    return round(max(12.0, min(96.0, estimated)), 1)


def _ai_evaluation_payload(cfg: dict) -> dict:
    """Public AI evaluation config — never exposes keys, weights paths, or credentials."""
    return {
        "enabled": cfg["enable_ai_media_evaluation"],
        "quality_model": {
            "id": MODEL_ID,
            "name": "EfficientNet-B0",
            "engine": SCORING_ENGINE,
            "description": (
                "EfficientNet-B0 analyzes uploaded photos and video frames to score technical "
                "quality — sharpness, blur, noise, brightness, contrast, and compression artifacts."
            ),
            "available_on_server": efficientnet_available(),
            "configurable": False,
        },
        "feedback_generation": {
            "name": "Gemini",
            "description": (
                "After EfficientNet-B0 produces criterion scores, Gemini receives those results "
                "and generates encouraging, human-friendly feedback for members. Gemini does not "
                "change or invent scores."
            ),
            "configured": bool((settings.gemini_api_key or "").strip()),
            "model": (settings.gemini_model or "").strip() or "gemini-3.8-flash",
            "configurable": False,
        },
        "max_evaluation_uploads_per_day": cfg["max_evaluation_uploads_per_day"],
    }


def _full_payload(db: Session) -> dict:
    branding = branding_crud.branding_payload(db)
    cfg = settings_crud.settings_payload(db)
    updated_by = None
    try:
        row = db.get(SystemBranding, branding_crud.BRANDING_ROW_ID)
        if row and row.updater:
            updated_by = row.updater.fullname
    except Exception:
        db.rollback()

    defaults = branding.get("defaults") or {}
    return {
        "general": {
            "app_name": branding["app_name"],
            "organization": branding["organization"],
            "system_description": branding["tagline"],
            "names_custom": branding.get("names_custom", False),
            "defaults": {
                "app_name": defaults.get("app_name"),
                "organization": defaults.get("organization"),
                "system_description": defaults.get("tagline"),
            },
        },
        "notifications": {
            "email_available": False,
            "in_app": {key: cfg[key] for key in settings_crud.NOTIFICATION_PREF_KEYS},
        },
        "ai_evaluation": _ai_evaluation_payload(cfg),
        "media": {
            **admin_media_payload(db, storage_usage_percent=_storage_usage_percent(db)),
            "facebook": _facebook_status(),
        },
        "security": {
            "min_password_length": cfg["min_password_length"],
            "session_timeout_minutes": cfg["session_timeout_minutes"],
            "max_login_attempts": cfg["max_login_attempts"],
            "account_lockout_minutes": cfg["account_lockout_minutes"],
            "defaults": {
                "min_password_length": SECURITY_DEFAULTS["min_password_length"],
                "session_timeout_minutes": SECURITY_DEFAULTS["session_timeout_minutes"],
                "max_login_attempts": SECURITY_DEFAULTS["max_login_attempts"],
                "account_lockout_minutes": SECURITY_DEFAULTS["account_lockout_minutes"],
            },
            "ranges": {
                "min_password_length": {"min": 6, "max": 32},
                "session_timeout_minutes": {"min": 5, "max": 480},
                "max_login_attempts": {"min": 3, "max": 20},
                "account_lockout_minutes": {"min": 5, "max": 1440},
            },
        },
        "meta": {
            "updated_at": cfg.get("updated_at"),
            "updated_by": updated_by,
            "public_api_url": settings.public_api_url,
        },
    }


def _body_fields(body: BaseModel) -> dict:
    return {k: v for k, v in body.model_dump().items() if v is not None}


@router.get("")
def get_system_settings(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return _full_payload(db)


@router.patch("/general")
def patch_general_settings(
    body: GeneralSettingsBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    description = body.system_description.strip()
    branding_crud.update_names(
        db,
        user_id=admin.id,
        app_name=body.app_name.strip(),
        organization=body.organization.strip(),
        tagline=description,
        short_tagline=description,
    )
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_general",
        description="Updated general system settings",
    )
    return {"message": "General settings saved.", **_full_payload(db)}


@router.post("/general/reset")
def reset_general_settings(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    branding_crud.reset_names(db, admin.id)
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_general_reset",
        description="Reset general system settings to defaults",
    )
    return {"message": "General settings reset to defaults.", **_full_payload(db)}


@router.patch("/notifications")
def patch_notification_settings(
    body: NotificationSettingsBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    fields = _body_fields(body)
    if fields:
        settings_crud.update_section(db, user_id=admin.id, fields=fields)
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_notifications",
        description="Updated notification settings",
    )
    return {"message": "Notification settings saved.", **_full_payload(db)}


@router.patch("/ai-evaluation")
def patch_ai_evaluation_settings(
    body: AiEvaluationSettingsBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    fields: dict = {}
    if body.enabled is not None:
        fields["enable_ai_media_evaluation"] = body.enabled
    if fields:
        settings_crud.update_section(db, user_id=admin.id, fields=fields)
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_ai_evaluation",
        description="Updated AI evaluation settings",
    )
    return {"message": "AI evaluation settings saved.", **_full_payload(db)}


@router.patch("/media")
def patch_media_settings(
    body: MediaSettingsBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    fields = _body_fields(body)
    if fields:
        settings_crud.update_section(db, user_id=admin.id, fields=fields)
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_media",
        description="Updated media settings",
    )
    return {"message": "Media settings saved.", **_full_payload(db)}


@router.patch("/security")
def patch_security_settings(
    body: SecuritySettingsBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    fields = _body_fields(body)
    if fields:
        settings_crud.update_section(db, user_id=admin.id, fields=fields)
    audit_crud.create(
        db,
        user_id=admin.id,
        action="system_settings_security",
        description="Updated security settings",
    )
    return {"message": "Security settings saved.", **_full_payload(db)}
