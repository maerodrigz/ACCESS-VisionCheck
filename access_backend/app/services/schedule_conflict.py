"""Detect documentation schedule conflicts with campus events and other requests."""

from __future__ import annotations

import re
from datetime import date, datetime, time

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar

_CANCELLED_EVENT_STATUSES = ("cancelled", "canceled")
_ACTIVE_REQUEST_STATUSES = ("pending", "approved")
_DEFAULT_DURATION_MINUTES = 60


def parse_flexible_time(value: str | time | None) -> time | None:
    if value is None:
        return None
    if isinstance(value, time):
        return value
    raw = " ".join(str(value).strip().upper().split())
    if not raw:
        return None
    raw = re.sub(r"(\d)(AM|PM)$", r"\1 \2", raw)
    for fmt in ("%I:%M %p", "%I:%M:%S %p", "%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(raw, fmt).time()
        except ValueError:
            continue
    return None


def _minutes(value: time) -> int:
    return value.hour * 60 + value.minute


def time_range_minutes(
    start: time | None,
    end: time | None,
    *,
    default_duration_minutes: int = _DEFAULT_DURATION_MINUTES,
) -> tuple[int, int] | None:
    if start is None:
        return None
    start_m = _minutes(start)
    if end is None:
        return start_m, start_m + default_duration_minutes
    end_m = _minutes(end)
    if end_m <= start_m:
        end_m = start_m + default_duration_minutes
    return start_m, end_m


def ranges_overlap(a: tuple[int, int], b: tuple[int, int]) -> bool:
    return a[0] < b[1] and b[0] < a[1]


def _format_time_label(value: time | None) -> str:
    if value is None:
        return "Time TBA"
    return value.strftime("%I:%M %p").lstrip("0")


def _calendar_conflicts(
    db: Session,
    *,
    event_date: date,
    request_range: tuple[int, int],
    exclude_request_id: int | None,
) -> list[dict]:
    rows = db.scalars(
        select(EventCalendar).where(
            EventCalendar.start_date == event_date,
            EventCalendar.status.notin_(_CANCELLED_EVENT_STATUSES),
        )
    ).all()
    conflicts: list[dict] = []
    for row in rows:
        if exclude_request_id is not None and row.request_id == exclude_request_id:
            continue
        event_range = time_range_minutes(row.start_time, row.end_time)
        if event_range is None:
            continue
        if ranges_overlap(request_range, event_range):
            conflicts.append(
                {
                    "source": "campus_event",
                    "title": row.title,
                    "start_time": _format_time_label(row.start_time),
                    "end_time": _format_time_label(row.end_time),
                }
            )
    return conflicts


def _request_conflicts(
    db: Session,
    *,
    event_date: date,
    request_range: tuple[int, int],
    exclude_request_id: int | None,
) -> list[dict]:
    q = select(DocumentationRequest).where(
        DocumentationRequest.event_date == event_date,
        DocumentationRequest.status.in_(_ACTIVE_REQUEST_STATUSES),
    )
    if exclude_request_id is not None:
        q = q.where(DocumentationRequest.id != exclude_request_id)
    rows = db.scalars(q).all()
    conflicts: list[dict] = []
    for row in rows:
        other_range = time_range_minutes(
            parse_flexible_time(row.start_time),
            parse_flexible_time(row.end_time),
        )
        if other_range is None:
            continue
        if ranges_overlap(request_range, other_range):
            conflicts.append(
                {
                    "source": "documentation_request",
                    "title": row.title,
                    "start_time": row.start_time or "Time TBA",
                    "end_time": row.end_time or "Time TBA",
                }
            )
    return conflicts


def find_schedule_conflicts(
    db: Session,
    *,
    event_date: date,
    start_time: str | time | None,
    end_time: str | time | None,
    exclude_request_id: int | None = None,
) -> list[dict]:
    start = parse_flexible_time(start_time)
    end = parse_flexible_time(end_time)
    request_range = time_range_minutes(start, end)
    if request_range is None:
        return []
    campus = _calendar_conflicts(
        db,
        event_date=event_date,
        request_range=request_range,
        exclude_request_id=exclude_request_id,
    )
    requests = _request_conflicts(
        db,
        event_date=event_date,
        request_range=request_range,
        exclude_request_id=exclude_request_id,
    )
    return campus + requests


def validate_request_schedule(
    db: Session,
    *,
    event_date: date,
    start_time: str | time | None,
    end_time: str | time | None,
    exclude_request_id: int | None = None,
) -> None:
    if event_date < date.today():
        raise ValueError("Event date must be today or in the future.")

    start = parse_flexible_time(start_time)
    end = parse_flexible_time(end_time)
    if start is None or end is None:
        raise ValueError("Start time and end time are required.")
    if _minutes(start) >= _minutes(end):
        raise ValueError("End time must be after start time.")

    conflicts = find_schedule_conflicts(
        db,
        event_date=event_date,
        start_time=start,
        end_time=end,
        exclude_request_id=exclude_request_id,
    )
    if not conflicts:
        return

    first = conflicts[0]
    if first["source"] == "campus_event":
        raise ValueError(
            "This time overlaps with an existing campus event "
            f"({first['title']}, {first['start_time']} to {first['end_time']}). "
            "You may schedule on the same date, but choose a different time slot."
        )
    raise ValueError(
        "This time overlaps with another documentation request "
        f"({first['title']}, {first['start_time']} to {first['end_time']}). "
        "Choose a different time slot."
    )
