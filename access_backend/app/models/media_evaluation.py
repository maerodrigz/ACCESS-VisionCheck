"""Rubric scores and feedback for uploaded media."""

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, Text, func
from sqlalchemy.ext.hybrid import hybrid_property
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class MediaEvaluation(Base):
    __tablename__ = "media_evaluations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    media_id: Mapped[int] = mapped_column(
        ForeignKey("media_files.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sharpness_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    brightness_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    contrast_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    blur_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    noise_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    overall_score: Mapped[float | None] = mapped_column(Float, nullable=True, index=True)
    feedback: Mapped[str | None] = mapped_column(Text)
    criteria_json: Mapped[str | None] = mapped_column(Text)
    quality_level: Mapped[str | None] = mapped_column(String(40))
    recommendation: Mapped[str | None] = mapped_column(String(80))
    evaluated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    media = relationship("MediaFile", back_populates="evaluations")

    @hybrid_property
    def admin_remarks(self) -> str | None:
        """Alias for admin remarks stored in the `feedback` column."""
        return self.feedback

    @admin_remarks.setter
    def admin_remarks(self, value: str | None) -> None:
        self.feedback = value

    @admin_remarks.expression
    @classmethod
    def admin_remarks(cls):
        return cls.feedback
