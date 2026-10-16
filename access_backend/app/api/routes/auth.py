"""Single login API for Admin (Web) and Member/Organization (Mobile)."""

import secrets

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.config import settings
from app.core.security import create_access_token, verify_password
from app.crud import session as session_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.enums import RoleName, UserStatus
from app.models.user import User
from app.services.security_policy import (
    assert_password_meets_policy,
    clear_login_failures,
    is_account_locked,
    record_failed_login,
    security_config,
)
from app.crud import registration_phone_otp as phone_otp_crud
from app.schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegistrationOtpSendRequest,
    RegistrationOtpSendResponse,
    RegistrationOtpVerifyRequest,
    RegistrationOtpVerifyResponse,
    UserOut,
)
from app.schemas.common import MessageResponse
from app.services import registration_email
from app.services.phone_normalize import normalize_ph_mobile

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _redirect_hint(role_name: str) -> str:
    """Flutter uses this to know which platform to open after login."""
    if role_name == RoleName.ADMIN:
        return "web_admin"
    return "mobile_app"


def _user_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        name=user.fullname,
        email=user.email,
        role=user.role.role_name,
    )


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    existing = user_crud.get_by_email(db, body.email)
    if existing and is_account_locked(existing):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account temporarily locked due to too many failed sign-in attempts. Try again later.",
        )

    if existing and verify_password(body.password, existing.password) and not existing.is_active:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "error": "removed",
                "message": "Your account has been removed. Please contact the administrator.",
            },
        )

    user = user_crud.authenticate(db, body.email, body.password)
    if not user:
        if existing:
            record_failed_login(db, existing)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if user.status == UserStatus.PENDING:
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "error": "pending",
                "message": "Your account is still pending admin approval.",
            },
        )
    if user.status == UserStatus.REJECTED:
        message = "Your account registration was rejected. Please contact the administrator."
        reason = (user.rejection_reason or "").strip()
        if reason:
            message = f"{message} Reason: {reason}"
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "error": "rejected",
                "message": message,
            },
        )

    clear_login_failures(db, user)
    cfg = security_config(db)
    role_name = user.role.role_name
    # Members stay signed in for JWT_EXPIRE_MINUTES (default 7 days). Admin web uses
    # the shorter session_timeout_minutes from Security settings (default 60 min).
    if role_name in (RoleName.MEMBER, RoleName.ORGANIZATION):
        expire_minutes = settings.jwt_expire_minutes
    else:
        expire_minutes = cfg["session_timeout_minutes"]
    token = create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": role_name,
        },
        expire_minutes=expire_minutes,
    )
    client_host = request.client.host if request.client else None
    device = request.headers.get("user-agent", "unknown")[:255]
    session_crud.record_login(db, user.id, ip_address=client_host, device_info=device)
    session_crud.create_session(
        db,
        user.id,
        token,
        expire_minutes=expire_minutes,
    )

    return LoginResponse(
        token=token,
        user=_user_out(user),
        redirect_hint=_redirect_hint(role_name),
    )


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Issue a temporary admin password (admin portal recovery — no email service yet)."""
    generic = ForgotPasswordResponse(
        message=(
            "If an administrator account exists for this email, "
            "a temporary password has been generated."
        ),
        reset=False,
    )
    user = user_crud.get_by_email(db, body.email)
    if not user or not user.is_active:
        return generic
    if user.role.role_name != RoleName.ADMIN:
        return generic
    if user.status != UserStatus.APPROVED:
        return ForgotPasswordResponse(
            message=(
                "This administrator account is not active for sign-in. "
                "Contact another administrator for help."
            ),
            reset=False,
        )

    temp_password = secrets.token_urlsafe(10)
    user_crud.set_password(db, user, temp_password)
    clear_login_failures(db, user)
    return ForgotPasswordResponse(
        message=(
            "A temporary password was generated. Sign in with it below, "
            "then update your password from Account Management."
        ),
        temporary_password=temp_password,
        reset=True,
    )


@router.post("/logout", response_model=MessageResponse)
def logout(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session_crud.revoke_sessions_for_user(db, current_user.id)
    return MessageResponse(message="Logged out")


def _registration_role_key(role: str) -> str:
    return role.strip().lower()


@router.post("/registration-otp/send", response_model=RegistrationOtpSendResponse)
def send_registration_otp(body: RegistrationOtpSendRequest, db: Session = Depends(get_db)):
    try:
        phone_e164 = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    try:
        code = phone_otp_crud.send_otp(db, phone_e164)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
    provider = (settings.sms_provider or "log").strip().lower()
    if provider == "log":
        msg = (
            "Development mode: your verification code is shown below on this screen "
            "(and printed in the backend terminal)."
        )
        return RegistrationOtpSendResponse(message=msg, dev_code=code)
    return RegistrationOtpSendResponse(
        message="Verification code sent via SMS.",
        dev_code=None,
    )


@router.post("/registration-otp/verify", response_model=RegistrationOtpVerifyResponse)
def verify_registration_otp(body: RegistrationOtpVerifyRequest, db: Session = Depends(get_db)):
    try:
        phone_e164 = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    try:
        token = phone_otp_crud.verify_otp(db, phone_e164, body.code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return RegistrationOtpVerifyResponse(phone_verification_token=token)


@router.post("/register", response_model=MessageResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    role_key = _registration_role_key(body.role)
    if role_key == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator accounts cannot be registered through the mobile app.",
        )
    if role_key in ("member", "organization"):
        if not body.contact_number or not body.phone_verification_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verify your mobile number before submitting registration.",
            )
        try:
            phone_e164 = normalize_ph_mobile(body.contact_number)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        try:
            phone_otp_crud.consume_verification_token(
                db, phone_e164, body.phone_verification_token
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        contact_for_user = phone_e164
    else:
        contact_for_user = body.contact_number

    if user_crud.get_by_email(db, body.email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    assert_password_meets_policy(db, body.password)
    user = user_crud.create_user(
        db,
        body.name,
        body.email,
        body.password,
        body.role,
        student_id=body.student_id,
        contact_number=contact_for_user,
        adviser_name=body.adviser_name,
        skill_level=body.skill_level,
    )
    role_name = user.role.role_name if user.role else None
    registration_email.notify_registration_received_async(
        to_email=user.email,
        fullname=user.fullname or user.email,
        role_name=role_name,
    )
    return MessageResponse(message="Registration submitted. Awaiting admin approval.")
