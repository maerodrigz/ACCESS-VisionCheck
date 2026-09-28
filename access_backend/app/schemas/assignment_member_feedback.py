from datetime import datetime

from pydantic import BaseModel, Field


class MemberRatingItem(BaseModel):
    assignment_id: int
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class MemberRatingsSubmit(BaseModel):
    request_id: int
    ratings: list[MemberRatingItem] = Field(min_length=1)


class AssignmentRatingTargetOut(BaseModel):
    assignment_id: int
    member_id: int
    member_name: str
    task_role: str
    assignment_status: str
    rated: bool
    rating: int | None = None
    comment: str | None = None


class AssignmentMemberFeedbackOut(BaseModel):
    id: int
    request_id: int
    assignment_id: int
    member_id: int
    member_name: str | None = None
    task_role: str | None = None
    requestor_id: int
    requestor_name: str | None = None
    event_title: str | None = None
    rating: int
    comment: str | None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
