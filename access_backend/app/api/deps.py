"""FastAPI dependencies: JWT auth and role-based access control."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.crud import session as session_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.enums import RoleName, UserStatus
from app.models.user import User

security = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No token")
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    # Enforce tracked sessions so logout / password-reset revocation takes effect immediately.
    active = session_crud.get_active_session(db, token)
    if active is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session revoked")
    user = user_crud.get_by_id(db, int(payload["userId"]))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if active.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "removed",
                "message": "Your account has been removed. Please contact the administrator.",
            },
        )
    return user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role.role_name != RoleName.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")
    return current_user


def require_approved(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "removed",
                "message": "Your account has been removed. Please contact the administrator.",
            },
        )
    if current_user.status == UserStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "pending", "message": "Account pending admin approval"},
        )
    if current_user.status == UserStatus.REJECTED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "rejected", "message": "Account not approved"},
        )
    return current_user


def require_organization(current_user: User = Depends(require_approved)) -> User:
    if current_user.role.role_name != RoleName.ORGANIZATION:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requestor (Organization) accounts only",
        )
    return current_user


def require_member(current_user: User = Depends(require_approved)) -> User:
    if current_user.role.role_name != RoleName.MEMBER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Member accounts only",
        )
    return current_user


def require_member_or_organization(current_user: User = Depends(require_approved)) -> User:
    if current_user.role.role_name not in (RoleName.MEMBER, RoleName.ORGANIZATION):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Member or requestor accounts only",
        )
    return current_user
