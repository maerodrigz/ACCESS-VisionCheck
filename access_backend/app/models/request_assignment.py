"""Members assigned to cover a documentation request."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RequestAssignment(Base):
    __tablename__ = "request_assignments"
    __table_args__ = (UniqueConstraint("request_id", "member_id", name="uq_request_member"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("documentation_requests.id", ondelete="CASCADE"), nullable=False, index=True
    )
    member_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    assigned_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    task_role: Mapped[str] = mapped_column(String(50), nullable=False, default="photographer")
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="pending_acceptance", index=True)
    decline_reason: Mapped[str | None] = mapped_column(Text)
    decline_reason_code: Mapped[str | None] = mapped_column(String(40))
    replaces_assignment_id: Mapped[int | None] = mapped_column(
        ForeignKey("request_assignments.id", ondelete="SET NULL"), nullable=True, index=True
    )
    service_points_awarded: Mapped[int | None] = mapped_column(Integer)
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    request = relationship("DocumentationRequest", back_populates="assignments")
    member = relationship("User", back_populates="request_assignments_as_member", foreign_keys=[member_id])
    assigner = relationship("User", back_populates="request_assignments_assigned", foreign_keys=[assigned_by])
    replaces = relationship("RequestAssignment", remote_side=[id], foreign_keys=[replaces_assignment_id])
    member_feedbacks = relationship(
        "AssignmentMemberFeedback",
        back_populates="assignment",
        cascade="all, delete-orphan",
    )
