"""Admin member list with participation and evaluation aggregates."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud import member_profile as profile_crud
from app.models.audit_log import AuditLog
from app.models.login_history import LoginHistory
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.request_assignment import RequestAssignment
from app.models.user import User


def _last_active(db: Session, user_id: int, created_at: datetime | None) -> datetime | None:
    candidates: list[datetime] = []
    if created_at:
        candidates.append(created_at)

    login_at = db.scalar(
        select(func.max(LoginHistory.login_time)).where(LoginHistory.user_id == user_id)
    )
    if login_at:
        candidates.append(login_at)

    media_at = db.scalar(
        select(func.max(MediaFile.uploaded_at)).where(MediaFile.uploaded_by == user_id)
    )
    if media_at:
        candidates.append(media_at)

    eval_at = db.scalar(
        select(func.max(MediaEvaluation.evaluated_at))
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .where(MediaFile.uploaded_by == user_id)
    )
    if eval_at:
        candidates.append(eval_at)

    if not candidates:
        return None
    return max(candidates)


def _primary_task_role(db: Session, user_id: int) -> str | None:
    row = db.execute(
        select(RequestAssignment.task_role, func.count())
        .where(RequestAssignment.member_id == user_id)
        .group_by(RequestAssignment.task_role)
        .order_by(func.count().desc())
        .limit(1)
    ).first()
    return row[0] if row else None


def _avg_media_score(db: Session, user_id: int) -> float:
    count, avg = profile_crud.evaluations_stats(db, user_id)
    if count == 0 or avg <= 0:
        return 0.0
    pct = avg * 100.0 if avg <= 1.0 else min(100.0, avg)
    return round(pct, 1)


def list_admin_members(db: Session) -> list[dict]:
    users = list(
        db.scalars(
            select(User)
            .options(
                joinedload(User.role),
                joinedload(User.skill_level),
                joinedload(User.member_ranking),
            )
            .order_by(User.created_at.desc())
        )
    )
    remover_ids = {u.removed_by for u in users if u.removed_by}
    remover_names: dict[int, str] = {}
    if remover_ids:
        for row in db.scalars(select(User).where(User.id.in_(remover_ids))):
            remover_names[row.id] = row.fullname
    rows: list[dict] = []
    for u in users:
        assigned = profile_crud.assignments_total(db, u.id)
        completed = profile_crud.assignments_completed(db, u.id)
        ranking = u.member_ranking
        rows.append(
            {
                "user_id": u.id,
                "name": u.fullname,
                "email": u.email,
                "role": u.role.role_name if u.role else "Member",
                "status": u.status,
                "is_active": u.is_active,
                "removed_at": u.removed_at,
                "removed_by": u.removed_by,
                "removed_by_name": remover_names.get(u.removed_by) if u.removed_by else None,
                "student_id": u.student_id,
                "contact_number": u.contact_number,
                "adviser_name": u.adviser_name,
                "rejection_reason": u.rejection_reason,
                "approved_at": u.approved_at,
                "skill_level": u.skill_level.level_name if u.skill_level else None,
                "assigned_tasks": assigned,
                "completed_tasks": completed,
                "media_eval_score": _avg_media_score(db, u.id),
                "last_active": _last_active(db, u.id, u.created_at),
                "primary_task_role": _primary_task_role(db, u.id),
                "profile_image": u.profile_image,
                "good_evaluations": ranking.total_points if ranking else 0,
                "avg_score": _avg_media_score(db, u.id),
                "created_at": u.created_at,
            }
        )
    return rows


def get_admin_member(db: Session, user_id: int) -> dict | None:
    u = db.scalar(
        select(User)
        .options(
            joinedload(User.role),
            joinedload(User.skill_level),
            joinedload(User.member_ranking),
        )
        .where(User.id == user_id)
    )
    if not u:
        return None
    remover_name = None
    if u.removed_by:
        remover = db.get(User, u.removed_by)
        remover_name = remover.fullname if remover else None
    assigned = profile_crud.assignments_total(db, u.id)
    completed = profile_crud.assignments_completed(db, u.id)
    ranking = u.member_ranking
    return {
        "user_id": u.id,
        "name": u.fullname,
        "email": u.email,
        "role": u.role.role_name if u.role else "Member",
        "status": u.status,
        "is_active": u.is_active,
        "removed_at": u.removed_at,
        "removed_by": u.removed_by,
        "removed_by_name": remover_name,
        "student_id": u.student_id,
        "contact_number": u.contact_number,
        "adviser_name": u.adviser_name,
        "rejection_reason": u.rejection_reason,
        "approved_at": u.approved_at,
        "skill_level": u.skill_level.level_name if u.skill_level else None,
        "assigned_tasks": assigned,
        "completed_tasks": completed,
        "media_eval_score": _avg_media_score(db, u.id),
        "last_active": _last_active(db, u.id, u.created_at),
        "primary_task_role": _primary_task_role(db, u.id),
        "profile_image": u.profile_image,
        "good_evaluations": ranking.total_points if ranking else 0,
        "avg_score": _avg_media_score(db, u.id),
        "created_at": u.created_at,
    }


def list_user_recent_activity(db: Session, user_id: int, limit: int = 10) -> list[dict]:
    """Login history and audit entries for a user, merged newest first."""
    logins = list(
        db.scalars(
            select(LoginHistory)
            .where(LoginHistory.user_id == user_id)
            .order_by(LoginHistory.login_time.desc())
            .limit(limit)
        )
    )
    audits = list(
        db.scalars(
            select(AuditLog)
            .where(AuditLog.user_id == user_id)
            .order_by(AuditLog.created_at.desc())
            .limit(limit)
        )
    )
    items: list[dict] = []
    for row in logins:
        detail_parts = [p for p in (row.ip_address, row.device_info) if p]
        items.append(
            {
                "kind": "login",
                "label": "Signed in",
                "detail": " · ".join(detail_parts) if detail_parts else None,
                "occurred_at": row.login_time,
            }
        )
    for row in audits:
        items.append(
            {
                "kind": "audit",
                "label": row.action.replace("_", " ").title(),
                "detail": row.description,
                "occurred_at": row.created_at,
            }
        )
    items.sort(
        key=lambda x: x["occurred_at"].timestamp() if x["occurred_at"] is not None else 0,
        reverse=True,
    )
    return items[:limit]
