"""Append-only audit events for submission chains (recovery, XP, re-upload)."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SubmissionChainEvent(Base):
    __tablename__ = "submission_chain_events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    chain_id: Mapped[int] = mapped_column(
        ForeignKey("submission_chains.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    payload: Mapped[str | None] = mapped_column(Text)
    actor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    chain = relationship("SubmissionChain", back_populates="events")
    media = relationship("MediaFile", foreign_keys=[media_id])
    actor = relationship("User", foreign_keys=[actor_user_id])
