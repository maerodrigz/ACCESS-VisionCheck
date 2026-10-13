"""Documentation / service requests."""

import logging
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_approved
from app.crud import documentation_request as req_crud
from app.database import get_db
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Documentation Requests"])


class ServiceRequestCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    event_date: date
    venue: str | None = None
    start_time: str | None = Field(default=None, max_length=20)
    end_time: str | None = Field(default=None, max_length=20)
    requirements: str | None = None


class ServiceRequestOut(BaseModel):
    id: int
    requestor_id: int
    requestor_name: str | None = None
    title: str
    description: str | None
    event_date: date
    venue: str | None
    start_time: str | None = None
    end_time: str | None = None
    requirements: str | None = None
    status: str
    rejection_reason: str | None = None
    original_event_date: date | None = None
    last_rescheduled_at: datetime | None = None
    reschedule_history: list[dict] = Field(default_factory=list)
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class ServiceRequestReschedule(BaseModel):
    event_date: date
    start_time: str | None = Field(default=None, max_length=20)
    end_time: str | None = Field(default=None, max_length=20)


class CoverageDayOut(BaseModel):
    date: str
    level: str
    bookings: int
    selectable: bool


class CoverageSlotOut(BaseModel):
    id: str
    label: str
    start_time: str
    end_time: str
    level: str
    selectable: bool


class ServiceRequestStatusUpdate(BaseModel):
    status: str
    rejection_reason: str | None = None


def _to_out(row: DocumentationRequest) -> ServiceRequestOut:
    requestor_name = None
    if row.requestor is not None:
        requestor_name = row.requestor.fullname or row.requestor.email
    return ServiceRequestOut(
        id=row.id,
        requestor_id=row.requestor_id,
        requestor_name=requestor_name,
        title=row.title,
        description=row.description,
        event_date=row.event_date,
        venue=row.venue,
        start_time=row.start_time,
        end_time=row.end_time,
        requirements=row.requirements,
        status=row.status,
        rejection_reason=row.rejection_reason,
        original_event_date=row.original_event_date,
        last_rescheduled_at=row.last_rescheduled_at,
        reschedule_history=row.reschedule_history_list(),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _assert_can_access(row: DocumentationRequest, user: User) -> None:
    if user.role.role_name == RoleName.ADMIN:
        return
    if row.requestor_id != user.id:
        raise HTTPException(status_code=403, detail="Not allowed to access this request")


@router.get("/service-requests", response_model=list[ServiceRequestOut])
def list_service_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    if current_user.role.role_name == RoleName.ADMIN:
        rows = req_crud.list_all(db)
    else:
        rows = req_crud.list_for_user(db, current_user.id)
    return [_to_out(row) for row in rows]


@router.get("/service-requests/coverage-availability", response_model=list[CoverageDayOut])
def coverage_availability(
    year: int,
    month: int,
    exclude_request_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services import coverage_availability as avail

    if exclude_request_id is not None:
        row = req_crud.get(db, exclude_request_id)
        if not row:
            raise HTTPException(status_code=404, detail="Request not found")
        _assert_can_access(row, current_user)
    if month < 1 or month > 12:
        raise HTTPException(status_code=400, detail="Invalid month")
    return avail.month_availability(
        db,
        year=year,
        month=month,
        exclude_request_id=exclude_request_id,
    )


@router.get("/service-requests/coverage-availability/slots", response_model=list[CoverageSlotOut])
def coverage_availability_slots(
    date: date,
    exclude_request_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services import coverage_availability as avail

    if exclude_request_id is not None:
        row = req_crud.get(db, exclude_request_id)
        if not row:
            raise HTTPException(status_code=404, detail="Request not found")
        _assert_can_access(row, current_user)
    return avail.slots_for_date(db, date, exclude_request_id=exclude_request_id)


@router.get("/service-requests/{request_id}", response_model=ServiceRequestOut)
def get_service_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    _assert_can_access(row, current_user)
    return _to_out(row)


@router.post("/service-requests", response_model=ServiceRequestOut)
def create_service_request(
    body: ServiceRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services import notification_events as notify_events
    from app.services.schedule_conflict import validate_request_schedule

    try:
        validate_request_schedule(
            db,
            event_date=body.event_date,
            start_time=body.start_time,
            end_time=body.end_time,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    existing = req_crud.find_recent_duplicate(
        db,
        current_user.id,
        body.title,
        body.event_date,
    )
    created = False
    if existing:
        row = existing
    else:
        row = req_crud.create(
            db,
            current_user.id,
            body.model_dump(),
        )
        created = True

    if created:
        requestor_name = current_user.fullname or current_user.email
        try:
            notify_events.notify_documentation_request_submitted(
                db, row.id, row.title, requestor_name
            )
            notify_events.notify_requestor_request_submitted(
                db, current_user.id, row.id, row.title
            )
        except Exception:
            logger.exception(
                "Admin notification failed for documentation request %s", row.id
            )

    row = req_crud.get(db, row.id)
    assert row is not None
    return _to_out(row)


@router.patch("/service-requests/{request_id}")
def update_service_request_status(
    request_id: int,
    body: ServiceRequestStatusUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    status = body.status.strip().lower()
    if status == "approved":
        from app.services.schedule_conflict import validate_request_schedule

        try:
            validate_request_schedule(
                db,
                event_date=row.event_date,
                start_time=row.start_time,
                end_time=row.end_time,
                exclude_request_id=row.id,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    if status == "rejected":
        reason = (body.rejection_reason or "").strip()
        if len(reason) < 8:
            raise HTTPException(
                status_code=400,
                detail="Rejection reason is required (at least 8 characters)",
            )
    if status == "completed":
        from app.crud import assignment as assignment_crud
        from app.models.assignment_constants import ACCEPTED, IN_PROGRESS, LEGACY_ASSIGNED

        confirmed = [
            a
            for a in assignment_crud.list_for_request(db, row.id)
            if a.status in (ACCEPTED, IN_PROGRESS, LEGACY_ASSIGNED, "completed")
        ]
        if not confirmed:
            raise HTTPException(
                status_code=400,
                detail="At least one assigned member must accept coverage before marking completed.",
            )
    req_crud.update_status(db, row, body.status, body.rejection_reason)
    from app.services import notification_events as notify_events

    notify_events.notify_documentation_request_status(
        db,
        row.requestor_id,
        row.id,
        row.title,
        body.status,
        rejection_reason=body.rejection_reason,
    )
    return {"message": f"Request {body.status}"}


@router.post("/service-requests/{request_id}/reschedule", response_model=ServiceRequestOut)
def reschedule_service_request(
    request_id: int,
    body: ServiceRequestReschedule,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services import coverage_availability as avail
    from app.services import notification_events as notify_events

    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    _assert_can_access(row, current_user)

    status = (row.status or "").strip().lower()
    if status == "completed":
        raise HTTPException(status_code=400, detail="Completed requests cannot be rescheduled.")
    if status not in {"rejected", "approved"}:
        raise HTTPException(
            status_code=400,
            detail="Only rejected or approved requests can be rescheduled.",
        )

    try:
        avail.validate_reschedule_selection(
            db,
            event_date=body.event_date,
            start_time=body.start_time,
            end_time=body.end_time,
            exclude_request_id=row.id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    previous_status = row.status
    row = req_crud.reschedule(
        db,
        row,
        event_date=body.event_date,
        start_time=body.start_time,
        end_time=body.end_time,
    )

    requestor_name = current_user.fullname or current_user.email
    try:
        notify_events.notify_documentation_request_resubmitted(
            db,
            row.id,
            row.title,
            requestor_name,
            event_date=body.event_date.isoformat(),
            previous_status=previous_status,
        )
        notify_events.notify_requestor_reschedule_pending(
            db,
            row.requestor_id,
            row.id,
            row.title,
            body.event_date.isoformat(),
        )
    except Exception:
        logger.exception("Admin notification failed for rescheduled request %s", row.id)

    row = req_crud.get(db, row.id)
    assert row is not None
    return _to_out(row)
