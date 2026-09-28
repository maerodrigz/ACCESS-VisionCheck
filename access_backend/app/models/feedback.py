"""Ratings and comments after event documentation."""

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin

FEEDBACK_REVIEW_PENDING = "pending"
FEEDBACK_REVIEW_REVIEWED = "reviewed"
FEEDBACK_REVIEW_ARCHIVED = "archived"


class Feedback(TimestampMixin, Base):
    __tablename__ = "feedbacks"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("documentation_requests.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text)
    admin_response: Mapped[str | None] = mapped_column(Text)
    review_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=FEEDBACK_REVIEW_PENDING, index=True
    )

    request = relationship("DocumentationRequest", back_populates="feedbacks")
    user = relationship("User", back_populates="feedbacks")
