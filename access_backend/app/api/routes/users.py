from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import secrets

from app.api.deps import require_admin
from app.crud import admin_members as admin_members_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.audit_log import AuditLog
from app.models.enums import RoleName, UserStatus
from app.models.user import User
from app.crud import media as media_crud
from app.schemas.admin_member import (
    AdminMemberResponse,
    AdminUserProfileResponse,
    UserRoleUpdate,
    UserStatusUpdate,
    UserStatusUpdateResponse,
)
from app.schemas.common import MessageResponse
from app.schemas.user import PasswordResetResponse, UserCreate, UserResponse, UserUpdate
from app.services.security_policy import assert_password_meets_policy

router = APIRouter(tags=["Users"])


@router.post("/users", response_model=UserResponse)
def create_user(
    body: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin: create a new user account."""
    if user_crud.get_by_email(db, body.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    password = (body.password or "").strip() or secrets.token_urlsafe(12)
    if body.password and body.password.strip():
        assert_password_meets_policy(db, password)
    status = (body.status or "").strip().lower() or None
    if status and status not in ("approved", "pending", "rejected"):
        raise HTTPException(status_code=400, detail="status must be approved, pending, or rejected")
    user = user_crud.create_user(
        db,
        body.name,
        body.email,
        password,
        body.role,
        status=status,
        skill_level=body.skill_level,
    )
    ranking = user.member_ranking
    return UserResponse(
        user_id=user.id,
        name=user.fullname,
        email=user.email,
        role=user.role.role_name,
        status=user.status,
        skill_level=user.skill_level.level_name if user.skill_level else None,
        good_evaluations=ranking.total_points if ranking else 0,
        avg_score=0.0,
        created_at=user.created_at,
    )


@router.get("/users", response_model=list[AdminMemberResponse])
def list_users(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return [AdminMemberResponse(**row) for row in admin_members_crud.list_admin_members(db)]


def _ensure_admin_privilege_change_allowed(
    db: Session,
    target: User,
    new_role: str,
    new_status: str,
) -> None:
    """Block demotion or deactivation of the last active administrator."""
    if target.role.role_name != RoleName.ADMIN:
        return
    demoting = new_role.strip() != RoleName.ADMIN
    deactivating = new_status.strip().lower() != UserStatus.APPROVED
    if not demoting and not deactivating:
        return
    if user_crud.count_active_admins(db) <= 1:
        raise HTTPException(
            status_code=403,
            detail="Cannot modify privileges of the last administrator account.",
        )


@router.get("/users/{user_id}/profile", response_model=AdminUserProfileResponse)
def get_user_profile(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin: full read-only profile with recent login/audit activity."""
    row = admin_members_crud.get_admin_member(db, user_id)
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    activity = admin_members_crud.list_user_recent_activity(db, user_id, limit=10)
    return AdminUserProfileResponse(
        **row,
        recent_activity=activity,
    )


@router.patch("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    body: UserUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: update user profile, role, skill level, and account status."""
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    status = body.status.strip().lower()
    if status not in (UserStatus.APPROVED, UserStatus.PENDING, UserStatus.REJECTED):
        raise HTTPException(status_code=400, detail="status must be approved, pending, or rejected")

    _ensure_admin_privilege_change_allowed(db, user, body.role, status)

    try:
        updated = user_crud.update_user_by_admin(
            db,
            user,
            name=body.name,
            email=str(body.email),
            role=body.role,
            skill_level=body.skill_level,
            status=status,
            approved_by=admin.id if status == UserStatus.APPROVED else None,
        )
    except ValueError as exc:
        if "Email already" in str(exc):
            raise HTTPException(status_code=409, detail="Email already registered") from exc
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    ranking = updated.member_ranking
    return UserResponse(
        user_id=updated.id,
        name=updated.fullname,
        email=updated.email,
        role=updated.role.role_name,
        status=updated.status,
        skill_level=updated.skill_level.level_name if updated.skill_level else None,
        good_evaluations=ranking.total_points if ranking else 0,
        avg_score=0.0,
        created_at=updated.created_at,
    )


@router.get("/users/{user_id}/media-upload-count")
def media_upload_count(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin: count gallery / evaluation files uploaded by this user."""
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"count": media_crud.count_for_uploader(db, user_id)}


@router.patch("/users/{user_id}/status", response_model=UserStatusUpdateResponse)
def update_user_status(
    user_id: int,
    body: UserStatusUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    status = body.status.strip().lower()
    if status == "rejected" and not (body.rejection_reason or "").strip():
        raise HTTPException(status_code=400, detail="Rejection reason is required")
    if body.delete_uploads:
        if status != "rejected":
            raise HTTPException(
                status_code=400,
                detail="delete_uploads is only allowed when setting status to rejected.",
            )
        if not user.role or user.role.role_name not in (RoleName.MEMBER, RoleName.ORGANIZATION):
            raise HTTPException(
                status_code=400,
                detail="delete_uploads applies to Member and Organization accounts only.",
            )

    media_deleted = 0
    media_failed = 0
    if body.delete_uploads and status == "rejected":
        media_deleted, media_failed = media_crud.delete_all_for_uploader(db, user.id)

    user_crud.update_status(
        db,
        user,
        status,
        rejection_reason=body.rejection_reason,
        approved_by=admin.id if status == "approved" else None,
    )
    if body.rejection_reason:
        db.add(
            AuditLog(
                user_id=admin.id,
                action="member_rejected",
                description=f"User {user_id} rejected: {body.rejection_reason.strip()}",
            )
        )
        db.commit()
    if body.delete_uploads and media_deleted:
        db.add(
            AuditLog(
                user_id=admin.id,
                action="member_media_purged",
                description=f"Deleted {media_deleted} media file(s) for user {user_id} during deactivation.",
            )
        )
        db.commit()
    message = f"User {status}"
    if body.delete_uploads:
        if media_deleted and not media_failed:
            message = f"User {status}. {media_deleted} media file(s) deleted."
        elif media_deleted and media_failed:
            message = (
                f"User {status}. {media_deleted} media file(s) deleted; "
                f"{media_failed} could not be removed."
            )
        elif media_failed:
            message = f"User {status}. No media files deleted ({media_failed} failed)."
    return UserStatusUpdateResponse(
        message=message,
        media_deleted=media_deleted,
        media_delete_failed=media_failed,
    )


@router.patch("/users/{user_id}/role", response_model=MessageResponse)
def update_user_role(
    user_id: int,
    body: UserRoleUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    _ensure_admin_privilege_change_allowed(db, user, body.role, user.status)
    try:
        role_id = user_crud._role_id_for_name(db, body.role)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    user.role_id = role_id
    db.commit()
    return MessageResponse(message=f"Role updated to {body.role}")


@router.post("/users/{user_id}/reset-password", response_model=PasswordResetResponse)
def reset_user_password(
    user_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin: issue a new temporary password for the user."""
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    temp_password = secrets.token_urlsafe(10)
    user_crud.set_password(db, user, temp_password)
    return PasswordResetResponse(
        message="Temporary password generated. Share it securely with the user.",
        temporary_password=temp_password,
    )
