"""Dashboard and analytics aggregates from PostgreSQL."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.ai_detection_result import AiDetectionResult
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName, UserStatus
from app.models.event_calendar import EventCalendar
from app.models.feedback import Feedback
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.request_assignment import RequestAssignment
from app.models.role import Role
from app.models.analytics_report import AnalyticsReport
from app.models.user import User


def list_analytics_reports(db: Session) -> list[dict]:
    """Rows from analytics_reports table for the admin analytics dashboard."""
    rows = db.scalars(
        select(AnalyticsReport).order_by(AnalyticsReport.generated_at.desc())
    ).all()
    result: list[dict] = []
    for r in rows:
        generated = r.generated_at.date().isoformat() if r.generated_at else ""
        result.append(
            {
                "id": r.id,
                "title": f"System snapshot — {generated}",
                "category": "participation",
                "status": "Published",
                "exported": True,
                "generated_at": generated,
                "total_requests": r.total_requests,
                "total_media": r.total_media,
                "total_members": r.total_members,
            }
        )
    return result


def _count_requests_by_status(db: Session, status: str) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(DocumentationRequest)
            .where(DocumentationRequest.status.ilike(status))
        )
        or 0
    )


def _count_assignments_by_status(db: Session, status: str) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(RequestAssignment)
            .where(RequestAssignment.status.ilike(status))
        )
        or 0
    )


def _count_assignments_in_statuses(db: Session, statuses: tuple[str, ...]) -> int:
    if not statuses:
        return 0
    return (
        db.scalar(
            select(func.count())
            .select_from(RequestAssignment)
            .where(RequestAssignment.status.in_(statuses))
        )
        or 0
    )


ACCEPTED_ASSIGNMENT_STATUSES = ("accepted", "in_progress", "completed", "done")
PENDING_ASSIGNMENT_STATUSES = ("pending_acceptance", "assigned")
DECLINED_ASSIGNMENT_STATUSES = ("declined",)


def _count_new_approved_members(db: Session, start: datetime, end: datetime) -> int:
    member_since = func.coalesce(User.approved_at, User.created_at)
    return (
        db.scalar(
            select(func.count())
            .select_from(User)
            .join(Role)
            .where(
                Role.role_name == RoleName.MEMBER,
                User.status == UserStatus.APPROVED,
                member_since >= start,
                member_since < end,
            )
        )
        or 0
    )


def dashboard_stats(db: Session) -> dict:
    """Real counts for admin dashboard summary cards (PostgreSQL)."""
    total_requests = db.scalar(select(func.count()).select_from(DocumentationRequest)) or 0
    pending_requests = _count_requests_by_status(db, "pending")
    approved_requests = _count_requests_by_status(db, "approved")
    rejected_requests = _count_requests_by_status(db, "rejected")
    completed_requests = _count_requests_by_status(db, "completed")

    total_members = (
        db.scalar(
            select(func.count())
            .select_from(User)
            .join(Role)
            .where(Role.role_name == RoleName.MEMBER)
        )
        or 0
    )
    pending_members = db.scalar(
        select(func.count()).select_from(User).where(User.status == UserStatus.PENDING)
    ) or 0
    active_members = (
        db.scalar(
            select(func.count())
            .select_from(User)
            .join(Role)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
        )
        or 0
    )

    total_events = db.scalar(select(func.count()).select_from(EventCalendar)) or 0
    task_assignments = db.scalar(select(func.count()).select_from(RequestAssignment)) or 0
    pending_assignments = _count_assignments_in_statuses(db, PENDING_ASSIGNMENT_STATUSES)
    accepted_assignments = _count_assignments_in_statuses(db, ACCEPTED_ASSIGNMENT_STATUSES)
    declined_assignments = _count_assignments_in_statuses(db, DECLINED_ASSIGNMENT_STATUSES)
    # Legacy field name — counts member-confirmed assignments (accepted workflow).
    completed_tasks = accepted_assignments

    now = datetime.now(timezone.utc)
    members_30d_start = now - timedelta(days=30)
    members_60d_start = now - timedelta(days=60)
    new_members_30d = _count_new_approved_members(db, members_30d_start, now)
    new_members_prev_30d = _count_new_approved_members(db, members_60d_start, members_30d_start)

    media_uploads = db.scalar(select(func.count()).select_from(MediaFile)) or 0
    total_evaluations = db.scalar(select(func.count()).select_from(MediaEvaluation)) or 0

    ai_flagged = (
        db.scalar(
            select(func.count())
            .select_from(AiDetectionResult)
            .where(AiDetectionResult.detection_result.ilike("ai_generated"))
        )
        or 0
    )
    ai_total = db.scalar(select(func.count()).select_from(AiDetectionResult)) or 0

    feedback_count = db.scalar(select(func.count()).select_from(Feedback)) or 0
    avg_rating = db.scalar(select(func.avg(Feedback.rating)).select_from(Feedback))

    return {
        "total_requests": total_requests,
        "pending_requests": pending_requests,
        "approved_requests": approved_requests,
        "rejected_requests": rejected_requests,
        "completed_requests": completed_requests,
        "total_members": total_members,
        "pending_members": pending_members,
        "active_members": active_members,
        "total_events": total_events,
        "task_assignments": task_assignments,
        "pending_assignments": pending_assignments,
        "accepted_assignments": accepted_assignments,
        "declined_assignments": declined_assignments,
        "completed_tasks": completed_tasks,
        "new_members_30d": new_members_30d,
        "new_members_prev_30d": new_members_prev_30d,
        "media_uploads": media_uploads,
        "total_evaluations": total_evaluations,
        "ai_flagged": ai_flagged,
        "ai_detection_total": ai_total,
        "feedback_count": feedback_count,
        "avg_feedback_rating": round(float(avg_rating), 2) if avg_rating is not None else None,
    }
