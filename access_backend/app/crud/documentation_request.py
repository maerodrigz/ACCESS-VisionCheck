from datetime import date, datetime, timedelta, timezone
import json

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.documentation_request import DocumentationRequest


def create(db: Session, requestor_id: int, data: dict) -> DocumentationRequest:
    row = DocumentationRequest(requestor_id=requestor_id, **data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def find_recent_duplicate(
    db: Session,
    requestor_id: int,
    title: str,
    event_date: date,
    *,
    window_minutes: int = 30,
) -> DocumentationRequest | None:
    """Same requestor re-submitting after a partial API failure (saved row, error response)."""
    title_norm = title.strip().lower()
    if not title_norm:
        return None
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=window_minutes)
    rows = db.scalars(
        select(DocumentationRequest)
        .options(joinedload(DocumentationRequest.requestor))
        .where(
            DocumentationRequest.requestor_id == requestor_id,
            DocumentationRequest.event_date == event_date,
            DocumentationRequest.status == "pending",
            DocumentationRequest.created_at >= cutoff,
        )
        .order_by(DocumentationRequest.created_at.desc())
    ).all()
    for row in rows:
        if (row.title or "").strip().lower() == title_norm:
            return row
    return None


def list_for_user(db: Session, user_id: int) -> list[DocumentationRequest]:
    return list(
        db.scalars(
            select(DocumentationRequest)
            .options(joinedload(DocumentationRequest.requestor))
            .where(DocumentationRequest.requestor_id == user_id)
            .order_by(DocumentationRequest.created_at.desc())
        )
    )


def list_all(db: Session) -> list[DocumentationRequest]:
    return list(
        db.scalars(
            select(DocumentationRequest)
            .options(joinedload(DocumentationRequest.requestor))
            .order_by(DocumentationRequest.created_at.desc())
        )
    )


def get(db: Session, request_id: int) -> DocumentationRequest | None:
    return db.scalar(
        select(DocumentationRequest)
        .options(joinedload(DocumentationRequest.requestor))
        .where(DocumentationRequest.id == request_id)
    )


def update_status(
    db: Session,
    row: DocumentationRequest,
    status: str,
    rejection_reason: str | None = None,
) -> DocumentationRequest:
    row.status = status.strip().lower()
    if rejection_reason:
        row.rejection_reason = rejection_reason
    db.commit()
    db.refresh(row)
    return row


def reschedule(
    db: Session,
    row: DocumentationRequest,
    *,
    event_date: date,
    start_time: str | None,
    end_time: str | None,
) -> DocumentationRequest:
    """Move event schedule back to pending for admin re-review."""
    now = datetime.now(timezone.utc)
    history = row.reschedule_history_list()
    history.append(
        {
            "rescheduled_at": now.isoformat(),
            "from_event_date": row.event_date.isoformat(),
            "from_start_time": row.start_time,
            "from_end_time": row.end_time,
            "to_event_date": event_date.isoformat(),
            "to_start_time": start_time,
            "to_end_time": end_time,
            "previous_status": row.status,
            "rejection_reason": row.rejection_reason,
        }
    )
    if row.original_event_date is None:
        row.original_event_date = row.event_date
    row.event_date = event_date
    row.start_time = start_time
    row.end_time = end_time
    row.status = "pending"
    row.rejection_reason = None
    row.reschedule_history = json.dumps(history)
    row.last_rescheduled_at = now
    db.commit()
    db.refresh(row)
    return get(db, row.id) or row
