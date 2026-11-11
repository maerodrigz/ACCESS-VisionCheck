"""Grandfather snapshot readiness checks before / after v2 activation seal."""

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


def _valid_floor(raw: str | None) -> bool:
    if not raw or not str(raw).strip():
        return False
    return str(raw).strip() in {"Beginner", "Intermediate", "Advanced", "Expert"}


def members_missing_grandfather_snapshot(db: Session) -> list[int]:
    """
    Members that still need a valid grandfather floor for v2 readiness.

    After a sealed activation: only protected cohort members (authoritative table).
    Before seal: all approved members without a valid floor (capture readiness).
    New post-seal approvals are outside the cohort and are not listed.
    """
    from app.services.skill_progression_v2_activation import (
        get_sealed_activation,
        protected_cohort_members_missing_floors,
    )

    seal = get_sealed_activation(db)
    if seal is not None:
        return protected_cohort_members_missing_floors(db, seal)

    missing: list[int] = []
    members = db.scalars(
        select(User)
        .join(Role, User.role_id == Role.id)
        .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
        .order_by(User.id)
    ).all()
    for user in members:
        ranking = db.scalar(
            select(MemberRanking).where(MemberRanking.user_id == user.id)
        )
        if ranking is None or not _valid_floor(ranking.skill_tier_grandfather_floor):
            missing.append(user.id)
    return missing


def grandfather_snapshots_complete(db: Session) -> bool:
    """
    True only when a sealed activation exists and every protected cohort
    member has a valid earned floor. Pre-seal always False for v2 readiness.
    """
    from app.services.skill_progression_v2_activation import (
        get_sealed_activation,
        protected_cohort_members_missing_floors,
    )

    seal = get_sealed_activation(db)
    if seal is None:
        return False
    return len(protected_cohort_members_missing_floors(db, seal)) == 0


def v2_activation_blocked_reason(db: Session) -> str | None:
    """When env requests v2 but seal/cohort requirements fail, explain why."""
    from app.services.skill_progression_policy import configured_skill_progression_policy
    from app.services.skill_progression_v2_activation import (
        get_sealed_activation,
        protected_cohort_members_missing_floors,
    )

    if configured_skill_progression_policy() != POLICY_V2:
        return None

    seal = get_sealed_activation(db)
    if seal is None:
        return (
            "SKILL_PROGRESSION_ACTIVE_POLICY=v2 but no sealed v2 activation exists. "
            "Effective policy remains v1 until cohort capture + "
            "skill_progression_seal_v2_activation.py --apply completes."
        )

    missing = protected_cohort_members_missing_floors(db, seal)
    if not missing:
        return None
    sample = missing[:5]
    suffix = "" if len(missing) <= 5 else f" (+{len(missing) - 5} more)"
    return (
        "SKILL_PROGRESSION_ACTIVE_POLICY=v2 but protected grandfather cohort snapshots "
        f"are incomplete for member user_ids={sample}{suffix}. Effective policy remains v1."
    )
