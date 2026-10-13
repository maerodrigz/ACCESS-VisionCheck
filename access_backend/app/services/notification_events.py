"""Create notifications when platform events occur."""

from __future__ import annotations

from datetime import datetime, timezone

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
        if not settings_crud.is_notification_enabled(db, "notify_request_completed"):
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


def notify_assignment_accepted(
    db: Session,
    assignment_id: int,
    member_name: str,
    event_title: str,
    role: str,
    *,
    requestor_id: int | None = None,
    request_id: int | None = None,
) -> None:
    """No admin inbox ping; requestor is notified that coverage was confirmed."""
    if requestor_id is not None and request_id is not None:
        notify_requestor_coverage_accepted(
            db,
            requestor_id,
            request_id,
            event_title,
            member_name,
            role,
        )


def notify_assignment_declined(
    db: Session,
    assignment_id: int,
    member_name: str,
    event_title: str,
    role: str,
    reason: str,
    *,
    requestor_id: int | None = None,
    request_id: int | None = None,
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
    if requestor_id is not None and request_id is not None:
        notify_requestor_coverage_declined(
            db,
            requestor_id,
            request_id,
            event_title,
            member_name,
            role,
            reason,
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


def notify_requestor_request_submitted(
    db: Session,
    requestor_id: int,
    request_id: int,
    title: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_request"):
        return
    notify_user(
        db,
        requestor_id,
        title="Request submitted",
        message=(
            f'Your documentation request "{title}" was received and is pending admin review.'
        ),
        category="documentation_request",
        priority="normal",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_requestor_reschedule_pending(
    db: Session,
    requestor_id: int,
    request_id: int,
    title: str,
    event_date: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_request"):
        return
    notify_user(
        db,
        requestor_id,
        title="Schedule updated",
        message=(
            f'"{title}" was moved to {event_date} and is pending admin review again.'
        ),
        category="documentation_request",
        priority="high",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_requestor_coverage_assigned(
    db: Session,
    requestor_id: int,
    request_id: int,
    event_title: str,
    member_name: str,
    role: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_assignment"):
        return
    role_label = role.replace("_", " ").title()
    notify_user(
        db,
        requestor_id,
        title="Documentation team assigned",
        message=(
            f'{member_name} was assigned as {role_label} for "{event_title}". '
            "They must accept before coverage is confirmed."
        ),
        category="documentation_request",
        priority="normal",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_requestor_coverage_accepted(
    db: Session,
    requestor_id: int,
    request_id: int,
    event_title: str,
    member_name: str,
    role: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_assignment"):
        return
    role_label = role.replace("_", " ").title()
    notify_user(
        db,
        requestor_id,
        title="Coverage confirmed",
        message=f'{member_name} accepted the {role_label} role for "{event_title}".',
        category="documentation_request",
        priority="normal",
        action_type="view_request",
        action_ref_id=request_id,
    )


def notify_requestor_coverage_declined(
    db: Session,
    requestor_id: int,
    request_id: int,
    event_title: str,
    member_name: str,
    role: str,
    reason: str,
) -> None:
    if not settings_crud.is_notification_enabled(db, "notify_new_documentation_assignment"):
        return
    role_label = role.replace("_", " ").title()
    preview = (reason or "").strip() or "No reason given"
    notify_user(
        db,
        requestor_id,
        title="Coverage declined",
        message=(
            f'{member_name} declined the {role_label} role for "{event_title}". '
            f"Reason: {preview}"
        ),
        category="documentation_request",
        priority="high",
        action_type="view_request",
        action_ref_id=request_id,
    )


GALLERY_BATCH_DEBOUNCE_MINUTES = 30
GALLERY_BATCH_THRESHOLD = 5


def gallery_batch_should_send(pending: int, minutes_since_last: float | None) -> bool:
    """Send a batched gallery ping when enough uploads queued or debounce window elapsed."""
    if pending <= 0:
        return False
    if pending >= GALLERY_BATCH_THRESHOLD:
        return True
    if minutes_since_last is not None and minutes_since_last >= GALLERY_BATCH_DEBOUNCE_MINUTES:
        return True
    return False


def notify_requestor_event_gallery_upload(
    db: Session,
    *,
    request_id: int,
) -> None:
    """Notify requestor when event gallery media is published (typically admin upload), not every file."""
    if not settings_crud.is_notification_enabled(db, "notify_request_gallery_uploads"):
        return

    from app.models.documentation_request import DocumentationRequest

    row = db.scalar(
        select(DocumentationRequest)
        .where(DocumentationRequest.id == request_id)
        .with_for_update()
    )
    if row is None:
        return

    status = (row.status or "").strip().lower()
    if status in ("completed", "rejected", "pending"):
        db.commit()
        return
    if status != "approved":
        db.commit()
        return

    event_title = row.title
    requestor_id = row.requestor_id
    now = datetime.now(timezone.utc)

    if not row.gallery_first_upload_notified:
        row.gallery_first_upload_notified = True
        row.gallery_upload_notify_pending = 0
        row.gallery_upload_last_notify_at = now
        db.commit()
        notify_user(
            db,
            requestor_id,
            title="Event gallery available",
            message=(
                f'Photos for "{event_title}" were added to your event gallery. '
                "Open gallery to view them."
            ),
            category="documentation_request",
            priority="normal",
            action_type="view_gallery",
            action_ref_id=request_id,
        )
        return

    row.gallery_upload_notify_pending = int(row.gallery_upload_notify_pending or 0) + 1
    last = row.gallery_upload_last_notify_at
    minutes_since: float | None = None
    if last is not None:
        minutes_since = (now - last).total_seconds() / 60.0

    pending = row.gallery_upload_notify_pending
    if not gallery_batch_should_send(pending, minutes_since):
        db.commit()
        return

    count_label = "photo" if pending == 1 else "photos"
    row.gallery_upload_notify_pending = 0
    row.gallery_upload_last_notify_at = now
    db.commit()
    notify_user(
        db,
        requestor_id,
        title="New gallery photos",
        message=f'{pending} more {count_label} were added to "{event_title}".',
        category="documentation_request",
        priority="normal",
        action_type="view_gallery",
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
        action_type="review_media",
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
    """Alert a member about rankings competency / performance remarks (not a media eval row)."""
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
        # Member id for audit; mobile opens rankings/profile feedback, not MED-* eval report.
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
