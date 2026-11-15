"""Persisted, non-secret Facebook Page token verification metadata (singleton row)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

# connection_status values
STATUS_CONNECTED = "connected"
STATUS_NEEDS_ATTENTION = "needs_attention"
STATUS_DISCONNECTED = "disconnected"
STATUS_UNKNOWN = "unknown"

# expiry_visibility values — never claim "never" without Meta confirmation
EXPIRY_UNKNOWN = "unknown"
EXPIRY_NEVER = "never"
EXPIRY_DATED = "dated"

HEALTH_ROW_ID = 1


class FacebookPageTokenHealth(Base):
    __tablename__ = "facebook_page_token_health"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    connection_status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=STATUS_UNKNOWN
    )
    page_id: Mapped[str | None] = mapped_column(String(64))
    page_name: Mapped[str | None] = mapped_column(String(255))
    last_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_ok: Mapped[bool | None] = mapped_column(Boolean)
    last_error: Mapped[str | None] = mapped_column(Text)
    token_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expiry_visibility: Mapped[str] = mapped_column(
        String(16), nullable=False, default=EXPIRY_UNKNOWN
    )
    album_id: Mapped[str | None] = mapped_column(String(64))
    album_name: Mapped[str | None] = mapped_column(String(255))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
