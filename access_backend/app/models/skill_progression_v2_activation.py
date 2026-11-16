"""Persisted Skill Progression v2 activation seal and protected cohort membership."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

ACTIVATION_STATUS_DRAFT = "draft"
ACTIVATION_STATUS_SEALED = "sealed"
ACTIVATION_STATUS_REVOKED = "revoked"


class SkillProgressionV2Activation(Base):
    """Operator-controlled v2 activation record (draft → sealed, or revoked)."""

    __tablename__ = "skill_progression_v2_activation"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ACTIVATION_STATUS_DRAFT, index=True
    )
    cohort_member_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    sealed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sealed_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    revoke_reason: Mapped[str | None] = mapped_column(Text)

    cohort_members = relationship(
        "SkillProgressionV2CohortMember",
        back_populates="activation",
        cascade="save-update, merge",
    )


class SkillProgressionV2CohortMember(Base):
    """Authoritative protected grandfather cohort membership for one activation."""

    __tablename__ = "skill_progression_v2_cohort_members"
    __table_args__ = (
        UniqueConstraint(
            "activation_id",
            "user_id",
            name="uq_skill_v2_cohort_activation_user",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    activation_id: Mapped[int] = mapped_column(
        ForeignKey("skill_progression_v2_activation.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    ranking_id: Mapped[int] = mapped_column(
        ForeignKey("member_rankings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Earned v1 tier at capture time (audit). Never override/XP-derived.
    floor_at_capture: Mapped[str] = mapped_column(String(40), nullable=False)
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    captured_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )

    activation = relationship("SkillProgressionV2Activation", back_populates="cohort_members")
