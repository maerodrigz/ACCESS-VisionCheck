from sqlalchemy import and_, delete, not_, or_, select, update
from sqlalchemy.orm import Session, joinedload

from app.crud import member_notification_preference as member_pref_crud
from app.models.ai_detection_result import AiDetectionResult
from app.models.enums import RoleName, UserStatus
from app.models.notification import Notification
from app.models.role import Role
from app.models.user import User


def list_for_user(db: Session, user_id: int, *, limit: int = 100) -> list[Notification]:
    return list(
        db.scalars(
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
    )


def get(db: Session, notification_id: int, user_id: int) -> Notification | None:
    return db.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
    )


def get_by_id(db: Session, notification_id: int) -> Notification | None:
    return db.get(Notification, notification_id)


def mark_read(db: Session, notification: Notification) -> Notification:
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


def mark_all_read(db: Session, user_id: int) -> int:
    result = db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    db.commit()
    return result.rowcount


def mark_all_read_all(db: Session) -> int:
    result = db.execute(
        update(Notification).where(Notification.is_read.is_(False)).values(is_read=True)
    )
    db.commit()
    return result.rowcount


def _admin_user_ids_subquery():
    return select(User.id).join(Role, User.role_id == Role.id).where(
        User.status == UserStatus.APPROVED,
        Role.role_name == RoleName.ADMIN,
    )


def _admin_inbox_visibility_clause():
    """Admin-facing alerts: requestor workflow, integrity review, event doc uploads, assignment exceptions."""
    member_only_actions = ("milestone", "view_admin_feedback", "view_result")
    return and_(
        or_(Notification.action_type.is_(None), Notification.action_type.notin_(member_only_actions)),
        or_(
            Notification.category.in_(("documentation_request", "feedback", "ai_detection")),
            and_(
                Notification.category == "media_evaluation",
                Notification.title == "New media uploaded",
                Notification.action_type.in_(("review_media", "view_result")),
            ),
            and_(
                Notification.category == "task_assignment",
                Notification.title.in_(("Assignment declined", "Assignment completed")),
            ),
        ),
    )


def purge_admin_inbox_noise(db: Session) -> int:
    """Remove admin rows that are member milestones, assignment echoes, or legacy practice-eval spam."""
    result = db.execute(
        delete(Notification).where(
            Notification.user_id.in_(_admin_user_ids_subquery()),
            not_(_admin_inbox_visibility_clause()),
        )
    )
    db.commit()
    return result.rowcount or 0


def mark_all_read_admin_inbox(db: Session) -> int:
    result = db.execute(
        update(Notification)
        .where(
            Notification.is_read.is_(False),
            Notification.user_id.in_(_admin_user_ids_subquery()),
            _admin_inbox_visibility_clause(),
        )
        .values(is_read=True)
    )
    db.commit()
    return result.rowcount


def delete_read_for_user(db: Session, user_id: int) -> int:
    result = db.execute(
        delete(Notification).where(
            Notification.user_id == user_id,
            Notification.is_read.is_(True),
        )
    )
    db.commit()
    return result.rowcount


def delete_all_read(db: Session) -> int:
    result = db.execute(delete(Notification).where(Notification.is_read.is_(True)))
    db.commit()
    return result.rowcount


def delete_read_admin_inbox(db: Session) -> int:
    result = db.execute(
        delete(Notification).where(
            Notification.is_read.is_(True),
            Notification.user_id.in_(_admin_user_ids_subquery()),
            _admin_inbox_visibility_clause(),
        )
    )
    db.commit()
    return result.rowcount


def delete_practice_eval_spam(db: Session, user_id: int) -> int:
    """Remove legacy admin alerts from the old every-eval notification behavior."""
    flagged_media_ids = select(AiDetectionResult.media_id).where(
        AiDetectionResult.detection_result.in_(("suspicious", "ai_generated"))
    )

    removed = 0
    for clause in (
        delete(Notification).where(
            Notification.user_id == user_id,
            Notification.category == "media_evaluation",
            Notification.title == "New media uploaded",
        ),
        delete(Notification).where(
            Notification.user_id == user_id,
            Notification.category == "media_evaluation",
            Notification.title == "Media evaluation completed",
        ),
        delete(Notification).where(
            Notification.user_id == user_id,
            Notification.category == "ai_detection",
            Notification.title == "AI detection alert",
            Notification.action_ref_id.notin_(flagged_media_ids),
        ),
    ):
        result = db.execute(clause)
        removed += result.rowcount or 0
    db.commit()
    return removed


def create(
    db: Session,
    user_id: int,
    title: str,
    message: str,
    *,
    category: str = "system_alert",
    priority: str = "normal",
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> Notification:
    row = Notification(
        user_id=user_id,
        title=title,
        message=message,
        category=category,
        priority=priority,
        action_type=action_type,
        action_ref_id=action_ref_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    from app.services.fcm_push import send_to_user_async

    send_to_user_async(
        user_id,
        title,
        message,
        category=category,
        notification_id=row.id,
        action_type=action_type,
        action_ref_id=action_ref_id,
    )
    return row


def list_all(db: Session, limit: int = 100) -> list[Notification]:
    return list(
        db.scalars(
            select(Notification)
            .options(joinedload(Notification.user))
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
    )


def list_for_admin_inbox(db: Session, limit: int = 200) -> list[Notification]:
    """Notifications delivered to Admin accounts only (not member/org inboxes)."""
    purge_admin_inbox_noise(db)
    return list(
        db.scalars(
            select(Notification)
            .options(joinedload(Notification.user))
            .where(
                Notification.user_id.in_(_admin_user_ids_subquery()),
                _admin_inbox_visibility_clause(),
            )
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
    )


def broadcast(
    db: Session,
    user_ids: list[int],
    title: str,
    message: str,
    *,
    category: str = "system_alert",
    priority: str = "normal",
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> int:
    sent = 0
    push_targets: list[int] = []
    for uid in user_ids:
        if not member_pref_crud.allows_category(db, uid, category):
            continue
        db.add(
            Notification(
                user_id=uid,
                title=title,
                message=message,
                category=category,
                priority=priority,
                action_type=action_type,
                action_ref_id=action_ref_id,
            )
        )
        push_targets.append(uid)
        sent += 1
    db.commit()
    if push_targets:
        from app.services.fcm_push import send_to_user_async

        for uid in push_targets:
            send_to_user_async(
                uid,
                title,
                message,
                category=category,
                action_type=action_type,
                action_ref_id=action_ref_id,
            )
    return sent


def notification_to_dict(n: Notification) -> dict:
    return {
        "id": n.id,
        "user_id": n.user_id,
        "title": n.title,
        "message": n.message,
        "is_read": n.is_read,
        "category": n.category,
        "priority": n.priority,
        "action_type": n.action_type,
        "action_ref_id": n.action_ref_id,
        "created_at": n.created_at.isoformat() if n.created_at else None,
    }
