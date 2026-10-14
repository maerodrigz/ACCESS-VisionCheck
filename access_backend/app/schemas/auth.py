from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class RegistrationOtpSendRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=40)


class RegistrationOtpVerifyRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=40)
    code: str = Field(min_length=4, max_length=8)


class RegistrationOtpVerifyResponse(BaseModel):
    phone_verification_token: str
    message: str = "Phone verified."


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6)
    role: str = Field(default="Member", description="Member | Organization | Admin")
    student_id: str | None = Field(None, max_length=40)
    contact_number: str | None = Field(None, max_length=40)
    adviser_name: str | None = Field(None, max_length=120)
    skill_level: str | None = Field(None, max_length=60, description="Optional skill tier name")
    phone_verification_token: str | None = Field(
        None,
        min_length=16,
        max_length=128,
        description="Required for Member and Organization self-registration",
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


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    temporary_password: str | None = None
    reset: bool = False
