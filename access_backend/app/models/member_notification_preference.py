"""Per-member in-app notification category preferences."""

from sqlalchemy import Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class MemberNotificationPreference(TimestampMixin, Base):
    __tablename__ = "member_notification_preferences"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    evaluation_feedback: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    event_calendar: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    system_announcements: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    user = relationship("User", back_populates="notification_preferences")
