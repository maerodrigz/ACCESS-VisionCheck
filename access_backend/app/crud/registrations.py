"""Admin registration approval lists (members and organizations)."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.enums import RoleName
from app.models.role import Role
from app.models.user import User


def _status_filter(status: str | None) -> str | None:
    if not status or status.strip().lower() in ("all", ""):
        return None
    return status.strip().lower()


def list_member_registrations(db: Session, *, status: str | None = None) -> list[dict]:
    role = db.scalar(select(Role).where(Role.role_name == RoleName.MEMBER))
    if not role:
        return []
    status_val = _status_filter(status) or "pending"
    q = (
        select(User)
        .options(joinedload(User.skill_level), joinedload(User.role))
        .where(User.role_id == role.id)
        .order_by(User.created_at.desc())
    )
    if status_val != "all":
        q = q.where(User.status == status_val)
    users = list(db.scalars(q))
    return [_member_row(u) for u in users]


def list_organization_registrations(db: Session, *, status: str | None = None) -> list[dict]:
    role = db.scalar(select(Role).where(Role.role_name == RoleName.ORGANIZATION))
    if not role:
        return []
    status_val = _status_filter(status) or "pending"
    q = (
        select(User)
        .options(joinedload(User.role))
        .where(User.role_id == role.id)
        .order_by(User.created_at.desc())
    )
    if status_val != "all":
        q = q.where(User.status == status_val)
    users = list(db.scalars(q))
    return [_organization_row(u) for u in users]


def _member_row(u: User) -> dict:
    return {
        "user_id": u.id,
        "full_name": u.fullname,
        "student_id": u.student_id,
        "email": u.email,
        "contact_number": u.contact_number,
        "skill_level": u.skill_level.level_name if u.skill_level else None,
        "status": u.status,
        "rejection_reason": u.rejection_reason,
        "date_registered": u.created_at,
    }


def _organization_row(u: User) -> dict:
    return {
        "user_id": u.id,
        "organization_name": u.fullname,
        "organization_email": u.email,
        "requestor_type": u.student_id,
        "adviser_name": u.adviser_name,
        "contact_number": u.contact_number,
        "status": u.status,
        "rejection_reason": u.rejection_reason,
        "date_registered": u.created_at,
    }
