"""request_assignments + documentation_requests for members."""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.assignment_constants import (
    ACCEPTED,
    COMPLETED,
    DECLINED,
    DOCUMENTATION_SERVICE_POINTS,
    IN_PROGRESS,
    LEGACY_ASSIGNED,
    PENDING_ACCEPTANCE,
)
from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar
from app.models.request_assignment import RequestAssignment


def list_for_member(db: Session, member_id: int) -> list[RequestAssignment]:
    return list(
        db.scalars(
            select(RequestAssignment)
            .options(
                joinedload(RequestAssignment.request),
                joinedload(RequestAssignment.member),
            )
            .where(RequestAssignment.member_id == member_id)
            .order_by(RequestAssignment.assigned_at.desc(), RequestAssignment.id.desc())
        )
    )


def list_for_request(db: Session, request_id: int) -> list[RequestAssignment]:
    return list(
        db.scalars(
            select(RequestAssignment)
            .options(
                joinedload(RequestAssignment.member),
                joinedload(RequestAssignment.replaces),
            )
            .where(RequestAssignment.request_id == request_id)
            .order_by(RequestAssignment.assigned_at.asc(), RequestAssignment.id.asc())
        )
    )


def request_team_fully_accepted(db: Session, request_id: int) -> bool:
    """True when every non-declined assignment for the request is accepted."""
    rows = list_for_request(db, request_id)
    active = [r for r in rows if r.status != DECLINED]
    if not active:
        return False
    return all(r.status in (ACCEPTED, IN_PROGRESS, COMPLETED, LEGACY_ASSIGNED) for r in active)


def get(db: Session, assignment_id: int) -> RequestAssignment | None:
    return db.scalar(
        select(RequestAssignment)
        .options(
            joinedload(RequestAssignment.request),
            joinedload(RequestAssignment.member),
        )
        .where(RequestAssignment.id == assignment_id)
    )


def get_for_request_member(
    db: Session, request_id: int, member_id: int
) -> RequestAssignment | None:
    return db.scalar(
        select(RequestAssignment).where(
            RequestAssignment.request_id == request_id,
            RequestAssignment.member_id == member_id,
        )
    )


def get_event_for_request(db: Session, request_id: int) -> EventCalendar | None:
    from app.crud import event_calendar as event_cal_crud

    return event_cal_crud.get_event_for_request(db, request_id)


def _sync_calendar_team(db: Session, request: DocumentationRequest) -> EventCalendar:
    from app.crud import event_calendar as event_cal_crud

    event = event_cal_crud.sync_calendar_from_request(db, request)
    assert event is not None
    db.commit()
    db.refresh(event)
    return event


def create_assignment(
    db: Session,
    *,
    request: DocumentationRequest,
    member_id: int,
    assigned_by: int,
    task_role: str,
    admin_notes: str | None = None,
    replaces_assignment_id: int | None = None,
) -> tuple[RequestAssignment, EventCalendar]:
    """Admin assigns member — awaits accept/decline (pending_acceptance)."""
    existing = get_for_request_member(db, request.id, member_id)
    if existing:
        if existing.status == DECLINED:
            raise ValueError(
                "This member previously declined this request. Choose a different member."
            )
        existing.task_role = task_role.strip().lower()
        existing.status = PENDING_ACCEPTANCE
        existing.decline_reason = None
        existing.decline_reason_code = None
        existing.replaces_assignment_id = replaces_assignment_id
        existing.responded_at = None
        existing.assigned_at = datetime.now(timezone.utc)
        assignment = existing
    else:
        assignment = RequestAssignment(
            request_id=request.id,
            member_id=member_id,
            assigned_by=assigned_by,
            task_role=task_role.strip().lower(),
            status=PENDING_ACCEPTANCE,
            replaces_assignment_id=replaces_assignment_id,
        )
        db.add(assignment)
    db.flush()

    from app.crud import event_calendar as event_cal_crud

    event = event_cal_crud.sync_calendar_from_request(db, request)
    if event is not None and admin_notes:
        event.admin_remarks = admin_notes

    db.commit()
    db.refresh(assignment)
    if event is not None:
        db.refresh(event)
    else:
        event = get_event_for_request(db, request.id)
    assert event is not None
    return assignment, event


def accept_assignment(db: Session, assignment: RequestAssignment) -> RequestAssignment:
    if assignment.status not in (PENDING_ACCEPTANCE, LEGACY_ASSIGNED):
        raise ValueError("Assignment is not awaiting member response.")
    assignment.status = ACCEPTED
    assignment.responded_at = datetime.now(timezone.utc)
    db.commit()
    if assignment.request:
        _sync_calendar_team(db, assignment.request)
    db.refresh(assignment)
    return assignment


def decline_assignment(
    db: Session,
    assignment: RequestAssignment,
    *,
    reason_code: str,
    reason_text: str | None = None,
) -> RequestAssignment:
    if assignment.status not in (PENDING_ACCEPTANCE, LEGACY_ASSIGNED):
        raise ValueError("Assignment is not awaiting member response.")
    assignment.status = DECLINED
    assignment.decline_reason_code = reason_code.strip().lower()
    assignment.decline_reason = (reason_text or reason_code).strip()
    assignment.responded_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(assignment)
    return assignment


def complete_assignment(
    db: Session,
    assignment: RequestAssignment,
    *,
    service_points: int = DOCUMENTATION_SERVICE_POINTS,
) -> RequestAssignment:
    """Legacy — member completion workflow removed. No points are awarded."""
    raise ValueError("Assignment completion is no longer supported.")


def update_status(db: Session, assignment: RequestAssignment, status: str) -> RequestAssignment:
    """Legacy/free-form status patch — prefer accept/decline helpers."""
    normalized = status.strip().lower()
    if normalized in ("completed", "done"):
        raise ValueError("Assignment completion is no longer supported.")
    if normalized == ACCEPTED:
        return accept_assignment(db, assignment)
    assignment.status = normalized
    db.commit()
    db.refresh(assignment)
    return assignment


def assignment_to_json(row: RequestAssignment) -> dict:
    req = row.request
    member = row.member
    replaced = row.replaces
    return {
        "id": row.id,
        "request_id": row.request_id,
        "member_id": row.member_id,
        "member_name": member.fullname if member else "Unknown",
        "task_role": row.task_role,
        "status": row.status,
        "decline_reason": row.decline_reason,
        "decline_reason_code": row.decline_reason_code,
        "replaces_assignment_id": row.replaces_assignment_id,
        "replaced_member_name": replaced.member.fullname if replaced and replaced.member else None,
        "service_points_awarded": row.service_points_awarded,
        "assigned_at": row.assigned_at.isoformat() if row.assigned_at else None,
        "responded_at": row.responded_at.isoformat() if row.responded_at else None,
        "completed_at": row.completed_at.isoformat() if row.completed_at else None,
        "request_title": req.title if req else "",
        "event_date": req.event_date.isoformat() if req and req.event_date else None,
        "venue": req.venue if req else None,
        "start_time": req.start_time if req else None,
        "end_time": req.end_time if req else None,
    }
