"""Leaderboard points and rank per member."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class MemberRanking(Base):
    __tablename__ = "member_rankings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True
    )
    total_points: Mapped[int] = mapped_column(Integer, nullable=False, default=0, index=True)
    rank_position: Mapped[int | None] = mapped_column(Integer, index=True)
    admin_remarks: Mapped[str | None] = mapped_column(Text)
    competency_level_override: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user = relationship("User", back_populates="member_ranking")
