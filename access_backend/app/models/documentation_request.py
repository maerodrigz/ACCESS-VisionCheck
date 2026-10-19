"""Event documentation requests submitted by organizations or members."""

import json
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class DocumentationRequest(TimestampMixin, Base):
    __tablename__ = "documentation_requests"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    requestor_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    event_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    venue: Mapped[str | None] = mapped_column(String(200))
    start_time: Mapped[str | None] = mapped_column(String(20))
    end_time: Mapped[str | None] = mapped_column(String(20))
    requirements: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    original_event_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    last_rescheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reschedule_history: Mapped[str | None] = mapped_column(Text)
    gallery_first_upload_notified: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    gallery_upload_notify_pending: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    gallery_upload_last_notify_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    archived_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    def reschedule_history_list(self) -> list[dict]:
        if not self.reschedule_history:
            return []
        try:
            data = json.loads(self.reschedule_history)
            return data if isinstance(data, list) else []
        except json.JSONDecodeError:
            return []

    requestor = relationship("User", back_populates="documentation_requests", foreign_keys=[requestor_id])
    assignments = relationship(
        "RequestAssignment", back_populates="request", cascade="all, delete-orphan"
    )
    calendar_events = relationship(
        "EventCalendar", back_populates="request", cascade="all, delete-orphan"
    )
    media_files = relationship("MediaFile", back_populates="request", cascade="all, delete-orphan")
    feedbacks = relationship("Feedback", back_populates="request", cascade="all, delete-orphan")
