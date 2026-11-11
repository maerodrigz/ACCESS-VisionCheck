from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.security import hash_password, password_hash_is_legacy, verify_password
from app.models.enums import RoleName, UserStatus
from app.models.role import Role
from app.models.skill_level import SkillLevel
from app.models.user import User


def get_by_email(db: Session, email: str) -> User | None:
    normalized = email.strip().lower()
    if not normalized:
        return None
    return db.scalar(
        select(User)
        .options(joinedload(User.role), joinedload(User.skill_level))
        .where(func.lower(User.email) == normalized)
    )


def get_by_verified_phone(db: Session, phone_e164: str) -> User | None:
    """Active user with this normalized contact number and phone_verified_at set."""
    phone = (phone_e164 or "").strip()
    if not phone:
        return None
    return db.scalar(
        select(User)
        .options(joinedload(User.role), joinedload(User.skill_level))
        .where(
            User.contact_number == phone,
            User.phone_verified_at.is_not(None),
            User.is_active.is_(True),
        )
    )


def find_verified_phone_conflict(db: Session, phone_e164: str, *, exclude_user_id: int | None = None) -> User | None:
    phone = (phone_e164 or "").strip()
    if not phone:
        return None
    stmt = (
        select(User)
        .options(joinedload(User.role), joinedload(User.skill_level))
        .where(
            User.contact_number == phone,
            User.phone_verified_at.is_not(None),
            User.is_active.is_(True),
        )
    )
    if exclude_user_id is not None:
        stmt = stmt.where(User.id != exclude_user_id)
    return db.scalar(stmt)


def mark_phone_verified(db: Session, user: User, phone_e164: str) -> User:
    user.contact_number = phone_e164
    user.phone_verified_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return user


def clear_phone_verification(db: Session, user: User) -> None:
    user.phone_verified_at = None
    db.commit()
    db.refresh(user)


def get_by_id(db: Session, user_id: int) -> User | None:
    return db.scalar(
        select(User)
        .options(joinedload(User.role), joinedload(User.skill_level))
        .where(User.id == user_id)
    )


def _role_id_for_name(db: Session, role: str) -> int:
    mapping = {
        "admin": RoleName.ADMIN,
        "member": RoleName.MEMBER,
        "organization": RoleName.ORGANIZATION,
    }
    role_name = mapping.get(role.strip().lower(), RoleName.MEMBER)
    row = db.scalar(select(Role).where(Role.role_name == role_name))
    if not row:
        raise ValueError(f"Role not found: {role_name}")
    return row.id


def _skill_level_id_for_name(db: Session, skill_name: str | None) -> int | None:
    if not skill_name or not skill_name.strip():
        return None
    row = db.scalar(
        select(SkillLevel).where(
            func.lower(SkillLevel.level_name) == skill_name.strip().lower()
        )
    )
    return row.id if row else None


def create_user(
    db: Session,
    name: str,
    email: str,
    password: str,
    role: str,
    *,
    status: str | None = None,
    student_id: str | None = None,
    contact_number: str | None = None,
    adviser_name: str | None = None,
    skill_level: str | None = None,
) -> User:
    role_name = role.strip().lower()
    is_admin = role_name == "admin"
    novice = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Novice"))
    skill_id = _skill_level_id_for_name(db, skill_level) or (novice.id if novice else None)

    if status is None:
        account_status = UserStatus.APPROVED if is_admin else UserStatus.PENDING
    else:
        account_status = status.strip().lower()

    from app.services.skill_progression_activation_coord import (
        acquire_member_approval_seal_coordination_lock,
        member_approval_requires_activation_coord_lock,
    )

    # Creating an already-approved Member can race with activation sealing.
    if member_approval_requires_activation_coord_lock(
        previous_status=None,
        new_status=account_status,
        role_name=role,
    ):
        acquire_member_approval_seal_coordination_lock(db)

    user = User(
        fullname=name.strip(),
        email=email.lower(),
        password=hash_password(password),
        role_id=_role_id_for_name(db, role),
        skill_level_id=skill_id,
        status=account_status,
        student_id=student_id.strip() if student_id and student_id.strip() else None,
        contact_number=contact_number.strip() if contact_number and contact_number.strip() else None,
        adviser_name=adviser_name.strip() if adviser_name and adviser_name.strip() else None,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return get_by_id(db, user.id)  # type: ignore[arg-type]


def authenticate(db: Session, email: str, password: str) -> User | None:
    user = get_by_email(db, email)
    if not user or not verify_password(password, user.password):
        return None
    if password_hash_is_legacy(user.password):
        user.password = hash_password(password)
        db.commit()
        db.refresh(user)
    if not user.is_active:
        return None
    return user


def permanently_delete_member(
    db: Session,
    user: User,
    *,
    acting_admin_id: int,
    delete_uploads: bool = True,
) -> "PermanentDeletionStats":
    """
    Remove a Member or Organization row after owned media and storage cleanup.
    Raises RuntimeError when blocked or storage cleanup incomplete.
    """
    from sqlalchemy.exc import IntegrityError

    from app.crud import session as session_crud
    from app.services.member_permanent_deletion import (
        PermanentDeletionStats,
        assert_requestor_permanent_delete_allowed,
        cleanup_member_assignments,
        delete_owned_media_for_user,
    )

    role_name = user.role.role_name if user.role else None
    if role_name not in (RoleName.MEMBER, RoleName.ORGANIZATION):
        raise RuntimeError("Only Member or Organization accounts can be permanently deleted.")
    if user.id == acting_admin_id:
        raise RuntimeError("You cannot delete your own account.")
    if role_name == RoleName.ADMIN:
        raise RuntimeError("Administrator accounts cannot be permanently deleted here.")

    assert_requestor_permanent_delete_allowed(db, user)

    session_crud.revoke_sessions_for_user(db, user.id)

    stats = delete_owned_media_for_user(
        db,
        user.id,
        include_event_gallery=bool(delete_uploads),
    )
    stats.assignments_removed = cleanup_member_assignments(db, user, acting_admin_id=acting_admin_id)

    if stats.media_failed > 0 or stats.storage_queued > 0:
        raise RuntimeError(
            f"Could not finish removing {stats.media_failed} media file(s). "
            f"{stats.storage_queued} storage object(s) queued for retry. "
            "Retry deletion after storage cleanup completes; the account was not removed."
        )

    account_kind = "requestor" if role_name == RoleName.ORGANIZATION else "member"
    try:
        db.delete(user)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise RuntimeError(
            f"This {account_kind} is still linked to records that could not be removed automatically. "
            "Try deactivating the account instead, or contact support."
        ) from exc

    return stats


def deactivate_account(
    db: Session,
    user: User,
    *,
    removed_by: int,
    removal_reason: str | None = None,
) -> User:
    """
    Disable sign-in while preserving the user row, status, and all related history.
    Does not delete media or change registration status (rejected vs approved).
    """
    from app.crud import session as session_crud

    user.is_active = False
    user.removed_at = datetime.now(timezone.utc)
    user.removed_by = removed_by
    user.removal_reason = (removal_reason or "").strip() or None
    db.commit()
    session_crud.revoke_sessions_for_user(db, user.id)
    db.refresh(user)
    return user


def remove_member(
    db: Session,
    user: User,
    *,
    removed_by: int,
    removal_reason: str | None = None,
) -> User:
    """Alias for deactivate_account (legacy admin members route)."""
    return deactivate_account(
        db, user, removed_by=removed_by, removal_reason=removal_reason
    )


def list_users(db: Session) -> list[User]:
    return list(
        db.scalars(
            select(User).options(joinedload(User.role)).order_by(User.created_at.desc())
        )
    )


def set_password(
    db: Session,
    user: User,
    new_password: str,
    *,
    clear_lockout: bool = False,
) -> User:
    """Hash and store a new password. Optionally clear failed-login lockout in the same commit."""
    user.password = hash_password(new_password)
    if clear_lockout:
        user.failed_login_count = 0
        user.locked_until = None
    db.commit()
    db.refresh(user)
    return user


def update_user_by_admin(
    db: Session,
    user: User,
    *,
    name: str,
    email: str,
    role: str,
    skill_level: str | None,
    status: str,
    approved_by: int | None = None,
) -> User:
    """Admin update of profile, role, skill tier, and account status."""
    other = get_by_email(db, email)
    if other and other.id != user.id:
        raise ValueError("Email already registered")

    from app.services.skill_progression_activation_coord import (
        acquire_member_approval_seal_coordination_lock,
        member_approval_requires_activation_coord_lock,
    )

    previous_status = user.status
    user.fullname = name.strip()
    user.email = email.lower().strip()
    user.role_id = _role_id_for_name(db, role)
    skill_id = _skill_level_id_for_name(db, skill_level)
    if skill_id:
        user.skill_level_id = skill_id

    normalized = status.strip().lower()
    if member_approval_requires_activation_coord_lock(
        previous_status=previous_status,
        new_status=normalized,
        role_name=role,
    ):
        acquire_member_approval_seal_coordination_lock(db)

    user.status = normalized
    if normalized == UserStatus.APPROVED:
        user.rejection_reason = None
        user.approved_by = approved_by
        user.approved_at = datetime.now(timezone.utc)
        user.is_active = True
        user.removed_at = None
        user.removed_by = None
        user.removal_reason = None
    elif normalized == UserStatus.REJECTED:
        user.rejection_reason = "Updated by administrator"
        user.approved_by = None
        user.approved_at = None
    else:
        user.rejection_reason = None
        user.approved_by = None
        user.approved_at = None

    db.commit()
    db.refresh(user)
    refreshed = get_by_id(db, user.id)
    return refreshed  # type: ignore[return-value]


def count_active_admins(db: Session) -> int:
    from sqlalchemy import func, select

    return (
        db.scalar(
            select(func.count())
            .select_from(User)
            .join(Role)
            .where(
                Role.role_name == RoleName.ADMIN,
                User.is_active.is_(True),
                User.status == UserStatus.APPROVED,
            )
        )
        or 0
    )


def update_status(
    db: Session,
    user: User,
    status: str,
    *,
    rejection_reason: str | None = None,
    approved_by: int | None = None,
) -> User:
    from app.services.skill_progression_activation_coord import (
        acquire_member_approval_seal_coordination_lock,
        member_approval_requires_activation_coord_lock,
    )

    normalized = status.strip().lower()
    previous_status = user.status
    role_name = user.role.role_name if user.role else None
    if role_name is None and user.role_id is not None:
        role_row = db.get(Role, user.role_id)
        role_name = role_row.role_name if role_row else None
    if member_approval_requires_activation_coord_lock(
        previous_status=previous_status,
        new_status=normalized,
        role_name=role_name,
    ):
        # Serialize with Skill Progression v2 activation sealing.
        acquire_member_approval_seal_coordination_lock(db)

    user.status = normalized
    if normalized == UserStatus.REJECTED:
        user.rejection_reason = (rejection_reason or "").strip() or None
        user.approved_by = None
        user.approved_at = None
    elif normalized == UserStatus.APPROVED:
        user.rejection_reason = None
        user.approved_by = approved_by
        user.approved_at = datetime.now(timezone.utc)
        user.is_active = True
        user.removed_at = None
        user.removed_by = None
        user.removal_reason = None
    else:
        user.rejection_reason = None
        user.approved_by = None
        user.approved_at = None
    db.commit()
    db.refresh(user)
    return user


def update_skill_from_evaluation(db: Session, user: User, score: float) -> None:
    """Deprecated — kept for compatibility. Use [recalculate_skill_level] instead."""
    recalculate_skill_level(db, user)


def recalculate_skill_level(db: Session, user: User) -> str:
    """Recompute skill tier from average quality + integrity (not the latest upload alone).

    Respects admin competency overrides until cleared in Competency Management.
    """
    from app.crud.rankings_admin import resolve_member_skill_level
    from app.services import member_milestones as milestone_service
    from app.services.skill_progression import build_skill_progression_snapshot

    old_level = user.skill_level.level_name if user.skill_level else None
    old_snap = build_skill_progression_snapshot(db, user.id)
    effective, _, _ = resolve_member_skill_level(db, user.id)
    skill_id = _skill_level_id_for_name(db, effective)
    if skill_id:
        user.skill_level_id = skill_id
    db.flush()
    new_snap = build_skill_progression_snapshot(db, user.id)
    milestone_service.on_skill_level_recalculated(
        db,
        user.id,
        old_level=old_level,
        new_level=effective,
        old_computed_tier=old_snap.computed_tier_active,
        new_computed_tier=new_snap.computed_tier_active,
    )
    db.commit()
    return effective


def rankings(db: Session) -> list[dict]:
    from app.crud import rankings_admin

    return rankings_admin.list_rankings(db)
