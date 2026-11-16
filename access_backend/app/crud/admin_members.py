"""Admin member list with participation and evaluation aggregates."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud import member_profile as profile_crud
from app.services.member_presence import presence_fields, utc_now
from app.services.supabase_storage import apply_display_profile_images, display_profile_image
from app.models.audit_log import AuditLog
from app.models.login_history import LoginHistory
from app.models.request_assignment import RequestAssignment
from app.models.user import User


def _member_skill_tier_fields(db: Session, user: User) -> dict[str, str | None]:
    from app.services.skill_progression import build_skill_progression_snapshot

    stored = user.skill_level.level_name if user.skill_level else None
    if user.role and user.role.role_name != "Member":
        return {
            "skill_level": stored,
            "skill_effective_tier": stored,
            "skill_tier_stored_legacy": stored,
        }
    snap = build_skill_progression_snapshot(db, user.id)
    effective = snap.effective_tier
    return {
        "skill_level": effective,
        "skill_effective_tier": effective,
        "skill_tier_stored_legacy": stored,
    }


def _presence_payload(user: User, *, now: datetime | None = None) -> dict:
    return presence_fields(
        is_active=bool(user.is_active),
        last_seen_at=getattr(user, "last_seen_at", None),
        last_login_at=getattr(user, "last_login_at", None),
        now=now,
    )


def _quality_skill_fields(db: Session, user: User) -> dict:
    """Quality Skill Classification titles — not XP / skill progression tiers."""
    if user.role and user.role.role_name != "Member":
        return {
            "quality_skill_photo_title": None,
            "quality_skill_video_title": None,
            "quality_skill_photo_average": None,
            "quality_skill_video_average": None,
            "quality_skill_photo_evaluations": None,
            "quality_skill_video_evaluations": None,
        }
    from app.services.quality_skill_classification import admin_classification_summary

    return admin_classification_summary(db, user.id)

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
    now = utc_now()
    rows: list[dict] = []
    for u in users:
        assigned = profile_crud.assignments_total(db, u.id)
        completed = profile_crud.assignments_completed(db, u.id)
        ranking = u.member_ranking
        tier_fields = _member_skill_tier_fields(db, u)
        quality_fields = _quality_skill_fields(db, u)
        presence = _presence_payload(u, now=now)
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
                **tier_fields,
                **quality_fields,
                "assigned_tasks": assigned,
                "completed_tasks": completed,
                "media_eval_score": _avg_media_score(db, u.id),
                "last_active": presence["last_active"],
                "account_status": presence["account_status"],
                "presence": presence["presence"],
                "is_online": presence["is_online"],
                "is_inactive": presence["is_inactive"],
                "last_seen_at": presence["last_seen_at"],
                "last_login_at": presence["last_login_at"],
                "primary_task_role": _primary_task_role(db, u.id),
                "profile_image": u.profile_image,
                "good_evaluations": ranking.total_points if ranking else 0,
                "avg_score": _avg_media_score(db, u.id),
                "created_at": u.created_at,
            }
        )
    apply_display_profile_images(rows)
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
    tier_fields = _member_skill_tier_fields(db, u)
    quality_fields = _quality_skill_fields(db, u)
    presence = _presence_payload(u)
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
        **tier_fields,
        **quality_fields,
        "assigned_tasks": assigned,
        "completed_tasks": completed,
        "media_eval_score": _avg_media_score(db, u.id),
        "last_active": presence["last_active"],
        "account_status": presence["account_status"],
        "presence": presence["presence"],
        "is_online": presence["is_online"],
        "is_inactive": presence["is_inactive"],
        "last_seen_at": presence["last_seen_at"],
        "last_login_at": presence["last_login_at"],
        "primary_task_role": _primary_task_role(db, u.id),
        "profile_image": display_profile_image(u.profile_image),
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
