from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class RegistrationOtpSendRequest(BaseModel):
    email: EmailStr
    name: str | None = Field(None, max_length=120, description="Optional greeting on the OTP email")


class RegistrationOtpSendResponse(BaseModel):
    message: str
    """Present when SMTP is off (local dev). Never set when email is sent for real."""
    dev_code: str | None = None


class RegistrationOtpVerifyRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=8)


class RegistrationOtpVerifyResponse(BaseModel):
    email_verification_token: str
    message: str = "Email verified."


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6)
    role: str = Field(default="Member", description="Member | Organization | Admin")
    student_id: str | None = Field(None, max_length=40)
    contact_number: str | None = Field(None, max_length=40)
    adviser_name: str | None = Field(None, max_length=120)
    skill_level: str | None = Field(None, max_length=60, description="Optional skill tier name")
    email_verification_token: str | None = Field(
        None,
        min_length=16,
        max_length=128,
        description="Deprecated: ignored. Email OTP is no longer required for self-registration.",
    )


class UserOut(BaseModel):
    id: int
    name: str
    email: str
    role: str

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    token: str
    user: UserOut
    redirect_hint: str = Field(
        description="web_admin for Admin, mobile_app for Member/Organization"
    )


class ForgotPasswordSendRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=20, description="Philippine mobile (09… or +639…)")


class ForgotPasswordSendResponse(BaseModel):
    message: str
    """Only when SMS_PROVIDER=log (local tests). Never set for TextBee."""
    dev_code: str | None = None
    resend_after_seconds: int | None = None


class ForgotPasswordCompleteRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=20)
    code: str = Field(min_length=4, max_length=8)
    new_password: str = Field(min_length=6)


class ForgotPasswordCompleteResponse(BaseModel):
    message: str
    """Masked email for the account that was updated (e.g. j***e@school.edu)."""
    account_email_hint: str | None = None


class PhoneVerifySendRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=20)


class PhoneVerifySendResponse(BaseModel):
    message: str
    phone: str
    phone_verified: bool = False
    """Only when SMS_PROVIDER=log (local tests). Never set for TextBee."""
    dev_code: str | None = None
    resend_after_seconds: int | None = None


class PhoneVerifyCompleteRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=20)
    code: str = Field(min_length=4, max_length=8)


class PhoneVerifyCompleteResponse(BaseModel):
    message: str
    phone: str
    phone_verified: bool = True
