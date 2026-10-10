"""Admin registration approval workflow for members and organizations."""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.crud import registrations as reg_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.audit_log import AuditLog
from app.models.enums import RoleName, UserStatus
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.registration import (
    MemberRegistrationOut,
    OrganizationRegistrationOut,
    RegistrationRejectBody,
)
from app.services import registration_email

router = APIRouter(prefix="/admin/registrations", tags=["Registration Approvals"])


def _require_user_with_role(db: Session, user_id: int, expected_role: str) -> User:
    user = user_crud.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Registration not found")
    if not user.role or user.role.role_name != expected_role:
        raise HTTPException(status_code=404, detail=f"Not a {expected_role} registration")
    return user


@router.get("/members", response_model=list[MemberRegistrationOut])
def list_member_registrations(
    status: str = Query("pending", description="pending | approved | rejected | all"),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    rows = reg_crud.list_member_registrations(db, status=status)
    return [MemberRegistrationOut(**row) for row in rows]


@router.get("/organizations", response_model=list[OrganizationRegistrationOut])
def list_organization_registrations(
    status: str = Query("pending", description="pending | approved | rejected | all"),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    rows = reg_crud.list_organization_registrations(db, status=status)
    return [OrganizationRegistrationOut(**row) for row in rows]


def _approve(db: Session, user: User, admin: User) -> MessageResponse:
    user_crud.update_status(db, user, UserStatus.APPROVED, approved_by=admin.id)
    db.add(
        AuditLog(
            user_id=admin.id,
            action="registration_approved",
            description=f"Approved user {user.id} ({user.email})",
        )
    )
    db.commit()
    registration_email.notify_registration_approved_async(
        to_email=user.email,
        fullname=user.fullname or user.email,
    )
    return MessageResponse(message="Registration approved")


def _reject(db: Session, user: User, admin: User, reason: str) -> MessageResponse:
    user_crud.update_status(
        db,
        user,
        UserStatus.REJECTED,
        rejection_reason=reason,
    )
    db.add(
        AuditLog(
            user_id=admin.id,
            action="registration_rejected",
            description=f"Rejected user {user.id}: {reason}",
        )
    )
    db.commit()
    registration_email.notify_registration_rejected_async(
        to_email=user.email,
        fullname=user.fullname or user.email,
        reason=reason,
    )
    return MessageResponse(message="Registration rejected")


@router.post("/members/{user_id}/approve", response_model=MessageResponse)
def approve_member(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = _require_user_with_role(db, user_id, RoleName.MEMBER)
    return _approve(db, user, admin)


@router.post("/members/{user_id}/reject", response_model=MessageResponse)
def reject_member(
    user_id: int,
    body: RegistrationRejectBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = _require_user_with_role(db, user_id, RoleName.MEMBER)
    return _reject(db, user, admin, body.rejection_reason.strip())


@router.post("/organizations/{user_id}/approve", response_model=MessageResponse)
def approve_organization(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = _require_user_with_role(db, user_id, RoleName.ORGANIZATION)
    return _approve(db, user, admin)


@router.post("/organizations/{user_id}/reject", response_model=MessageResponse)
def reject_organization(
    user_id: int,
    body: RegistrationRejectBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = _require_user_with_role(db, user_id, RoleName.ORGANIZATION)
    return _reject(db, user, admin, body.rejection_reason.strip())
