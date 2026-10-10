"""Recorded member milestones (skill tier, evaluation gates, titles)."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class MemberMilestone(TimestampMixin, Base):
    __tablename__ = "member_milestones"
    __table_args__ = (
        UniqueConstraint("user_id", "milestone_kind", "milestone_key", name="uq_member_milestone"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    milestone_kind: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    milestone_key: Mapped[str] = mapped_column(String(80), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user = relationship("User", back_populates="member_milestones")
