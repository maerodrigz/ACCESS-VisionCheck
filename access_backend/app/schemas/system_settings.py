"""Schemas for system configuration API."""

from pydantic import BaseModel, Field, field_validator

from app.services.media_upload_config import normalize_extensions_csv


class GeneralSettingsBody(BaseModel):
    app_name: str = Field(min_length=1, max_length=120)
    organization: str = Field(min_length=1, max_length=120)
    system_description: str = Field(min_length=1, max_length=255)


class NotificationSettingsBody(BaseModel):
    notify_new_documentation_request: bool | None = None
    notify_request_approved: bool | None = None
    notify_request_completed: bool | None = None
    notify_request_gallery_uploads: bool | None = None
    notify_request_rejected: bool | None = None
    notify_new_documentation_assignment: bool | None = None
    notify_evaluation_completed: bool | None = None
    notify_new_announcement: bool | None = None
    notify_system_alerts: bool | None = None


class AiEvaluationSettingsBody(BaseModel):
    enabled: bool | None = None


class MediaSettingsBody(BaseModel):
    event_max_upload_mb: int | None = Field(None, ge=1, le=500)
    evaluation_max_upload_mb: int | None = Field(None, ge=1, le=500)
    max_evaluation_uploads_per_day: int | None = Field(None, ge=1, le=100)
    event_allowed_image_formats: str | None = Field(None, max_length=255)
    event_allowed_video_formats: str | None = Field(None, max_length=255)
    evaluation_allowed_image_formats: str | None = Field(None, max_length=255)
    evaluation_allowed_video_formats: str | None = Field(None, max_length=255)
    allow_late_media_uploads: bool | None = None
    max_upload_period_days: int | None = Field(None, ge=1, le=90)
    require_event_album_before_upload: bool | None = None
    enable_facebook_publishing: bool | None = None

    @field_validator(
        "event_allowed_image_formats",
        "event_allowed_video_formats",
        "evaluation_allowed_image_formats",
        "evaluation_allowed_video_formats",
        mode="before",
    )
    @classmethod
    def validate_extensions(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return normalize_extensions_csv(str(value))


class SecuritySettingsBody(BaseModel):
    min_password_length: int | None = Field(None, ge=6, le=32)
    session_timeout_minutes: int | None = Field(None, ge=5, le=480)
    max_login_attempts: int | None = Field(None, ge=3, le=20)
    account_lockout_minutes: int | None = Field(None, ge=5, le=1440)
    two_factor_enabled: bool | None = None
