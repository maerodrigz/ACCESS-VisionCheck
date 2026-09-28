from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.api.deps import require_admin, require_organization
from app.crud import assignment as assignment_crud
from app.crud import assignment_member_feedback as member_rating_crud
from app.crud import documentation_request as req_crud
from app.crud import feedback as feedback_crud
from app.database import get_db
from app.models.user import User
from app.schemas.assignment_member_feedback import (
    AssignmentMemberFeedbackOut,
    AssignmentRatingTargetOut,
    MemberRatingsSubmit,
)
from app.schemas.member_api import FeedbackCreate, FeedbackOut

router = APIRouter(prefix="/feedback", tags=["Feedback"])


def _assert_requestor_owns_request(row, user: User) -> None:
    if row.requestor_id != user.id:
        raise HTTPException(status_code=403, detail="Not allowed to access this request")


def _feedback_to_out(row) -> AssignmentMemberFeedbackOut:
    member = row.member
    assignment = row.assignment
    request = row.request
    requestor = row.requestor
    return AssignmentMemberFeedbackOut(
        id=row.id,
        request_id=row.request_id,
        assignment_id=row.assignment_id,
        member_id=row.member_id,
        member_name=member.fullname if member else None,
        task_role=assignment.task_role if assignment else None,
        requestor_id=row.requestor_id,
        requestor_name=requestor.fullname if requestor else None,
        event_title=request.title if request else None,
        rating=row.rating,
        comment=row.comment,
        created_at=row.created_at,
    )


@router.get("", response_model=list[FeedbackOut])
def list_feedback(
    request_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_organization),
):
    return feedback_crud.list_feedbacks(db, user_id=current_user.id, request_id=request_id)


@router.post("", response_model=FeedbackOut)
def submit_feedback(
    body: FeedbackCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_organization),
):
    doc = req_crud.get(db, body.request_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Request not found")
    _assert_requestor_owns_request(doc, current_user)

    row = feedback_crud.create(
        db,
        {
            "request_id": body.request_id,
            "user_id": current_user.id,
            "rating": body.rating,
            "comment": body.comment,
        },
    )
    from app.services import notification_events as notify_events

    event_title = doc.title if doc else f"Request #{body.request_id}"
    notify_events.notify_feedback_submitted(
        db,
        row.id,
        event_title,
        body.rating,
        current_user.fullname or current_user.email,
    )
    return row


@router.get("/member-ratings/assignments", response_model=list[AssignmentRatingTargetOut])
def list_assignment_rating_targets(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_organization),
):
    doc = req_crud.get(db, request_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Request not found")
    _assert_requestor_owns_request(doc, current_user)

    assignments = member_rating_crud.list_rateable_assignments(db, request_id)
    existing = {
        r.assignment_id: r
        for r in member_rating_crud.list_for_request_requestor(
            db, request_id=request_id, requestor_id=current_user.id
        )
    }
    return [
        AssignmentRatingTargetOut(
            assignment_id=a.id,
            member_id=a.member_id,
            member_name=a.member.fullname if a.member else "Unknown",
            task_role=a.task_role,
            assignment_status=a.status,
            rated=a.id in existing,
            rating=existing[a.id].rating if a.id in existing else None,
            comment=existing[a.id].comment if a.id in existing else None,
        )
        for a in assignments
    ]


@router.post("/member-ratings", response_model=list[AssignmentMemberFeedbackOut])
def submit_member_ratings(
    body: MemberRatingsSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_organization),
):
    doc = req_crud.get(db, body.request_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Request not found")
    _assert_requestor_owns_request(doc, current_user)

    rateable = member_rating_crud.list_rateable_assignments(db, body.request_id)
    rateable_ids = {a.id: a for a in rateable}
    if not rateable_ids:
        raise HTTPException(status_code=400, detail="No assigned team members to rate for this event")

    submitted_ids = {item.assignment_id for item in body.ratings}
    missing = set(rateable_ids.keys()) - submitted_ids
    if missing:
        raise HTTPException(
            status_code=400,
            detail="Please rate every assigned photographer and videographer for this event",
        )

    saved: list[AssignmentMemberFeedbackOut] = []
    for item in body.ratings:
        assignment = rateable_ids.get(item.assignment_id)
        if not assignment:
            assignment = assignment_crud.get(db, item.assignment_id)
        if not assignment or assignment.request_id != body.request_id:
            raise HTTPException(status_code=400, detail=f"Invalid assignment #{item.assignment_id}")
        row = member_rating_crud.upsert(
            db,
            request_id=body.request_id,
            assignment_id=assignment.id,
            member_id=assignment.member_id,
            requestor_id=current_user.id,
            rating=item.rating,
            comment=item.comment,
        )
        row.member = assignment.member
        row.assignment = assignment
        row.request = doc
        row.requestor = current_user
        saved.append(_feedback_to_out(row))
    return saved


@router.get("/member-ratings", response_model=list[AssignmentMemberFeedbackOut])
def list_member_ratings(
    request_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_organization),
):
    from sqlalchemy import select

    from app.models.assignment_member_feedback import AssignmentMemberFeedback

    q = (
        select(AssignmentMemberFeedback)
        .options(
            joinedload(AssignmentMemberFeedback.member),
            joinedload(AssignmentMemberFeedback.requestor),
            joinedload(AssignmentMemberFeedback.request),
            joinedload(AssignmentMemberFeedback.assignment),
        )
        .where(AssignmentMemberFeedback.requestor_id == current_user.id)
    )
    if request_id is not None:
        doc = req_crud.get(db, request_id)
        if not doc:
            raise HTTPException(status_code=404, detail="Request not found")
        _assert_requestor_owns_request(doc, current_user)
        q = q.where(AssignmentMemberFeedback.request_id == request_id)
    q = q.order_by(AssignmentMemberFeedback.created_at.desc())
    rows = list(db.scalars(q))
    return [_feedback_to_out(r) for r in rows]
