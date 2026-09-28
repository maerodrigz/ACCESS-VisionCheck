"""Create notifications when platform events occur."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.crud import member_notification_preference as member_pref_crud
from app.crud import notification as notification_crud
from app.crud import system_settings as settings_crud
from app.models.enums import RoleName, UserStatus
from app.models.role import Role
from app.models.user import User


def _admin_user_ids(db: Session) -> list[int]:
    return list(
        db.scalars(
            select(User.id)
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.ADMIN)
        )
    )


def notify_user(
    db: Session,
    user_id: int,
    *,
    title: str,
    message: str,
    category: str = "system_alert",
    priority: str = "normal",
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> None:
    if not member_pref_crud.allows_category(db, user_id, category):
        return
    notification_crud.create(
        db,
        user_id,
        title,
        message,
        category=category,
        priority=priority,
        action_type=action_type,
        action_ref_id=action_ref_id,
    )


def notify_admins(
    db: Session,
    *,
    title: str,
    message: str,
    category: str = "system_alert",
    priority: str = "normal",
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> int:
    ids = _admin_user_ids(db)
    if not ids:
        return 0
    return notification_crud.broadcast(
        db,
        ids,
        title,
        message,
        category=category,
        priority=priority,
        action_type=action_type,
        action_ref_id=action_ref_id,
    )


def notify_documentation_request_submitted(db: Session, request_id: int, title: str, requester: str) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_request"):
        return
    notify_admins(
        db,
        title="New documentation request",
        message=f'{requester} submitted "{title}" for review.',
        category="documentation_request",
        priority="high",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_documentation_request_resubmitted(
    db: Session,
    request_id: int,
    title: str,
    requester: str,
    *,
    event_date: str,
    previous_status: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_request"):
        return
    notify_admins(
        db,
        title="Documentation request resubmitted",
        message=(
            f'{requester} rescheduled "{title}" to {event_date} '
            f'(previously {previous_status}). Admin review is required.'
        ),
        category="documentation_request",
        priority="high",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_documentation_request_status(
    db: Session,
    user_id: int,
    request_id: int,
    title: str,
    status: str,
    rejection_reason: str | None = None,
) -> None:
    st = status.strip().lower()
    if st == "approved":
        if not settings_crud.is_notification_enabled(db, "notify_request_approved"):
            return
        msg = f'Your documentation request "{title}" was approved.'
        notif_title = "Request approved"
        priority = "high"
    elif st == "rejected":
        if not settings_crud.is_notification_enabled(db, "notify_request_rejected"):
            return
        reason = (rejection_reason or "").strip()
        if reason:
            msg = f'Your documentation request "{title}" was rejected. Reason: {reason}'
        else:
            msg = f'Your documentation request "{title}" was rejected. Contact the administrator for details.'
        notif_title = "Request rejected"
        priority = "high"
    elif st == "completed":
        if not settings_crud.is_notification_enabled(db, "notify_request_approved"):
            return
        msg = (
            f'Documentation for "{title}" has been completed. '
            "Open your request to review the gallery or leave feedback."
        )
        notif_title = "Documentation completed"
        priority = "normal"
    else:
        return
    notify_user(
        db,
        user_id,
        title=notif_title,
        message=msg,
        category="documentation_request",
        priority=priority,
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_task_assigned(db: Session, member_id: int, assignment_id: int, task_title: str, role: str) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_assignment"):
        return
    notify_user(
        db,
        member_id,
        title="New Documentation Assignment",
        message=(
            f'You have been assigned as {role.replace("_", " ").title()} for "{task_title}". '
            "Please accept or decline this assignment."
        ),
        category="task_assignment",
        priority="high",
        action_type="view_task",
        action_ref_id=assignment_id,
    )
    notify_admins(
        db,
        title="Member assigned to event",
        message=f'Member assigned as {role} for "{task_title}".',
        category="task_assignment",
        priority="normal",
        action_type="view_task",
        action_ref_id=assignment_id,
    )


def notify_assignment_accepted(
    db: Session,
    assignment_id: int,
    member_name: str,
    event_title: str,
    role: str,
) -> None:
    notify_admins(
        db,
        title="Assignment accepted",
        message=(
            f'{member_name} accepted the {role.replace("_", " ").title()} assignment '
            f'for "{event_title}".'
        ),
        category="task_assignment",
        priority="normal",
        action_type="view_task",
        action_ref_id=assignment_id,
    )


def notify_assignment_declined(
    db: Session,
    assignment_id: int,
    member_name: str,
    event_title: str,
    role: str,
    reason: str,
) -> None:
    notify_admins(
        db,
        title="Assignment declined",
        message=(
            f'{member_name} declined the {role.replace("_", " ").title()} assignment '
            f'for "{event_title}". Reason: {reason}'
        ),
        category="task_assignment",
        priority="high",
        action_type="view_task",
        action_ref_id=assignment_id,
    )


def notify_assignment_completed(
    db: Session,
    assignment_id: int,
    member_id: int,
    member_name: str,
    event_title: str,
    role: str,
) -> None:
    notify_admins(
        db,
        title="Assignment completed",
        message=(
            f'{member_name} completed the {role.replace("_", " ").title()} assignment '
            f'for "{event_title}".'
        ),
        category="task_assignment",
        priority="normal",
        action_type="view_task",
        action_ref_id=assignment_id,
    )
    notify_user(
        db,
        member_id,
        title="Assignment completed",
        message=f'You completed documentation for "{event_title}".',
        category="task_assignment",
        priority="normal",
        action_type="view_task",
        action_ref_id=assignment_id,
    )


def notify_requestor_documentation_completed(
    db: Session,
    requestor_id: int,
    request_id: int,
    event_title: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_request_approved"):
        return
    notify_user(
        db,
        requestor_id,
        title="Documentation completed",
        message=(
            f'Documentation for "{event_title}" has been completed. '
            "Open your request to review details or leave feedback."
        ),
        category="documentation_request",
        priority="normal",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_event_member_assigned(
    db: Session,
    *,
    event_id: int,
    event_title: str,
    member_id: int,
    event_date: str | None = None,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_assignment"):
        return
    when = f" on {event_date}" if event_date else ""
    notify_user(
        db,
        member_id,
        title="Event assignment",
        message=f'You were assigned to "{event_title}"{when}.',
        category="task_assignment",
        priority="high",
        action_type="view_task",
        action_ref_id=event_id,
    )
    notify_admins(
        db,
        title="Member assigned to event",
        message=f'A member was assigned to "{event_title}"{when}.',
        category="task_assignment",
        priority="normal",
        action_type="view_task",
        action_ref_id=event_id,
    )


def notify_media_uploaded(db: Session, media_id: int, file_name: str, uploader: str) -> None:
    """Reserved for event-documentation uploads that need admin review — not member practice evals."""
    if not settings_crud.is_notification_enabled(db, "notify_system_alerts"):
        return
    notify_admins(
        db,
        title="New media uploaded",
        message=f'{uploader} uploaded "{file_name}" for review.',
        category="media_evaluation",
        priority="normal",
        action_type="view_result",
        action_ref_id=media_id,
    )


def notify_media_evaluated(db: Session, user_id: int, media_id: int, file_name: str, score_pct: int) -> None:
    """Optional score ping — disabled for routine practice evals (see media_pipeline)."""
    if not settings_crud.is_notification_enabled(db, "notify_evaluation_completed"):
        return
    notify_user(
        db,
        user_id,
        title="Media evaluation completed",
        message=f'Your upload "{file_name}" scored {score_pct}%.',
        category="media_evaluation",
        priority="normal",
        action_type="view_result",
        action_ref_id=media_id,
    )


def notify_ai_detection_alert(
    db: Session,
    media_id: int,
    file_name: str,
    uploader: str,
    *,
    member_id: int | None = None,
    detection_label: str = "ai_generated",
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_system_alerts"):
        return
    label = (detection_label or "ai_generated").lower()
    if label == "suspicious":
        admin_msg = f'Suspicious content detected on "{file_name}" by {uploader}. Review recommended.'
        member_msg = f'Your upload "{file_name}" flagged suspicious indicators and needs admin review.'
    else:
        admin_msg = f'AI-generated content detected on "{file_name}" by {uploader}.'
        member_msg = f'Your upload "{file_name}" is under AI review. Please wait for admin verification.'
    notify_admins(
        db,
        title="AI detection alert",
        message=admin_msg,
        category="ai_detection",
        priority="high",
        action_type="review_media",
        action_ref_id=media_id,
    )
    if member_id:
        notify_user(
            db,
            member_id,
            title="Media under AI review",
            message=member_msg,
            category="ai_detection",
            priority="normal",
            action_type="view_result",
            action_ref_id=media_id,
        )


def notify_member_admin_feedback(
    db: Session,
    member_id: int,
    *,
    remarks: str,
) -> None:
    """Alert a documentation member that an admin left competency / performance notes."""
    if not settings_crud.is_notification_enabled(db, "notify_evaluation_completed"):
        return
    preview = (remarks or "").strip()
    if not preview:
        return
    if len(preview) > 180:
        preview = f"{preview[:177]}…"
    notify_user(
        db,
        member_id,
        title="Feedback from administrator",
        message=preview,
        category="media_evaluation",
        priority="normal",
        action_type="view_admin_feedback",
        action_ref_id=member_id,
    )


def notify_feedback_submitted(db: Session, feedback_id: int, event_title: str, rating: int, from_user: str) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_system_alerts"):
        return
    notify_admins(
        db,
        title="New feedback submitted",
        message=f'{from_user} rated "{event_title}" {rating}/5.',
        category="feedback",
        priority="normal",
        action_type="view_feedback",
        action_ref_id=feedback_id,
    )
