"""Admin member removal (soft delete)."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.crud import user as user_crud
from app.database import get_db
from app.models.audit_log import AuditLog
from app.models.enums import RoleName
from app.models.user import User
from app.schemas.admin_member import MemberDeleteBody, MemberRemoveBody
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
    if not user.role or user.role.role_name != RoleName.MEMBER:
        raise HTTPException(
            status_code=400,
            detail="Only Member accounts can be removed from Member Management",
        )
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot remove your own admin account")
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Member is already removed")

    reason = (body.removal_reason if body else None) or None
    user_crud.remove_member(db, user, removed_by=admin.id, removal_reason=reason)
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


@router.post("/{user_id}/delete", response_model=MessageResponse)
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
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot delete your own account")

    typed = body.confirmation_email.strip().lower()
    if typed != user.email.strip().lower():
        raise HTTPException(
            status_code=400,
            detail="Confirmation email does not match this member.",
        )

    try:
        media_deleted, media_failed = user_crud.permanently_delete_member(
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
                f"Permanently deleted {deleted_kind} {user_id} ({typed})"
                + (f"; {media_deleted} media file(s) removed" if body.delete_uploads else "")
            ),
        )
    )
    db.commit()

    label = "Requestor account" if role_name == RoleName.ORGANIZATION else "Member account"
    msg = f"{label} permanently deleted."
    if media_deleted:
        msg = f"{label} deleted. {media_deleted} media file(s) removed."
        if media_failed:
            msg += f" {media_failed} file(s) could not be removed."
    elif not body.delete_uploads:
        msg = f"{label} permanently deleted. Practice evaluation uploads were removed from Media Integrity."
    return MessageResponse(message=msg)
