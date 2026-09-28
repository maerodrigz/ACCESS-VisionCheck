from datetime import date, datetime, time, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar
from app.models.request_assignment import RequestAssignment
from app.models.user import User
from app.utils.timestamps import first_timestamp_iso


def _event_query():
    return select(EventCalendar).options(
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


def list_member_events(db: Session) -> list[EventCalendar]:
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
