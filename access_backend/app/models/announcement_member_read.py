"""Per-member announcement read / expiry timeline."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AnnouncementMemberRead(Base):
    """Tracks when a member first opened an announcement detail.

    ``expires_at`` is stamped once as first_read_at + 24h and never reset.
    The original ``announcements`` row is never deleted by this lifecycle.
    """

    __tablename__ = "announcement_member_reads"
    __table_args__ = (
        UniqueConstraint(
            "announcement_id",
            "user_id",
            name="uq_announcement_member_reads_announcement_user",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    announcement_id: Mapped[int] = mapped_column(
        ForeignKey("announcements.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    first_read_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )

    announcement = relationship("Announcement", back_populates="member_reads")
    user = relationship("User")
