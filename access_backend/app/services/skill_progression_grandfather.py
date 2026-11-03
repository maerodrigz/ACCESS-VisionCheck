"""Grandfather snapshot readiness checks before v2 activation."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import RoleName, UserStatus
from app.models.member_ranking import MemberRanking
from app.models.role import Role
from app.models.user import User
from app.services.skill_progression_policy import POLICY_V2


def approved_member_user_ids(db: Session) -> list[int]:
    rows = db.scalars(
        select(User.id)
        .join(Role, User.role_id == Role.id)
        .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
        .order_by(User.id)
    ).all()
    return list(rows)


def members_missing_grandfather_snapshot(db: Session) -> list[int]:
    """Approved members without a captured v1 earned-tier grandfather floor."""
    missing: list[int] = []
    members = db.scalars(
        select(User)
        .options()
        .join(Role, User.role_id == Role.id)
        .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
        .order_by(User.id)
    ).all()
    for user in members:
        ranking = db.scalar(
            select(MemberRanking).where(MemberRanking.user_id == user.id)
        )
        if ranking is None:
            missing.append(user.id)
            continue
        floor = ranking.skill_tier_grandfather_floor
        if not floor or not str(floor).strip():
            missing.append(user.id)
    return missing


def grandfather_snapshots_complete(db: Session) -> bool:
    return len(members_missing_grandfather_snapshot(db)) == 0


def v2_activation_blocked_reason(db: Session) -> str | None:
    """When env requests v2 but snapshots are incomplete, return a human-readable reason."""
    from app.services.skill_progression_policy import configured_skill_progression_policy

    if configured_skill_progression_policy() != POLICY_V2:
        return None
    missing = members_missing_grandfather_snapshot(db)
    if not missing:
        return None
    sample = missing[:5]
    suffix = "" if len(missing) <= 5 else f" (+{len(missing) - 5} more)"
    return (
        "SKILL_PROGRESSION_ACTIVE_POLICY=v2 but grandfather snapshots are incomplete "
        f"for member user_ids={sample}{suffix}. Effective policy remains v1 until "
        "skill_progression_capture_grandfather.py --apply completes."
    )
