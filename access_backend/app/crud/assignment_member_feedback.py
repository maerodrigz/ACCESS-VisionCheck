"""CRUD for requestor ratings of assigned photographers/videographers."""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.models.assignment_constants import (
    ACCEPTED,
    COMPLETED,
    IN_PROGRESS,
    LEGACY_ASSIGNED,
)
from app.models.assignment_member_feedback import AssignmentMemberFeedback
from app.models.request_assignment import RequestAssignment

RATEABLE_ASSIGNMENT_STATUSES = (ACCEPTED, IN_PROGRESS, COMPLETED, LEGACY_ASSIGNED)


def list_rateable_assignments(db: Session, request_id: int) -> list[RequestAssignment]:
    return list(
        db.scalars(
            select(RequestAssignment)
            .options(joinedload(RequestAssignment.member))
            .where(
                RequestAssignment.request_id == request_id,
                RequestAssignment.status.in_(RATEABLE_ASSIGNMENT_STATUSES),
            )
            .order_by(RequestAssignment.assigned_at.asc(), RequestAssignment.id.asc())
        )
    )


def list_for_request_requestor(
    db: Session, *, request_id: int, requestor_id: int
) -> list[AssignmentMemberFeedback]:
    return list(
        db.scalars(
            select(AssignmentMemberFeedback)
            .options(
                joinedload(AssignmentMemberFeedback.member),
                joinedload(AssignmentMemberFeedback.assignment),
            )
            .where(
                AssignmentMemberFeedback.request_id == request_id,
                AssignmentMemberFeedback.requestor_id == requestor_id,
            )
            .order_by(AssignmentMemberFeedback.created_at.desc())
        )
    )


def get_for_assignment_requestor(
    db: Session, *, assignment_id: int, requestor_id: int
) -> AssignmentMemberFeedback | None:
    return db.scalar(
        select(AssignmentMemberFeedback).where(
            AssignmentMemberFeedback.assignment_id == assignment_id,
            AssignmentMemberFeedback.requestor_id == requestor_id,
        )
    )


def list_for_member(db: Session, member_id: int, *, limit: int = 20) -> list[AssignmentMemberFeedback]:
    return list(
        db.scalars(
            select(AssignmentMemberFeedback)
            .options(
                joinedload(AssignmentMemberFeedback.request),
                joinedload(AssignmentMemberFeedback.requestor),
                joinedload(AssignmentMemberFeedback.assignment),
            )
            .where(AssignmentMemberFeedback.member_id == member_id)
            .order_by(AssignmentMemberFeedback.created_at.desc())
            .limit(limit)
        )
    )


def member_rating_summary(db: Session, member_id: int) -> dict:
    row = db.execute(
        select(
            func.count(AssignmentMemberFeedback.id),
            func.avg(AssignmentMemberFeedback.rating),
        ).where(AssignmentMemberFeedback.member_id == member_id)
    ).one()
    count = int(row[0] or 0)
    avg = float(row[1]) if row[1] is not None else None
    return {"count": count, "average_rating": avg}


def summaries_for_members(db: Session, member_ids: list[int]) -> dict[int, dict]:
    if not member_ids:
        return {}
    rows = db.execute(
        select(
            AssignmentMemberFeedback.member_id,
            func.count(AssignmentMemberFeedback.id),
            func.avg(AssignmentMemberFeedback.rating),
        )
        .where(AssignmentMemberFeedback.member_id.in_(member_ids))
        .group_by(AssignmentMemberFeedback.member_id)
    ).all()
    out: dict[int, dict] = {}
    for member_id, count, avg in rows:
        out[int(member_id)] = {
            "count": int(count or 0),
            "average_rating": float(avg) if avg is not None else None,
        }
    return out


def upsert(
    db: Session,
    *,
    request_id: int,
    assignment_id: int,
    member_id: int,
    requestor_id: int,
    rating: int,
    comment: str | None,
) -> AssignmentMemberFeedback:
    row = get_for_assignment_requestor(db, assignment_id=assignment_id, requestor_id=requestor_id)
    if row:
        row.rating = rating
        row.comment = comment.strip() if comment and comment.strip() else None
    else:
        row = AssignmentMemberFeedback(
            request_id=request_id,
            assignment_id=assignment_id,
            member_id=member_id,
            requestor_id=requestor_id,
            rating=rating,
            comment=comment.strip() if comment and comment.strip() else None,
        )
        db.add(row)
    db.commit()
    db.refresh(row)
    return row
