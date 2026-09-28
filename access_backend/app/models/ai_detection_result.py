"""AI authenticity / quality detection output for media."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class AiDetectionResult(TimestampMixin, Base):
    __tablename__ = "ai_detection_results"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    media_id: Mapped[int] = mapped_column(
        ForeignKey("media_files.id", ondelete="CASCADE"), nullable=False, index=True
    )
    ai_probability: Mapped[float] = mapped_column(Float, nullable=False)
    detection_result: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    reviewed_by_admin: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    review_status: Mapped[str] = mapped_column(
        String(40), nullable=False, default="pending_review", index=True
    )
    admin_remarks: Mapped[str | None] = mapped_column(Text)
    detection_remarks: Mapped[str | None] = mapped_column(Text)
    exif_metadata: Mapped[str | None] = mapped_column(Text)
    reviewed_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    media = relationship("MediaFile", back_populates="ai_detection_results")
    reviewer = relationship("User", foreign_keys=[reviewed_by])
    review_history = relationship(
        "AiReviewHistory",
        back_populates="ai_detection",
        order_by="AiReviewHistory.reviewed_at.desc()",
    )

