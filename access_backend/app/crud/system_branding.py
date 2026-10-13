"""CRUD for system branding (logo + display names)."""

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.system_branding import (
    DEFAULT_APP_NAME,
    DEFAULT_ORGANIZATION,
    DEFAULT_SHORT_TAGLINE,
    DEFAULT_TAGLINE,
    SystemBranding,
)

BRANDING_ROW_ID = 1


def get_or_create(db: Session) -> SystemBranding:
    row = db.get(SystemBranding, BRANDING_ROW_ID)
    if not row:
        row = SystemBranding(id=BRANDING_ROW_ID)
        db.add(row)
        db.flush()
    return row


def _row_safe(db: Session) -> SystemBranding | None:
    try:
        return db.get(SystemBranding, BRANDING_ROW_ID)
    except Exception:
        db.rollback()
        return None


def _resolved_names(row: SystemBranding | None) -> dict:
    tagline = (row.tagline if row and row.tagline else None) or DEFAULT_TAGLINE
    stored_short = (row.short_tagline if row and row.short_tagline else None)
    # General settings writes [tagline] (system description); login reads [short_tagline].
    short_tagline = tagline if (row and row.tagline) else (stored_short or DEFAULT_SHORT_TAGLINE)
    return {
        "app_name": (row.app_name if row and row.app_name else None) or DEFAULT_APP_NAME,
        "tagline": tagline,
        "short_tagline": short_tagline,
        "organization": (row.organization if row and row.organization else None)
        or DEFAULT_ORGANIZATION,
        "web_admin_title": f"{(row.app_name if row and row.app_name else None) or DEFAULT_APP_NAME} - Admin",
    }


def _names_are_custom(row: SystemBranding | None) -> bool:
    if not row:
        return False
    return any(
        [
            row.app_name,
            row.tagline,
            row.short_tagline,
            row.organization,
        ]
    )


def branding_payload(db: Session) -> dict:
    """JSON-safe branding state for API responses."""
    row = _row_safe(db)
    names = _resolved_names(row)
    logo_path = row.logo_path if row else None
    updated = row.updated_at.isoformat() if row and row.updated_at else None
    return {
        "logo_url": logo_path,
        "updated_at": updated,
        "is_custom": bool(logo_path),
        "names_custom": _names_are_custom(row),
        **names,
        "defaults": {
            "app_name": DEFAULT_APP_NAME,
            "tagline": DEFAULT_TAGLINE,
            "short_tagline": DEFAULT_SHORT_TAGLINE,
            "organization": DEFAULT_ORGANIZATION,
        },
    }


def set_logo(db: Session, logo_path: str, user_id: int | None) -> SystemBranding:
    row = get_or_create(db)
    row.logo_path = logo_path
    row.updated_by = user_id
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row


def clear_logo(db: Session, user_id: int | None) -> SystemBranding:
    row = get_or_create(db)
    row.logo_path = None
    row.updated_by = user_id
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row


def update_names(
    db: Session,
    *,
    user_id: int | None,
    app_name: str | None = None,
    tagline: str | None = None,
    short_tagline: str | None = None,
    organization: str | None = None,
) -> SystemBranding:
    row = get_or_create(db)
    if app_name is not None:
        row.app_name = app_name.strip() or None
    if tagline is not None:
        row.tagline = tagline.strip() or None
    if short_tagline is not None:
        row.short_tagline = short_tagline.strip() or None
    elif tagline is not None:
        row.short_tagline = row.tagline
    if organization is not None:
        row.organization = organization.strip() or None
    row.updated_by = user_id
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row


def reset_names(db: Session, user_id: int | None) -> SystemBranding:
    row = get_or_create(db)
    row.app_name = None
    row.tagline = None
    row.short_tagline = None
    row.organization = None
    row.updated_by = user_id
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row
