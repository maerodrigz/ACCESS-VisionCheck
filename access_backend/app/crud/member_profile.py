"""Profile and participation aggregates for members."""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.request_assignment import RequestAssignment
from app.models.user import User


def uploads_count(db: Session, user_id: int) -> int:
    return db.scalar(
        select(func.count()).select_from(MediaFile).where(MediaFile.uploaded_by == user_id)
    ) or 0


def assignments_completed(db: Session, user_id: int) -> int:
    """Assignments the member confirmed (accepted). Includes legacy completed rows."""
    return db.scalar(
        select(func.count())
        .select_from(RequestAssignment)
        .where(
            RequestAssignment.member_id == user_id,
            RequestAssignment.status.in_(["accepted", "in_progress", "completed", "done"]),
        )
    ) or 0


def assignments_total(db: Session, user_id: int) -> int:
    return db.scalar(
        select(func.count())
        .select_from(RequestAssignment)
        .where(RequestAssignment.member_id == user_id)
    ) or 0


def approved_uploads_count(db: Session, user_id: int, *, min_score: float = 0.60) -> int:
    """Uploads with at least one evaluation meeting minimum quality."""
    return (
        db.scalar(
            select(func.count(func.distinct(MediaFile.id)))
            .join(MediaEvaluation, MediaEvaluation.media_id == MediaFile.id)
            .where(
                MediaFile.uploaded_by == user_id,
                MediaEvaluation.overall_score >= min_score,
            )
        )
        or 0
    )


def admin_evaluation_score(db: Session, user_id: int) -> float:
    """Average quality (0–100) of media that received admin remarks."""
    rows = db.scalars(
        select(MediaEvaluation.overall_score)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .where(
            MediaFile.uploaded_by == user_id,
            MediaEvaluation.admin_remarks.isnot(None),
            MediaEvaluation.admin_remarks != "",
        )
    ).all()
    if not rows:
        return 0.0
    avg = sum(rows) / len(rows)
    return round(avg * 100.0 if avg <= 1.0 else min(100.0, avg), 2)


def evaluations_stats(db: Session, user_id: int) -> tuple[int, float]:
    rows = db.scalars(
        select(MediaEvaluation.overall_score)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .where(MediaFile.uploaded_by == user_id)
    ).all()
    if not rows:
        return 0, 0.0
    return len(rows), sum(rows) / len(rows)


def update_profile(
    db: Session,
    user: User,
    *,
    name: str | None = None,
    email: str | None = None,
    contact_number: str | None = None,
    profile_image: str | None = None,
    new_password: str | None = None,
) -> User:
    if name is not None:
        user.fullname = name.strip()
    if email is not None:
        user.email = email.strip().lower()
    if contact_number is not None:
        user.contact_number = contact_number.strip()
    if profile_image is not None:
        user.profile_image = profile_image
    if new_password:
        user.password = hash_password(new_password)
    db.commit()
    db.refresh(user)
    return user
