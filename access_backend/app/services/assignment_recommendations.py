"""Rank eligible documentation team members for admin assignment."""

from __future__ import annotations

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud import member_profile as profile_crud
from app.crud import rankings_admin as rankings_crud
from app.models.assignment_constants import ACTIVE_ASSIGNMENT_STATUSES, DECLINED
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName, UserStatus
from app.models.request_assignment import RequestAssignment
from app.models.role import Role
from app.models.user import User
from app.services.skill_scoring import build_skill_payload


def _role_matches(task_role: str, coverage_role: str) -> bool:
    tr = task_role.strip().lower()
    cr = coverage_role.strip().lower()
    if tr == "photographer":
        return "photo" in cr or cr == "photographer"
    if tr == "videographer":
        return "video" in cr or cr == "videographer"
    return True


def _infer_coverage_role(primary_task_role: str | None) -> str:
    r = (primary_task_role or "").lower()
    if "video" in r:
        return "videographer"
    if "photo" in r:
        return "photographer"
    return "unassigned"


def _active_assignments_count(db: Session, member_id: int) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(RequestAssignment)
            .where(
                RequestAssignment.member_id == member_id,
                RequestAssignment.status.in_(ACTIVE_ASSIGNMENT_STATUSES),
            )
        )
        or 0
    )


def _has_schedule_conflict(db: Session, member_id: int, event_date: date) -> bool:
    return (
        db.scalar(
            select(func.count())
            .select_from(RequestAssignment)
            .join(DocumentationRequest, RequestAssignment.request_id == DocumentationRequest.id)
            .where(
                RequestAssignment.member_id == member_id,
                DocumentationRequest.event_date == event_date,
                RequestAssignment.status.in_(ACTIVE_ASSIGNMENT_STATUSES + ("accepted", "in_progress")),
            )
        )
        or 0
    ) > 0


def _availability_level(db: Session, member_id: int, event_date: date, active_count: int) -> str:
    if _has_schedule_conflict(db, member_id, event_date):
        return "unavailable"
    if active_count >= 3:
        return "unavailable"
    if active_count == 2:
        return "limited"
    if active_count == 1:
        return "limited"
    return "available"


def _member_performance_score(db: Session, user: User) -> tuple[float, str]:
    uploads = profile_crud.uploads_count(db, user.id)
    approved = profile_crud.approved_uploads_count(db, user.id)
    completed = profile_crud.assignments_completed(db, user.id)
    assigned = profile_crud.assignments_total(db, user.id)
    admin_score = profile_crud.admin_evaluation_score(db, user.id)
    human, ai_gen, suspicious = rankings_crud._ai_counts(db, user.id)
    total_checked = human + ai_gen + suspicious
    _, avg_score = profile_crud.evaluations_stats(db, user.id)
    payload = build_skill_payload(
        average_quality_score=avg_score,
        approved_uploads=approved,
        total_uploads=uploads,
        completed_tasks=completed,
        assigned_tasks=assigned,
        admin_evaluation_score=admin_score,
        human_verified_uploads=human,
        total_checked_uploads=total_checked,
    )
    skill_level = payload.get("skill_level") or (user.skill_level.level_name if user.skill_level else "Beginner")
    return float(payload.get("skill_score") or 0), str(skill_level)


def recommend_members_for_request(
    db: Session,
    request: DocumentationRequest,
    *,
    task_role: str,
    exclude_member_ids: list[int] | None = None,
    limit: int = 10,
) -> list[dict]:
    """Return ranked eligible members for a role. Ranking is recommendation only."""
    exclude = set(exclude_member_ids or [])
    event_date = request.event_date

    members = db.scalars(
        select(User)
        .options(joinedload(User.role), joinedload(User.skill_level))
        .join(Role, User.role_id == Role.id)
        .where(
            User.status == UserStatus.APPROVED,
            User.is_active.is_(True),
            Role.role_name == RoleName.MEMBER,
        )
    ).all()

    # Primary roles already filled with active assignment for this request+role.
    active_role_member_ids = set(
        db.scalars(
            select(RequestAssignment.member_id).where(
                RequestAssignment.request_id == request.id,
                RequestAssignment.task_role == task_role.strip().lower(),
                RequestAssignment.status.in_(ACTIVE_ASSIGNMENT_STATUSES),
            )
        ).all()
    )

    rows: list[dict] = []
    for user in members:
        if user.id in exclude:
            continue
        if user.id in active_role_member_ids:
            continue

        last_role = db.scalar(
            select(RequestAssignment.task_role)
            .where(RequestAssignment.member_id == user.id)
            .order_by(RequestAssignment.id.desc())
            .limit(1)
        )
        primary_role = _infer_coverage_role(last_role)
        if primary_role != "unassigned" and not _role_matches(task_role, primary_role):
            continue

        active_count = _active_assignments_count(db, user.id)
        availability = _availability_level(db, user.id, event_date, active_count)
        if availability == "unavailable":
            continue

        score, skill_level = _member_performance_score(db, user)
        rows.append(
            {
                "member_id": user.id,
                "name": user.fullname or user.email,
                "task_role": task_role.strip().lower(),
                "performance_score": round(score, 1),
                "skill_level": skill_level,
                "availability": availability,
                "current_assignments": active_count,
                "recommended": False,
            }
        )

    rows.sort(
        key=lambda r: (
            0 if r["availability"] == "available" else 1,
            -r["performance_score"],
            r["current_assignments"],
        )
    )
    if rows:
        rows[0]["recommended"] = True
    return rows[:limit]
