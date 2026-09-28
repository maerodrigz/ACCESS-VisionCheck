"""Member notification preference CRUD."""

from sqlalchemy.orm import Session

from app.models.member_notification_preference import MemberNotificationPreference

# Maps notification.category values to preference fields.
_CATEGORY_TO_FIELD: dict[str, str] = {
    "documentation_request": "event_calendar",
    "media_evaluation": "evaluation_feedback",
    "ai_detection": "evaluation_feedback",
    "task_assignment": "event_calendar",
    "system_alert": "system_announcements",
    "announcement": "system_announcements",
}


def get_or_create(db: Session, user_id: int) -> MemberNotificationPreference:
    row = db.get(MemberNotificationPreference, user_id)
    if row is None:
        row = MemberNotificationPreference(user_id=user_id)
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


def to_dict(row: MemberNotificationPreference) -> dict[str, bool]:
    return {
        "evaluation_feedback": row.evaluation_feedback,
        "event_calendar": row.event_calendar,
        "system_announcements": row.system_announcements,
    }


def allows_category(db: Session, user_id: int, category: str) -> bool:
    field = _CATEGORY_TO_FIELD.get(category)
    if field is None:
        return True
    prefs = get_or_create(db, user_id)
    return bool(getattr(prefs, field))


def update(
    db: Session,
    user_id: int,
    *,
    evaluation_feedback: bool | None = None,
    event_calendar: bool | None = None,
    system_announcements: bool | None = None,
) -> MemberNotificationPreference:
    row = get_or_create(db, user_id)
    if evaluation_feedback is not None:
        row.evaluation_feedback = evaluation_feedback
    if event_calendar is not None:
        row.event_calendar = event_calendar
    if system_announcements is not None:
        row.system_announcements = system_announcements
    db.commit()
    db.refresh(row)
    return row
