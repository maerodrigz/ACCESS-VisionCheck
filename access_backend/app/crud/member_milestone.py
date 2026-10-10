"""Member milestone persistence."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.member_milestone import MemberMilestone


def get_by_kind_key(
    db: Session, user_id: int, *, milestone_kind: str, milestone_key: str
) -> MemberMilestone | None:
    return db.scalar(
        select(MemberMilestone).where(
            MemberMilestone.user_id == user_id,
            MemberMilestone.milestone_kind == milestone_kind,
            MemberMilestone.milestone_key == milestone_key,
        )
    )


def list_for_user(
    db: Session,
    user_id: int,
    *,
    unacknowledged_only: bool = False,
    limit: int = 50,
) -> list[MemberMilestone]:
    q = select(MemberMilestone).where(MemberMilestone.user_id == user_id)
    if unacknowledged_only:
        q = q.where(MemberMilestone.acknowledged_at.is_(None))
    q = q.order_by(MemberMilestone.created_at.desc()).limit(max(1, min(limit, 100)))
    return list(db.scalars(q).all())


def acknowledge(db: Session, user_id: int, milestone_id: int) -> MemberMilestone | None:
    row = db.scalar(
        select(MemberMilestone).where(
            MemberMilestone.id == milestone_id,
            MemberMilestone.user_id == user_id,
        )
    )
    if row is None:
        return None
    if row.acknowledged_at is None:
        row.acknowledged_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(row)
    return row


def create_if_new(
    db: Session,
    user_id: int,
    *,
    milestone_kind: str,
    milestone_key: str,
    title: str,
    message: str,
) -> MemberMilestone | None:
    existing = get_by_kind_key(
        db, user_id, milestone_kind=milestone_kind, milestone_key=milestone_key
    )
    if existing is not None:
        return None
    row = MemberMilestone(
        user_id=user_id,
        milestone_kind=milestone_kind,
        milestone_key=milestone_key,
        title=title.strip()[:200],
        message=message.strip(),
    )
    db.add(row)
    db.flush()
    return row
