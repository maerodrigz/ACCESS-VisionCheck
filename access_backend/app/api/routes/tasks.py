"""Assigned tasks (request_assignments) for members."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import assignment as assignment_crud
from app.database import get_db
from app.models.assignment_constants import DECLINE_REASONS
from app.models.enums import RoleName
from app.models.user import User
from app.schemas.member_api import AssignmentOut, AssignmentRespond, AssignmentStatusUpdate

router = APIRouter(prefix="/tasks", tags=["Tasks"])


def _to_out(row) -> AssignmentOut:
    req = row.request
    member = row.member
    return AssignmentOut(
        id=row.id,
        request_id=row.request_id,
        member_id=row.member_id,
        member_name=member.fullname if member else None,
        task_role=row.task_role,
        status=row.status,
        request_title=req.title if req else "",
        request_description=req.description if req else None,
        event_date=req.event_date if req else row.assigned_at.date(),
        venue=req.venue if req else None,
        start_time=req.start_time if req else None,
        end_time=req.end_time if req else None,
        request_status=req.status if req else "",
        decline_reason=row.decline_reason,
        decline_reason_code=row.decline_reason_code,
        assigned_at=row.assigned_at,
        responded_at=row.responded_at,
        completed_at=row.completed_at,
        service_points_awarded=row.service_points_awarded,
    )


@router.get("", response_model=list[AssignmentOut])
def list_tasks(db: Session = Depends(get_db), current_user: User = Depends(require_approved)):
    if current_user.role.role_name == RoleName.ADMIN:
        from sqlalchemy import select
        from app.models.request_assignment import RequestAssignment
        from sqlalchemy.orm import joinedload

        rows = list(
            db.scalars(
                select(RequestAssignment)
                .options(joinedload(RequestAssignment.request), joinedload(RequestAssignment.member))
                .order_by(RequestAssignment.id.desc())
            )
        )
    else:
        rows = assignment_crud.list_for_member(db, current_user.id)
    return [_to_out(r) for r in rows]


@router.post("/{assignment_id}/respond", response_model=AssignmentOut)
def respond_to_assignment(
    assignment_id: int,
    body: AssignmentRespond,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services import notification_events as notify_events

    row = assignment_crud.get(db, assignment_id)
    if not row:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if row.member_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your assignment")

    action = body.action.strip().lower()
    req = row.request
    event_title = req.title if req else "Documentation event"

    if action == "accept":
        try:
            row = assignment_crud.accept_assignment(db, row)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        try:
            notify_events.notify_assignment_accepted(
                db,
                row.id,
                current_user.fullname or current_user.email,
                event_title,
                row.task_role,
            )
        except Exception:
            pass
    elif action == "decline":
        code = (body.decline_reason_code or "").strip().lower()
        if code not in DECLINE_REASONS:
            raise HTTPException(status_code=400, detail="Valid decline reason is required.")
        reason_text = (body.decline_reason or "").strip()
        if code == "other" and len(reason_text) < 8:
            raise HTTPException(status_code=400, detail="Please provide a short explanation.")
        try:
            row = assignment_crud.decline_assignment(
                db,
                row,
                reason_code=code,
                reason_text=reason_text or code.replace("_", " "),
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        try:
            notify_events.notify_assignment_declined(
                db,
                row.id,
                current_user.fullname or current_user.email,
                event_title,
                row.task_role,
                row.decline_reason or code,
            )
        except Exception:
            pass
    else:
        raise HTTPException(status_code=400, detail="action must be accept or decline")

    row = assignment_crud.get(db, row.id)
    assert row is not None
    return _to_out(row)


@router.patch("/{assignment_id}", response_model=AssignmentOut)
def update_task_status(
    assignment_id: int,
    body: AssignmentStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    row = assignment_crud.get(db, assignment_id)
    if not row:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if (
        current_user.role.role_name != RoleName.ADMIN
        and row.member_id != current_user.id
    ):
        raise HTTPException(status_code=403, detail="Not your assignment")

    status = body.status.strip().lower()
    if status in ("completed", "done"):
        raise HTTPException(
            status_code=400,
            detail="Assignment completion is no longer supported. Accept or decline only.",
        )

    try:
        row = assignment_crud.update_status(db, row, body.status)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return _to_out(row)
