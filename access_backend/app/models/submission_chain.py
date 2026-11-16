"""Practice evaluation submission chains (original + linked replacements)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin
from app.models.submission_chain_constants import XP_RECONCILIATION_PENDING


class SubmissionChain(TimestampMixin, Base):
    __tablename__ = "submission_chains"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    root_media_id: Mapped[int] = mapped_column(
        ForeignKey("media_files.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
        index=True,
    )
    member_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    active_replacement_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
    )
    awaiting_replacement_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
    )
    xp_awarded_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    xp_award_locked: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    xp_awarded_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
    )
    xp_awarded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    chain_resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    xp_reconciliation_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default=XP_RECONCILIATION_PENDING,
        server_default=XP_RECONCILIATION_PENDING,
        index=True,
    )

    root_media = relationship(
        "MediaFile",
        foreign_keys=[root_media_id],
        back_populates="submission_chain_as_root",
    )
    member = relationship("User", foreign_keys=[member_id])
    active_replacement = relationship(
        "MediaFile",
        foreign_keys=[active_replacement_media_id],
    )
    awaiting_replacement = relationship(
        "MediaFile",
        foreign_keys=[awaiting_replacement_media_id],
    )
    events = relationship(
        "SubmissionChainEvent",
        back_populates="chain",
        cascade="all, delete-orphan",
        order_by="SubmissionChainEvent.created_at.desc()",
    )
