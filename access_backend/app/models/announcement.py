"""System-wide announcements posted by admins."""

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class Announcement(TimestampMixin, Base):
    __tablename__ = "announcements"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    posted_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    poster = relationship("User", back_populates="announcements")
    member_reads = relationship(
        "AnnouncementMemberRead",
        back_populates="announcement",
        cascade="all, delete-orphan",
    )
