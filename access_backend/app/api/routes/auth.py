"""Single login API for Admin (Web) and Member/Organization (Mobile)."""

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
from app.crud import password_reset_email_otp as reset_otp_crud
from app.crud import registration_email_otp as email_otp_crud
from app.schemas.auth import (
    ForgotPasswordCompleteRequest,
    ForgotPasswordCompleteResponse,
    ForgotPasswordSendRequest,
    ForgotPasswordSendResponse,
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
from app.services.email_delivery import is_email_configured
from app.services.phone_normalize import normalize_ph_mobile

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Seed/demo domains have no MX records (mail to admin@access.edu always bounces).
_NON_DELIVERABLE_EMAIL_DOMAINS = frozenset({"access.edu"})


def _reject_non_deliverable_otp_email(email: str) -> None:
    domain = email.rsplit("@", 1)[-1].strip().lower()
    if domain not in _NON_DELIVERABLE_EMAIL_DOMAINS:
        return
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=(
            "This address cannot receive email (access.edu is sign-in demo only, not a real mailbox). "
            "Use Gmail, Outlook, or your school email for verification codes. "
            "Admins: sign in, open Profile, and set a real email, then use Forgot password with that address."
        ),
    )


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
    email = str(body.email).strip().lower()
    existing = user_crud.get_by_email(db, email)
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

    user = user_crud.authenticate(db, email, body.password)
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


_GENERIC_RESET_SEND = (
    "If an account exists for this email, a 6-digit reset code was sent. "
    "Check your inbox (and spam folder)."
)


@router.post("/forgot-password/send", response_model=ForgotPasswordSendResponse)
def forgot_password_send(body: ForgotPasswordSendRequest, db: Session = Depends(get_db)):
    """Email a 6-digit OTP for password reset (all approved roles). Dev: code on screen when SMTP is off."""
    email = str(body.email).strip().lower()
    _reject_non_deliverable_otp_email(email)
    generic = ForgotPasswordSendResponse(message=_GENERIC_RESET_SEND, dev_code=None)
    user = user_crud.get_by_email(db, email)
    if not user or not user.is_active:
        return generic
    if user.status != UserStatus.APPROVED:
        return ForgotPasswordSendResponse(
            message=(
                "This account is not active for sign-in. "
                "Contact your ACCESS administrator for help."
            ),
            dev_code=None,
        )

    try:
        code = reset_otp_crud.send_otp(
            db,
            user.email,
            fullname=user.fullname or user.email,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc

    if is_email_configured():
        return ForgotPasswordSendResponse(message=_GENERIC_RESET_SEND, dev_code=None)
    return ForgotPasswordSendResponse(
        message=(
            "Development mode: your reset code is shown below on this screen "
            "(and printed in the backend terminal)."
        ),
        dev_code=code,
    )


@router.post("/forgot-password/complete", response_model=ForgotPasswordCompleteResponse)
def forgot_password_complete(body: ForgotPasswordCompleteRequest, db: Session = Depends(get_db)):
    """Verify email OTP and set a new password."""
    user = user_crud.get_by_email(db, body.email)
    if not user or not user.is_active or user.status != UserStatus.APPROVED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not reset password. Check your email and code, or request a new code.",
        )
    try:
        reset_otp_crud.verify_and_consume(db, user.email, body.code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    assert_password_meets_policy(db, body.new_password)
    user_crud.set_password(db, user, body.new_password)
    clear_login_failures(db, user)
    session_crud.revoke_sessions_for_user(db, user.id)
    return ForgotPasswordCompleteResponse(
        message="Password updated. Sign in with your new password.",
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


_GENERIC_REGISTRATION_OTP = (
    "If this email is available for registration, a 6-digit verification code was sent. "
    "Check your inbox (and spam folder)."
)


@router.post("/registration-otp/send", response_model=RegistrationOtpSendResponse)
def send_registration_otp(body: RegistrationOtpSendRequest, db: Session = Depends(get_db)):
    email = str(body.email).strip().lower()
    _reject_non_deliverable_otp_email(email)
    if user_crud.get_by_email(db, email):
        return RegistrationOtpSendResponse(message=_GENERIC_REGISTRATION_OTP, dev_code=None)
    try:
        code = email_otp_crud.send_otp(
            db,
            email,
            fullname=(body.name or "").strip(),
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
    if is_email_configured():
        return RegistrationOtpSendResponse(message=_GENERIC_REGISTRATION_OTP, dev_code=None)
    return RegistrationOtpSendResponse(
        message=(
            "Development mode: your verification code is shown below on this screen "
            "(and printed in the backend terminal)."
        ),
        dev_code=code,
    )


@router.post("/registration-otp/verify", response_model=RegistrationOtpVerifyResponse)
def verify_registration_otp(body: RegistrationOtpVerifyRequest, db: Session = Depends(get_db)):
    email = str(body.email).strip().lower()
    if user_crud.get_by_email(db, email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email is already registered. Sign in or use Forgot password.",
        )
    try:
        token = email_otp_crud.verify_otp(db, email, body.code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return RegistrationOtpVerifyResponse(email_verification_token=token)


@router.post("/register", response_model=MessageResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    role_key = _registration_role_key(body.role)
    if role_key == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator accounts cannot be registered through the mobile app.",
        )
    if role_key in ("member", "organization"):
        if not body.email_verification_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verify your email with the code before submitting registration.",
            )
        try:
            email_otp_crud.consume_verification_token(
                db,
                str(body.email).strip().lower(),
                body.email_verification_token,
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        contact_for_user = None
        if body.contact_number and body.contact_number.strip():
            try:
                contact_for_user = normalize_ph_mobile(body.contact_number)
            except ValueError as exc:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
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
        student_id=user.student_id,
    )
    return MessageResponse(message="Registration submitted. Awaiting admin approval.")
