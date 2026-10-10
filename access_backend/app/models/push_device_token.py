"""FCM device tokens for member and requestor mobile push."""

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class PushDeviceToken(TimestampMixin, Base):
    __tablename__ = "push_device_tokens"
    __table_args__ = (UniqueConstraint("token", name="uq_push_device_tokens_token"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False, default="android")

    user = relationship("User", back_populates="push_device_tokens")
