"""Photos and videos uploaded for a documentation request."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.media_constants import (
    APPROVAL_NOT_APPLICABLE,
    FB_NOT_PUBLISHED,
    MEDIA_CATEGORY_EVALUATION,
)


class MediaFile(Base):
    __tablename__ = "media_files"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    uploaded_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    request_id: Mapped[int | None] = mapped_column(
        ForeignKey("documentation_requests.id", ondelete="SET NULL"), nullable=True, index=True
    )
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    file_url: Mapped[str] = mapped_column(Text, nullable=False)
    # SHA-256 hex of upload bytes; member_evaluation only. Legacy rows may be NULL.
    file_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    # Workflow: event_documentation (linked to events) vs member_evaluation (practice uploads)
    media_category: Mapped[str] = mapped_column(
        String(30), nullable=False, default=MEDIA_CATEGORY_EVALUATION, index=True
    )
    approval_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=APPROVAL_NOT_APPLICABLE, index=True
    )
    approval_rejection_reason: Mapped[str | None] = mapped_column(Text)
    facebook_publish_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=FB_NOT_PUBLISHED, index=True
    )
    facebook_post_id: Mapped[str | None] = mapped_column(String(100))
    facebook_published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_best_shot: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    album_name_override: Mapped[str | None] = mapped_column(String(255))
    # Member removed blob from storage; evaluation + scores kept for averages and XP.
    storage_removed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Linked replacement workflow (Phase 1: schema + read-only metadata).
    submission_chain_id: Mapped[int | None] = mapped_column(
        ForeignKey(
            "submission_chains.id",
            ondelete="SET NULL",
            name="fk_media_files_submission_chain_id",
            use_alter=True,
        ),
        nullable=True,
        index=True,
    )
    replaces_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media_files.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    replacement_lifecycle: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)

    uploader = relationship("User", back_populates="uploaded_media")
    request = relationship("DocumentationRequest", back_populates="media_files")
    evaluations = relationship(
        "MediaEvaluation", back_populates="media", cascade="all, delete-orphan"
    )
    ai_detection_results = relationship(
        "AiDetectionResult", back_populates="media", cascade="all, delete-orphan"
    )
    comments = relationship("MediaComment", back_populates="media", cascade="all, delete-orphan")
    archives = relationship("Archive", back_populates="media", cascade="all, delete-orphan")
    facebook_posts = relationship("FacebookPost", back_populates="media", cascade="all, delete-orphan")
    submission_chain_as_root = relationship(
        "SubmissionChain",
        back_populates="root_media",
        foreign_keys="SubmissionChain.root_media_id",
        uselist=False,
    )
    submission_chain = relationship(
        "SubmissionChain",
        foreign_keys=[submission_chain_id],
        primaryjoin="MediaFile.submission_chain_id == SubmissionChain.id",
    )
    replaces_media = relationship(
        "MediaFile",
        remote_side=[id],
        foreign_keys=[replaces_media_id],
    )
