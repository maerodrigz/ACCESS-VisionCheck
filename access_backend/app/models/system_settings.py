"""System-wide configuration (single row, id=1)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

SETTINGS_ROW_ID = 1

DEFAULT_ORGANIZATION_EMAIL = "access@university.edu.ph"
DEFAULT_ACADEMIC_YEAR = "2025–2026"


class SystemSettings(Base):
    """Persisted platform settings for admin System Configuration."""

    __tablename__ = "system_settings"

    id: Mapped[int] = mapped_column(primary_key=True, default=SETTINGS_ROW_ID)

    organization_email: Mapped[str | None] = mapped_column(String(255))
    academic_year: Mapped[str | None] = mapped_column(String(32))

    allow_late_media_uploads: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    max_upload_period_days: Mapped[int] = mapped_column(Integer, default=7, nullable=False)
    require_event_album_before_upload: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    enable_facebook_publishing: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    enable_ai_detection: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    ai_confidence_threshold: Mapped[float] = mapped_column(Float, default=0.75, nullable=False)
    auto_generate_review_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    require_manual_verification_before_warning: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )

    enable_ai_media_evaluation: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    max_evaluation_uploads_per_day: Mapped[int] = mapped_column(Integer, default=5, nullable=False)

    event_max_upload_mb: Mapped[int | None] = mapped_column(Integer)
    evaluation_max_upload_mb: Mapped[int | None] = mapped_column(Integer)
    event_allowed_image_formats: Mapped[str | None] = mapped_column(String(255))
    event_allowed_video_formats: Mapped[str | None] = mapped_column(String(255))
    evaluation_allowed_image_formats: Mapped[str | None] = mapped_column(String(255))
    evaluation_allowed_video_formats: Mapped[str | None] = mapped_column(String(255))

    notify_new_documentation_request: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_request_approved: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_request_completed: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_request_gallery_uploads: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_request_rejected: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_new_documentation_assignment: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_evaluation_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    notify_new_announcement: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_system_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    min_password_length: Mapped[int] = mapped_column(Integer, default=8, nullable=False)
    session_timeout_minutes: Mapped[int] = mapped_column(Integer, default=60, nullable=False)
    max_login_attempts: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    account_lockout_minutes: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    two_factor_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )

    updater = relationship("User", foreign_keys=[updated_by])
