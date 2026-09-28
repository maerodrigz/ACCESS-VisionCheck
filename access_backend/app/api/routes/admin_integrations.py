"""Admin: notification broadcast, system monitor."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_approved
from app.config import settings
from app.crud import announcement as announcement_crud
from app.crud import audit_log as audit_crud
from app.crud import notification as notification_crud
from app.crud import system_settings as settings_crud
from app.database import get_db, engine
from app.models.ai_detection_result import AiDetectionResult
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName, UserStatus
from app.models.facebook_post import FacebookPost
from app.models.login_history import LoginHistory
from app.models.media_file import MediaFile
from app.models.notification import Notification
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/admin", tags=["Admin Integrations"])


class BroadcastBody(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = Field(min_length=1)
    audience: str = Field(default="all", description="all | member | organization | admin")


@router.get("/notifications")
def list_all_notifications(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    rows = notification_crud.list_all(db, limit=200)
    return [
        {
            "id": n.id,
            "user_id": n.user_id,
            "user_name": n.user.fullname if n.user else "Unknown",
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "category": getattr(n, "category", None) or "system_alert",
            "priority": getattr(n, "priority", None) or "normal",
            "action_type": getattr(n, "action_type", None),
            "action_ref_id": getattr(n, "action_ref_id", None),
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in rows
    ]


@router.patch("/notifications/{notification_id}/read")
def admin_mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    row = notification_crud.get_by_id(db, notification_id)
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    updated = notification_crud.mark_read(db, row)
    return notification_crud.notification_to_dict(updated)


@router.post("/notifications/read-all", response_model=MessageResponse)
def admin_mark_all_notifications_read(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    count = notification_crud.mark_all_read_all(db)
    return MessageResponse(message=f"Marked {count} notifications as read")


@router.delete("/notifications/read", response_model=MessageResponse)
def admin_clear_read_notifications(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    count = notification_crud.delete_all_read(db)
    return MessageResponse(message=f"Cleared {count} read notifications")


@router.post("/notifications/broadcast", response_model=MessageResponse)
def broadcast_notifications(
    body: BroadcastBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    audience = body.audience.strip().lower()
    q = select(User.id).where(User.status == UserStatus.APPROVED)
    if audience == "member":
        q = q.where(User.role.has(Role.role_name == RoleName.MEMBER))
    elif audience == "organization":
        q = q.where(User.role.has(Role.role_name == RoleName.ORGANIZATION))
    elif audience == "admin":
        q = q.where(User.role.has(Role.role_name == RoleName.ADMIN))
    user_ids = list(db.scalars(q))
    count = 0
    announcement = announcement_crud.create(
        db,
        title=body.title,
        content=body.message,
        posted_by=admin.id,
    )
    if settings_crud.is_notification_enabled(db, "notify_new_announcement"):
        count = notification_crud.broadcast(
            db,
            user_ids,
            body.title,
            body.message,
            category="announcement",
            action_type="view_announcement",
            action_ref_id=announcement.id,
        )
    audit_crud.create(
        db,
        user_id=admin.id,
        action="notification_broadcast",
        description=f"Sent to {count} users ({audience})",
    )
    return MessageResponse(message=f"Broadcast sent to {count} users")


@router.get("/system-monitor")
def system_monitor(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    started = datetime.now(timezone.utc)
    db_ok = True
    db_error = None
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        db_ok = False
        db_error = str(exc)

    table_counts = {
        "users": db.scalar(select(func.count()).select_from(User)) or 0,
        "documentation_requests": db.scalar(select(func.count()).select_from(DocumentationRequest)) or 0,
        "media_files": db.scalar(select(func.count()).select_from(MediaFile)) or 0,
        "notifications": db.scalar(select(func.count()).select_from(Notification)) or 0,
        "facebook_posts": db.scalar(select(func.count()).select_from(FacebookPost)) or 0,
        "active_sessions": db.scalar(select(func.count()).select_from(UserSession)) or 0,
        "login_history": db.scalar(select(func.count()).select_from(LoginHistory)) or 0,
        "ai_flagged": db.scalar(
            select(func.count()).select_from(AiDetectionResult).where(
                AiDetectionResult.detection_result == "ai_generated"
            )
        )
        or 0,
    }

    logs = audit_crud.list_recent(db, limit=25)
    elapsed_ms = int((datetime.now(timezone.utc) - started).total_seconds() * 1000)

    return {
        "api_status": "ok",
        "database": {"connected": db_ok, "error": db_error, "name": settings.db_name},
        "public_url": settings.public_api_url,
        "response_ms": elapsed_ms,
        "table_counts": table_counts,
        "audit_logs": [
            {
                "id": log.id,
                "action": log.action,
                "description": log.description,
                "user_name": log.user.fullname if log.user else "System",
                "created_at": log.created_at.isoformat() if log.created_at else None,
            }
            for log in logs
        ],
    }
