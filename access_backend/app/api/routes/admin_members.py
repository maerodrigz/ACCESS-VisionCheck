"""Admin member removal (soft delete)."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.crud import user as user_crud
from app.database import get_db
from app.models.audit_log import AuditLog
from app.models.enums import RoleName
from app.models.user import User
from app.schemas.admin_member import (
    MemberDeleteBody,
    MemberPermanentDeleteResponse,
    MemberRemoveBody,
)
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/admin/members", tags=["Admin Members"])


@router.patch("/{user_id}/remove", response_model=MessageResponse)
def remove_member(
    user_id: int,
    body: MemberRemoveBody | None = None,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Member not found")
    if not user.role or user.role.role_name not in (RoleName.MEMBER, RoleName.ORGANIZATION):
        raise HTTPException(
            status_code=400,
            detail="Only Member or Organization accounts can be deactivated via this route",
        )
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot remove your own admin account")
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Member is already removed")

    reason = (body.removal_reason if body else None) or None
    user_crud.deactivate_account(db, user, removed_by=admin.id, removal_reason=reason)
    db.add(
        AuditLog(
            user_id=admin.id,
            action="member_removed",
            description=f"Removed member {user_id} ({user.email})"
            + (f": {reason}" if reason else ""),
        )
    )
    db.commit()
    return MessageResponse(message="Member removed successfully")


@router.post("/{user_id}/delete", response_model=MemberPermanentDeleteResponse)
def permanently_delete_member(
    user_id: int,
    body: MemberDeleteBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Member not found")
    role_name = user.role.role_name if user.role else None
    if role_name not in (RoleName.MEMBER, RoleName.ORGANIZATION):
        raise HTTPException(
            status_code=400,
            detail="Only Member or Organization (requestor) accounts can be permanently deleted.",
        )
    if role_name == RoleName.ADMIN:
        raise HTTPException(status_code=400, detail="Administrator accounts cannot be permanently deleted here.")
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot delete your own account")

    typed = body.confirmation_email.strip().lower()
    if typed != user.email.strip().lower():
        raise HTTPException(
            status_code=400,
            detail="Confirmation email does not match this member.",
        )

    try:
        stats = user_crud.permanently_delete_member(
            db,
            user,
            acting_admin_id=admin.id,
            delete_uploads=body.delete_uploads,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    deleted_kind = "requestor" if role_name == RoleName.ORGANIZATION else "member"
    db.add(
        AuditLog(
            user_id=admin.id,
            action="member_deleted",
            description=(
                f"Permanently deleted {deleted_kind} {user_id} ({typed}); "
                f"media_deleted={stats.media_deleted}; storage_deleted={stats.storage_deleted}; "
                f"chains_removed={stats.chains_removed}"
            ),
        )
    )
    db.commit()

    label = "Requestor account" if role_name == RoleName.ORGANIZATION else "Member account"
    msg = (
        f"{label} permanently deleted. "
        f"{stats.media_deleted} media record(s) and {stats.storage_deleted} storage object(s) removed."
    )
    return MemberPermanentDeleteResponse(
        message=msg,
        media_deleted=stats.media_deleted,
        media_failed=stats.media_failed,
        storage_deleted=stats.storage_deleted,
        storage_queued=stats.storage_queued,
        chains_removed=stats.chains_removed,
        assignments_removed=stats.assignments_removed,
        partial_failure=False,
    )


@router.post("/{user_id}/retry-storage-cleanup", response_model=MemberPermanentDeleteResponse)
def retry_member_storage_cleanup(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Retry queued Supabase/local deletes for a member whose account delete was blocked."""
    from app.crud import pending_storage_deletion as pending_crud

    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    stats = pending_crud.retry_for_user(db, user_id)
    partial = stats.media_failed > 0
    msg = (
        f"Storage retry complete. {stats.media_deleted} media record(s) removed, "
        f"{stats.storage_deleted} storage object(s) deleted."
    )
    if partial:
        msg += f" {stats.media_failed} item(s) still need attention."
    return MemberPermanentDeleteResponse(
        message=msg,
        media_deleted=stats.media_deleted,
        media_failed=stats.media_failed,
        storage_deleted=stats.storage_deleted,
        storage_queued=stats.media_failed,
        partial_failure=partial,
    )
