from datetime import datetime

from pydantic import BaseModel, Field


class MemberRegistrationOut(BaseModel):
    user_id: int
    full_name: str
    student_id: str | None = None
    email: str
    contact_number: str | None = None
    skill_level: str | None = None
    status: str
    rejection_reason: str | None = None
    date_registered: datetime | None = None

    model_config = {"from_attributes": True}


class OrganizationRegistrationOut(BaseModel):
    user_id: int
    organization_name: str
    organization_email: str
    requestor_type: str | None = None
    adviser_name: str | None = None
    contact_number: str | None = None
    status: str
    rejection_reason: str | None = None
    date_registered: datetime | None = None

    model_config = {"from_attributes": True}


class RegistrationRejectBody(BaseModel):
    rejection_reason: str = Field(..., min_length=3, max_length=500)
