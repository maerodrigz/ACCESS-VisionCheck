from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import event_calendar as event_crud
from app.database import get_db
from app.models.enums import RoleName
from app.models.user import User
from app.schemas.member_api import (
    EventCampusOut,
    EventMemberAssignmentOut,
    EventRequestorOut,
)

router = APIRouter(prefix="/events", tags=["Events"])

ScopeMember = Annotated[str, Query(description="assignments | campus")]
ScopeOrg = Annotated[str, Query(description="my-requests | campus")]


def _reject_admin_list(current_user: User) -> None:
    if current_user.role.role_name == RoleName.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Admins must use GET /api/admin/events for the full calendar.",
        )


def _reject_extra_filters(**params: Any) -> None:
    blocked = {k: v for k, v in params.items() if v is not None}
    if blocked:
        raise HTTPException(
            status_code=422,
            detail="Unsupported query parameters for calendar scope.",
        )


@router.get("")
def list_events_scoped(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
    scope: str | None = None,
    member_id: int | None = None,
    requestor_id: int | None = None,
    user_id: int | None = None,
):
    """
    Scoped member/requestor calendar lists (Option C).
    Legacy unscoped GET is rejected; use scope=assignments|campus (members) or my-requests|campus (orgs).
    """
    _reject_extra_filters(member_id=member_id, requestor_id=requestor_id, user_id=user_id)
    _reject_admin_list(current_user)

    if not scope or not scope.strip():
        raise HTTPException(
            status_code=422,
            detail="scope is required (assignments, campus, or my-requests).",
        )

    key = scope.strip().lower()
    role = current_user.role.role_name

    if role == RoleName.MEMBER:
        if key == "assignments":
            pairs = event_crud.list_events_for_member_assignments(db, current_user.id)
            return [
                EventMemberAssignmentOut(**event_crud.event_to_member_assignment_json(e, a))
                for e, a in pairs
            ]
        if key == "campus":
            rows = event_crud.list_member_events(db)
            return [EventCampusOut(**event_crud.event_to_campus_json(e)) for e in rows]

    if role == RoleName.ORGANIZATION:
        if key == "my-requests":
            rows = event_crud.list_events_for_requestor(db, current_user.id)
            return [EventRequestorOut(**event_crud.event_to_requestor_json(e)) for e in rows]
        if key == "campus":
            rows = event_crud.list_member_events(db)
            return [EventCampusOut(**event_crud.event_to_campus_json(e)) for e in rows]

    raise HTTPException(
        status_code=422,
        detail=f"Invalid scope '{scope}' for role {role}.",
    )


@router.get("/{event_id}")
def get_event_detail(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
    member_id: int | None = None,
    requestor_id: int | None = None,
):
    _reject_extra_filters(member_id=member_id, requestor_id=requestor_id)

    if current_user.role.role_name == RoleName.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Admins must use GET /api/admin/events for event details.",
        )

    event = event_crud.get_event(db, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    req = event.request
    if req is not None and (req.status or "").lower() != "approved":
        raise HTTPException(status_code=404, detail="Event not found")
    if (event.status or "").lower() in {"cancelled", "canceled"}:
        raise HTTPException(status_code=404, detail="Event not found")

    role = current_user.role.role_name

    if role == RoleName.MEMBER:
        assignment = event_crud.member_has_assignment_on_event(db, current_user.id, event)
        if assignment is not None:
            return EventMemberAssignmentOut(
                **event_crud.event_to_member_assignment_json(event, assignment)
            )
        return EventCampusOut(**event_crud.event_to_campus_json(event))

    if role == RoleName.ORGANIZATION:
        if event_crud.requestor_owns_event(event, current_user.id):
            return EventRequestorOut(**event_crud.event_to_requestor_json(event))
        return EventCampusOut(**event_crud.event_to_campus_json(event))

    raise HTTPException(status_code=403, detail="Not allowed.")
