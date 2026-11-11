"""Single login API for Admin (Web) and Member/Organization (Mobile)."""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_approved
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
    lockout_detail_message,
    record_failed_login,
    security_config,
)
from app.crud import password_reset_sms_otp as reset_otp_crud
from app.crud import phone_verification_otp as phone_verify_otp_crud
from app.crud import registration_email_otp as email_otp_crud
from app.schemas.auth import (
    ForgotPasswordCompleteRequest,
    ForgotPasswordCompleteResponse,
    ForgotPasswordSendRequest,
    ForgotPasswordSendResponse,
    LoginRequest,
    LoginResponse,
    PhoneVerifyCompleteRequest,
    PhoneVerifyCompleteResponse,
    PhoneVerifySendRequest,
    PhoneVerifySendResponse,
    RegisterRequest,
    RegistrationOtpSendRequest,
    RegistrationOtpSendResponse,
    RegistrationOtpVerifyRequest,
    RegistrationOtpVerifyResponse,
    UserOut,
)
from app.schemas.common import MessageResponse
from app.services import registration_email
from app.services import sms_rate_limit
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
            detail=lockout_detail_message(existing),
        )

    if existing and verify_password(body.password, existing.password) and not existing.is_active:
        deactivated = existing.removed_at is not None and existing.status == UserStatus.APPROVED
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "error": "deactivated" if deactivated else "removed",
                "message": (
                    "Your account has been deactivated. Contact your ACCESS administrator to restore access."
                    if deactivated
                    else "Your account has been removed. Please contact the administrator."
                ),
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
    "If a verified account exists for this mobile number, a 6-digit reset code was sent by SMS."
)


def _client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


def _mask_email(email: str) -> str:
    text = (email or "").strip()
    if "@" not in text:
        return "***"
    local, _, domain = text.partition("@")
    if len(local) <= 2:
        masked_local = f"{local[:1]}*" if local else "*"
    else:
        masked_local = f"{local[0]}{'*' * (len(local) - 2)}{local[-1]}"
    return f"{masked_local}@{domain}"


@router.post("/forgot-password/send", response_model=ForgotPasswordSendResponse)
def forgot_password_send(
    body: ForgotPasswordSendRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """SMS a 6-digit OTP for password reset (verified phones only). Generic response always."""
    try:
        phone = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    ip = _client_ip(request)
    generic = ForgotPasswordSendResponse(
        message=_GENERIC_RESET_SEND,
        dev_code=None,
        resend_after_seconds=settings.sms_reset_otp_resend_seconds,
    )
    user = user_crud.get_by_verified_phone(db, phone)
    if not user or not user.is_active or user.status != UserStatus.APPROVED:
        # Still bill IP rate limit so unknown numbers cannot flood probes.
        try:
            sms_rate_limit.check_and_record(
                key=f"ip:{ip or 'unknown'}",
                limit=settings.sms_rate_limit_per_ip_hour,
                window_s=3600.0,
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc
        return generic

    try:
        code = reset_otp_crud.send_otp(
            db,
            phone,
            fullname=user.fullname or "",
            client_ip=ip,
            actually_deliver=True,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc)) from exc

    provider = (settings.sms_provider or "log").strip().lower()
    if provider == "log":
        return ForgotPasswordSendResponse(
            message=(
                "Development mode (SMS_PROVIDER=log): reset code is shown below. "
                "TextBee is not used."
            ),
            dev_code=code,
            resend_after_seconds=settings.sms_reset_otp_resend_seconds,
        )
    return generic


@router.post("/forgot-password/complete", response_model=ForgotPasswordCompleteResponse)
def forgot_password_complete(body: ForgotPasswordCompleteRequest, db: Session = Depends(get_db)):
    """Verify SMS OTP and set a new password. Revokes existing sessions."""
    try:
        phone = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    new_password = (body.new_password or "").strip()
    user = user_crud.get_by_verified_phone(db, phone)
    if not user or not user.is_active or user.status != UserStatus.APPROVED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not reset password. Check your mobile number and code, or request a new code.",
        )
    try:
        reset_otp_crud.verify_and_consume(db, phone, body.code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    assert_password_meets_policy(db, new_password)
    user_id = user.id
    account_email = user.email
    # Same commit clears failed-login counters / locked_until so a successful SMS
    # reset is immediately usable (prior wrong-password lockouts must not linger).
    user_crud.set_password(db, user, new_password, clear_lockout=True)
    # Confirm the committed hash verifies before telling the client it succeeded.
    fresh = user_crud.get_by_id(db, user_id)
    if not fresh or not verify_password(new_password, fresh.password):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password update did not persist. Please request a new code and try again.",
        )
    if is_account_locked(fresh) or int(getattr(fresh, "failed_login_count", 0) or 0) != 0:
        clear_login_failures(db, fresh)
        fresh = user_crud.get_by_id(db, user_id)
    if not fresh or is_account_locked(fresh):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password updated but account lockout could not be cleared. Try again later or contact an administrator.",
        )
    session_crud.revoke_sessions_for_user(db, user_id)
    return ForgotPasswordCompleteResponse(
        message="Password updated. Sign in with your new password.",
        account_email_hint=_mask_email(account_email),
    )


@router.post("/phone/verify/send", response_model=PhoneVerifySendResponse)
def phone_verify_send(
    body: PhoneVerifySendRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    """Authenticated enrollment: SMS OTP to claim a recovery mobile number."""
    try:
        phone = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    conflict = user_crud.find_verified_phone_conflict(db, phone, exclude_user_id=current_user.id)
    if conflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This mobile number is already verified on another account.",
        )

    user = user_crud.get_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    previous = (user.contact_number or "").strip()
    if phone != previous or user.phone_verified_at is None:
        user.contact_number = phone
        user.phone_verified_at = None
        db.commit()
        db.refresh(user)

    try:
        code = phone_verify_otp_crud.send_otp(
            db,
            user_id=user.id,
            phone_e164=phone,
            client_ip=_client_ip(request),
        )
    except ValueError as exc:
        detail = str(exc)
        code_status = (
            status.HTTP_429_TOO_MANY_REQUESTS
            if "wait" in detail.lower() or "too many" in detail.lower() or "unavailable" in detail.lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=code_status, detail=detail) from exc

    provider = (settings.sms_provider or "log").strip().lower()
    return PhoneVerifySendResponse(
        message="A 6-digit verification code was sent by SMS.",
        phone=phone,
        phone_verified=False,
        dev_code=code if provider == "log" else None,
        resend_after_seconds=settings.sms_reset_otp_resend_seconds,
    )


@router.post("/phone/verify/complete", response_model=PhoneVerifyCompleteResponse)
def phone_verify_complete(
    body: PhoneVerifyCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    try:
        phone = normalize_ph_mobile(body.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    conflict = user_crud.find_verified_phone_conflict(db, phone, exclude_user_id=current_user.id)
    if conflict:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This mobile number is already verified on another account.",
        )

    try:
        phone_verify_otp_crud.verify_and_consume(
            db,
            user_id=current_user.id,
            phone_e164=phone,
            code=body.code,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    user = user_crud.get_by_id(db, current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user_crud.mark_phone_verified(db, user, phone)
    return PhoneVerifyCompleteResponse(
        message="Mobile number verified. You can use SMS password recovery.",
        phone=phone,
        phone_verified=True,
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

    # Email OTP is no longer required for Member/Organization self-registration.
    # Optional token is ignored if present so older clients do not fail hard.
    # Do not treat registration as email-verified (no email_verified flag is set).
    contact_for_user = None
    if role_key in ("member", "organization"):
        raw_contact = (body.contact_number or "").strip()
        if not raw_contact:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mobile number is required for registration.",
            )
        try:
            contact_for_user = normalize_ph_mobile(raw_contact)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        # Phone is stored for profile/recovery enrollment only. SMS ownership
        # proof still happens via /auth/phone/verify (do not set phone_verified_at here).
        if user_crud.find_verified_phone_conflict(db, contact_for_user):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This mobile number is already registered to another account.",
            )
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
