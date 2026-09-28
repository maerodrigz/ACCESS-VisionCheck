from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.feedback import Feedback


def list_feedbacks(
    db: Session,
    *,
    user_id: int | None = None,
    request_id: int | None = None,
) -> list[Feedback]:
    q = select(Feedback).options(joinedload(Feedback.user), joinedload(Feedback.request))
    if user_id is not None:
        q = q.where(Feedback.user_id == user_id)
    if request_id is not None:
        q = q.where(Feedback.request_id == request_id)
    q = q.order_by(Feedback.created_at.desc())
    return list(db.scalars(q))


def get(db: Session, feedback_id: int) -> Feedback | None:
    return db.get(Feedback, feedback_id)


def create(db: Session, data: dict) -> Feedback:
    row = Feedback(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_admin_review(
    db: Session,
    row: Feedback,
    *,
    admin_response: str | None = None,
    review_status: str | None = None,
) -> Feedback:
    if admin_response is not None:
        row.admin_response = admin_response.strip() or None
    if review_status is not None:
        row.review_status = review_status
    db.commit()
    db.refresh(row)
    return row
