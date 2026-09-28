"""Requestor ratings for photographers/videographers on a documentation assignment."""

from sqlalchemy import ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class AssignmentMemberFeedback(TimestampMixin, Base):
    __tablename__ = "assignment_member_feedbacks"
    __table_args__ = (
        UniqueConstraint("assignment_id", "requestor_id", name="uq_assignment_member_feedback"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("documentation_requests.id", ondelete="CASCADE"), nullable=False, index=True
    )
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("request_assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    member_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    requestor_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text)

    request = relationship("DocumentationRequest")
    assignment = relationship("RequestAssignment", back_populates="member_feedbacks")
    member = relationship("User", foreign_keys=[member_id])
    requestor = relationship("User", foreign_keys=[requestor_id])
