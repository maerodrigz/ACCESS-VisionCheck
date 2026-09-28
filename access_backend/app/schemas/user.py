from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserResponse(BaseModel):
    user_id: int
    name: str
    email: str
    role: str
    status: str
    skill_level: str | None = None
    good_evaluations: int = 0
    avg_score: float = 0.0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class UserStatusUpdate(BaseModel):
    status: str  # approved | rejected | pending


class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    email: EmailStr
    password: str | None = Field(None, min_length=6, max_length=128)
    role: str = "Member"
    skill_level: str | None = Field(None, max_length=60)
    status: str | None = Field(None, description="approved | pending | rejected")


class UserUpdate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    email: EmailStr
    role: str = Field(..., description="Admin | Member | Organization")
    skill_level: str | None = Field(None, max_length=60)
    status: str = Field(..., description="approved | pending | rejected")


class PasswordResetResponse(BaseModel):
    message: str
    temporary_password: str
