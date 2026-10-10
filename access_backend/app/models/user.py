"""System accounts — shared login for Admin Web (Chrome) and Mobile (Android)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    fullname: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    # Stores bcrypt hash; never store plain text
    password: Mapped[str] = mapped_column(String(255), nullable=False)
    role_id: Mapped[int] = mapped_column(ForeignKey("roles.id", ondelete="RESTRICT"), nullable=False, index=True)
    profile_image: Mapped[str | None] = mapped_column(String(500))
    skill_level_id: Mapped[int | None] = mapped_column(
        ForeignKey("skill_levels.id", ondelete="SET NULL"), index=True
    )
    # pending | approved | rejected — used by login and admin approval
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="approved", index=True)
    student_id: Mapped[str | None] = mapped_column(String(40), index=True)
    contact_number: Mapped[str | None] = mapped_column(String(40))
    adviser_name: Mapped[str | None] = mapped_column(String(120))
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    approved_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    failed_login_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    removed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    removed_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    removal_reason: Mapped[str | None] = mapped_column(Text)

    role = relationship("Role", back_populates="users", lazy="joined")
    skill_level = relationship("SkillLevel", back_populates="users")

    documentation_requests = relationship(
        "DocumentationRequest",
        back_populates="requestor",
        foreign_keys="DocumentationRequest.requestor_id",
    )
    request_assignments_as_member = relationship(
        "RequestAssignment",
        back_populates="member",
        foreign_keys="RequestAssignment.member_id",
    )
    request_assignments_assigned = relationship(
        "RequestAssignment",
        back_populates="assigner",
        foreign_keys="RequestAssignment.assigned_by",
    )
    uploaded_media = relationship("MediaFile", back_populates="uploader")
    feedbacks = relationship("Feedback", back_populates="user")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    member_ranking = relationship(
        "MemberRanking", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    audit_logs = relationship("AuditLog", back_populates="user")
    login_history = relationship("LoginHistory", back_populates="user", cascade="all, delete-orphan")
    user_sessions = relationship("UserSession", back_populates="user", cascade="all, delete-orphan")
    media_comments = relationship("MediaComment", back_populates="user")
    announcements = relationship("Announcement", back_populates="poster")
    archives_created = relationship("Archive", back_populates="archiver")
    notification_preferences = relationship(
        "MemberNotificationPreference",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    push_device_tokens = relationship(
        "PushDeviceToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    # Compatibility with JWT payloads and Flutter API (legacy field names)
    @property
    def user_id(self) -> int:
        return self.id

    @property
    def name(self) -> str:
        return self.fullname
