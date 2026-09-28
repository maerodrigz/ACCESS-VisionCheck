"""Compute documentation coverage availability for requestor rescheduling."""

from __future__ import annotations

from calendar import monthrange
from datetime import date, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar
from app.services.schedule_conflict import (
    find_schedule_conflicts,
    parse_flexible_time,
    time_range_minutes,
    validate_request_schedule,
)

# Standard coverage windows shown to requestors.
TIME_SLOTS: list[dict[str, str]] = [
    {"id": "morning", "label": "Morning", "start_time": "8:00 AM", "end_time": "12:00 PM"},
    {"id": "afternoon", "label": "Afternoon", "start_time": "1:00 PM", "end_time": "5:00 PM"},
    {"id": "evening", "label": "Evening", "start_time": "6:00 PM", "end_time": "9:00 PM"},
]

_ACTIVE_REQUEST_STATUSES = ("pending", "approved")
_CANCELLED_EVENT_STATUSES = ("cancelled", "canceled")


def _load_level(count: int) -> str:
    if count >= 3:
        return "unavailable"
    if count >= 1:
        return "limited"
    return "available"


def _coverage_count_for_date(
    db: Session,
    day: date,
    *,
    exclude_request_id: int | None = None,
) -> int:
    req_q = select(DocumentationRequest.id).where(
        DocumentationRequest.event_date == day,
        DocumentationRequest.status.in_(_ACTIVE_REQUEST_STATUSES),
    )
    if exclude_request_id is not None:
        req_q = req_q.where(DocumentationRequest.id != exclude_request_id)

    cal_q = select(EventCalendar.id).where(
        EventCalendar.start_date == day,
        EventCalendar.status.notin_(_CANCELLED_EVENT_STATUSES),
    )
    if exclude_request_id is not None:
        cal_q = cal_q.where(
            or_(
                EventCalendar.request_id.is_(None),
                EventCalendar.request_id != exclude_request_id,
            )
        )

    req_count = db.scalar(select(func.count()).select_from(req_q.subquery())) or 0
    cal_count = db.scalar(select(func.count()).select_from(cal_q.subquery())) or 0
    return int(req_count) + int(cal_count)


def month_availability(
    db: Session,
    *,
    year: int,
    month: int,
    exclude_request_id: int | None = None,
) -> list[dict]:
    today = date.today()
    _, days = monthrange(year, month)
    out: list[dict] = []
    for day_num in range(1, days + 1):
        d = date(year, month, day_num)
        if d < today:
            out.append(
                {
                    "date": d.isoformat(),
                    "level": "unavailable",
                    "bookings": 0,
                    "selectable": False,
                }
            )
            continue
        bookings = _coverage_count_for_date(db, d, exclude_request_id=exclude_request_id)
        level = _load_level(bookings)
        out.append(
            {
                "date": d.isoformat(),
                "level": level,
                "bookings": bookings,
                "selectable": level != "unavailable",
            }
        )
    return out


def slots_for_date(
    db: Session,
    day: date,
    *,
    exclude_request_id: int | None = None,
) -> list[dict]:
    day_bookings = _coverage_count_for_date(db, day, exclude_request_id=exclude_request_id)
    day_level = _load_level(day_bookings)
    slots: list[dict] = []
    for slot in TIME_SLOTS:
        if day_level == "unavailable":
            level = "unavailable"
            selectable = False
        else:
            slot_range = time_range_minutes(
                parse_flexible_time(slot["start_time"]),
                parse_flexible_time(slot["end_time"]),
            )
            has_time_conflict = False
            if slot_range is not None:
                for conflict in find_schedule_conflicts(
                    db,
                    event_date=day,
                    start_time=slot["start_time"],
                    end_time=slot["end_time"],
                    exclude_request_id=exclude_request_id,
                ):
                    has_time_conflict = True
                    break
            if has_time_conflict:
                level = "unavailable"
                selectable = False
            elif day_bookings == 0:
                level = "available"
                selectable = True
            elif day_bookings == 1:
                level = "limited"
                selectable = True
            else:
                level = "unavailable"
                selectable = False
        slots.append(
            {
                **slot,
                "level": level,
                "selectable": selectable,
            }
        )
    return slots


def validate_reschedule_selection(
    db: Session,
    *,
    event_date: date,
    start_time: str | None = None,
    end_time: str | None = None,
    exclude_request_id: int | None = None,
) -> None:
    validate_request_schedule(
        db,
        event_date=event_date,
        start_time=start_time,
        end_time=end_time,
        exclude_request_id=exclude_request_id,
    )
    bookings = _coverage_count_for_date(db, event_date, exclude_request_id=exclude_request_id)
    if bookings >= 3:
        raise ValueError("Selected date is no longer available for documentation coverage.")
