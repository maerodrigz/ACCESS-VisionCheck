from datetime import datetime

from pydantic import BaseModel, Field


class AdminMemberResponse(BaseModel):
    user_id: int
    name: str
    email: str
    role: str
    status: str
    is_active: bool = True
    removed_at: datetime | None = None
    removed_by: int | None = None
    removed_by_name: str | None = None
    student_id: str | None = None
    contact_number: str | None = None
    adviser_name: str | None = None
    rejection_reason: str | None = None
    approved_at: datetime | None = None
    skill_level: str | None = None
    assigned_tasks: int = 0
    completed_tasks: int = 0
    media_eval_score: float = 0.0
    last_active: datetime | None = None
    primary_task_role: str | None = None
    profile_image: str | None = None
    good_evaluations: int = 0
    avg_score: float = 0.0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class UserRoleUpdate(BaseModel):
    role: str = Field(..., description="Admin | Member | Organization")


class UserStatusUpdate(BaseModel):
    status: str
    rejection_reason: str | None = Field(None, max_length=500)
    delete_uploads: bool = Field(
        default=False,
        description="When deactivating a Member or Organization, delete their uploaded media files.",
    )


class UserStatusUpdateResponse(BaseModel):
    message: str
    media_deleted: int = 0
    media_delete_failed: int = 0


class MemberRemoveBody(BaseModel):
    removal_reason: str | None = Field(None, max_length=500)


class MemberDeleteBody(BaseModel):
    """Permanent delete — requires typing the account email (Member or Organization)."""

    confirmation_email: str = Field(..., min_length=3, max_length=255)
    delete_uploads: bool = Field(
        default=False,
        description="Also delete photos/videos uploaded by this user.",
    )


class ProfileActivityItem(BaseModel):
    kind: str
    label: str
    detail: str | None = None
    occurred_at: datetime | None = None


class AdminUserProfileResponse(AdminMemberResponse):
    recent_activity: list[ProfileActivityItem] = Field(default_factory=list)
