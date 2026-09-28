"""Organization branding (logo + system display names)."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

# Bundled defaults when admin has not customized names.
DEFAULT_APP_NAME = "ACCESS"
DEFAULT_TAGLINE = "Unified Platform for Coordination and Documentation"
DEFAULT_SHORT_TAGLINE = "Coordination and Documentation Platform"
DEFAULT_ORGANIZATION = "USTP Oroquieta"


class SystemBranding(Base):
    """Single-row branding config (id=1)."""

    __tablename__ = "system_branding"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    logo_path: Mapped[str | None] = mapped_column(String(500))
    app_name: Mapped[str | None] = mapped_column(String(120))
    tagline: Mapped[str | None] = mapped_column(String(255))
    short_tagline: Mapped[str | None] = mapped_column(String(255))
    organization: Mapped[str | None] = mapped_column(String(120))
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )

    updater = relationship("User", foreign_keys=[updated_by])
