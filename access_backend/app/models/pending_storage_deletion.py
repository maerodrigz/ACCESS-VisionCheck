"""Durable queue when Supabase/local blob delete fails during account or media removal."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PendingStorageDeletion(Base):
    __tablename__ = "pending_storage_deletions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    owner_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    file_url: Mapped[str] = mapped_column(Text, nullable=False)
    bucket: Mapped[str | None] = mapped_column(String(120))
    object_path: Mapped[str | None] = mapped_column(Text)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
