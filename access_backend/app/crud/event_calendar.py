from datetime import date, datetime, time, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.assignment_constants import (
    ACCEPTED,
    COMPLETED,
    DECLINED,
    IN_PROGRESS,
    LEGACY_ASSIGNED,
    PENDING_ACCEPTANCE,
)
from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar
from app.models.request_assignment import RequestAssignment
from app.models.user import User
from app.utils.timestamps import first_timestamp_iso


def _event_query():
    return select(EventCalendar).options(
        joinedload(EventCalendar.request).joinedload(DocumentationRequest.requestor),
        joinedload(EventCalendar.request)
        .joinedload(DocumentationRequest.assignments)
        .joinedload(RequestAssignment.member),
        joinedload(EventCalendar.assigned_member),
    )


def list_events(db: Session) -> list[EventCalendar]:
    return list(
        db.scalars(
            _event_query().order_by(EventCalendar.start_date.asc(), EventCalendar.start_time.asc())
        ).unique()
    )


def get_event_for_request(db: Session, request_id: int) -> EventCalendar | None:
    return db.scalar(select(EventCalendar).where(EventCalendar.request_id == request_id))


def _apply_request_schedule_to_event(event: EventCalendar, request: DocumentationRequest) -> None:
    event.title = request.title
    event.description = request.description
    event.start_date = request.event_date
    event.venue = request.venue
    event.start_time = parse_time(request.start_time)
    event.end_time = parse_time(request.end_time)


def _event_status_from_assignments(db: Session, request_id: int) -> tuple[int | None, str]:
    """Map assignment rows to calendar assigned_member_id and status string."""
    rows = list(
        db.scalars(select(RequestAssignment).where(RequestAssignment.request_id == request_id))
    )
    priority = (ACCEPTED, IN_PROGRESS, COMPLETED, LEGACY_ASSIGNED, PENDING_ACCEPTANCE)
    for status in priority:
        for row in rows:
            if row.status == status:
                return row.member_id, "assigned"
    return None, "upcoming"


def sync_calendar_from_request(
    db: Session, request: DocumentationRequest
) -> EventCalendar | None:
    """
    Keep a single calendar row in sync with a documentation request lifecycle.
    Idempotent for approved requests (updates existing row, never duplicates).
    """
    if request.id is None:
        return None

    req_status = (request.status or "").strip().lower()
    event = get_event_for_request(db, request.id)

    if req_status == "rejected":
        if event is not None:
            _apply_request_schedule_to_event(event, request)
            event.status = "cancelled"
            db.flush()
        return event

    if req_status not in ("approved", "completed"):
        if event is not None:
            _apply_request_schedule_to_event(event, request)
            event.status = "pending"
            db.flush()
        return event

    if event is None:
        event = EventCalendar(
            request_id=request.id,
            title=request.title,
            description=request.description,
            start_date=request.event_date,
            venue=request.venue,
            status="upcoming",
        )
        db.add(event)

    _apply_request_schedule_to_event(event, request)
    member_id, cal_status = _event_status_from_assignments(db, request.id)
    event.assigned_member_id = member_id
    event.status = cal_status
    db.flush()
    return event


def list_member_events(db: Session) -> list[EventCalendar]:
    """Approved, active campus events (internal building block for scoped lists)."""
    rows = list_events(db)
    approved: list[EventCalendar] = []
    for event in rows:
        req = event.request
        if req is not None and (req.status or "").lower() != "approved":
            continue
        if (event.status or "").lower() in {"cancelled", "canceled"}:
            continue
        approved.append(event)
    return approved


_MEMBER_ASSIGNMENT_STATUSES = (
    PENDING_ACCEPTANCE,
    ACCEPTED,
    IN_PROGRESS,
    LEGACY_ASSIGNED,
    COMPLETED,
)


def list_events_for_member_assignments(
    db: Session, member_id: int
) -> list[tuple[EventCalendar, RequestAssignment]]:
    """Calendar rows where [member_id] has a non-declined assignment on an approved request."""
    rows = list(
        db.scalars(
            select(EventCalendar)
            .join(DocumentationRequest, EventCalendar.request_id == DocumentationRequest.id)
            .join(
                RequestAssignment,
                RequestAssignment.request_id == DocumentationRequest.id,
            )
            .options(
                joinedload(EventCalendar.request).joinedload(DocumentationRequest.requestor),
                joinedload(EventCalendar.request)
                .joinedload(DocumentationRequest.assignments)
                .joinedload(RequestAssignment.member),
                joinedload(EventCalendar.assigned_member),
            )
            .where(
                RequestAssignment.member_id == member_id,
                RequestAssignment.status.in_(_MEMBER_ASSIGNMENT_STATUSES),
                DocumentationRequest.status.ilike("approved"),
            )
            .order_by(EventCalendar.start_date.asc(), EventCalendar.start_time.asc())
        ).unique()
    )
    out: list[tuple[EventCalendar, RequestAssignment]] = []
    seen_request: set[int] = set()
    for event in rows:
        if event.request_id is None or event.id is None:
            continue
        if (event.status or "").lower() in {"cancelled", "canceled"}:
            continue
        if event.request_id in seen_request:
            continue
        assignment = db.scalar(
            select(RequestAssignment).where(
                RequestAssignment.request_id == event.request_id,
                RequestAssignment.member_id == member_id,
                RequestAssignment.status.in_(_MEMBER_ASSIGNMENT_STATUSES),
            )
        )
        if assignment is None:
            continue
        seen_request.add(event.request_id)
        out.append((event, assignment))
    return out


def list_events_for_requestor(db: Session, requestor_id: int) -> list[EventCalendar]:
    rows = list(
        db.scalars(
            select(EventCalendar)
            .join(DocumentationRequest, EventCalendar.request_id == DocumentationRequest.id)
            .options(
                joinedload(EventCalendar.request)
                .joinedload(DocumentationRequest.assignments)
                .joinedload(RequestAssignment.member),
                joinedload(EventCalendar.assigned_member),
            )
            .where(
                DocumentationRequest.requestor_id == requestor_id,
                DocumentationRequest.status.ilike("approved"),
            )
            .order_by(EventCalendar.start_date.asc(), EventCalendar.start_time.asc())
        ).unique()
    )
    return [
        e
        for e in rows
        if (e.status or "").lower() not in {"cancelled", "canceled"}
    ]


def member_has_assignment_on_event(db: Session, member_id: int, event: EventCalendar) -> RequestAssignment | None:
    if event.request_id is None:
        return None
    return db.scalar(
        select(RequestAssignment).where(
            RequestAssignment.request_id == event.request_id,
            RequestAssignment.member_id == member_id,
            RequestAssignment.status != DECLINED,
        )
    )


def requestor_owns_event(event: EventCalendar, requestor_id: int) -> bool:
    req = event.request
    return req is not None and req.requestor_id == requestor_id


def event_to_campus_json(e: EventCalendar) -> dict:
    status = (e.status or "upcoming").lower()
    if status == "assigned":
        public_status = "scheduled"
    elif status in {"cancelled", "canceled", "pending"}:
        public_status = "upcoming"
    else:
        public_status = status
    return {
        "id": e.id,
        "title": e.title,
        "start_date": e.start_date.isoformat(),
        "end_date": e.end_date.isoformat() if e.end_date else None,
        "start_time": e.start_time.isoformat() if e.start_time else None,
        "end_time": e.end_time.isoformat() if e.end_time else None,
        "location": e.venue,
        "venue": e.venue,
        "status": public_status,
    }


def event_to_member_assignment_json(e: EventCalendar, assignment: RequestAssignment) -> dict:
    base = event_to_json(e)
    base["assignment_id"] = assignment.id
    base["assignment_status"] = assignment.status
    base["task_role"] = assignment.task_role
    if base.get("request_id") is None and e.request_id is not None:
        base["request_id"] = e.request_id
    return base


def event_to_requestor_json(e: EventCalendar) -> dict:
    data = event_to_json(e)
    if data.get("request_id") is None and e.request_id is not None:
        data["request_id"] = e.request_id
    data.pop("assigned_member_name", None)
    data.pop("requester_id", None)
    data.pop("requester_name", None)
    data.pop("requestor_name", None)
    data.pop("admin_remarks", None)
    return data


def get_event(db: Session, event_id: int) -> EventCalendar | None:
    return db.scalar(
        select(EventCalendar)
        .options(
            joinedload(EventCalendar.request),
            joinedload(EventCalendar.assigned_member),
        )
        .where(EventCalendar.id == event_id)
    )


def create_event(db: Session, data: dict) -> EventCalendar:
    row = EventCalendar(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return get_event(db, row.id) or row


def update_event(db: Session, row: EventCalendar, data: dict) -> EventCalendar:
    for key, value in data.items():
        if hasattr(row, key):
            setattr(row, key, value)
    db.commit()
    db.refresh(row)
    return get_event(db, row.id) or row


def delete_event(db: Session, row: EventCalendar) -> None:
    db.delete(row)
    db.commit()


def _documentation_team(req: DocumentationRequest | None) -> list[str]:
    if req is None:
        return []
    names: list[str] = []
    seen: set[str] = set()
    for assignment in req.assignments or []:
        member = assignment.member
        if member is None:
            continue
        name = (member.fullname or "").strip()
        if not name or name in seen:
            continue
        seen.add(name)
        names.append(name)
    return names


def event_to_json(e: EventCalendar) -> dict:
    member = e.assigned_member
    req = e.request
    team = _documentation_team(req)
    requestor = req.requestor if req else None
    requestor_name = None
    if requestor is not None:
        requestor_name = (requestor.fullname or requestor.email or "").strip() or None
    return {
        "id": e.id,
        "request_id": e.request_id,
        "documentation_request_id": e.request_id,
        "title": e.title,
        "description": e.description,
        "event_date": e.start_date.isoformat(),
        "start_date": e.start_date.isoformat(),
        "end_date": e.end_date.isoformat() if e.end_date else None,
        "start_time": e.start_time.isoformat() if e.start_time else None,
        "end_time": e.end_time.isoformat() if e.end_time else None,
        "location": e.venue,
        "venue": e.venue,
        "status": e.status,
        "assigned_member_id": e.assigned_member_id,
        "assigned_member_name": member.fullname if member else None,
        "documentation_team": team,
        "request_status": req.status if req else None,
        "requester_id": req.requestor_id if req else None,
        "requester_name": requestor_name,
        "requestor_name": requestor_name,
        "admin_remarks": e.admin_remarks,
        "created_at": first_timestamp_iso(e, "created_at"),
        "updated_at": first_timestamp_iso(e, "updated_at", "created_at"),
    }


def parse_time(value: str | None) -> time | None:
    if not value:
        return None
    from app.services.schedule_conflict import parse_flexible_time

    return parse_flexible_time(value)


def parse_date(value: str | None) -> date | None:
    if not value:
        return None
    return date.fromisoformat(value[:10])
