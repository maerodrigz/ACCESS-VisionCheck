"""Calendar row sync when documentation requests are approved, assigned, or rescheduled."""

from __future__ import annotations

from datetime import date, timedelta
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401 — register metadata for create_all

from app.crud import event_calendar as event_cal_crud
from app.database import Base
from app.models.documentation_request import DocumentationRequest
from app.crud import assignment as assignment_crud
from app.models.assignment_constants import PENDING_ACCEPTANCE
from app.models.event_calendar import EventCalendar
from app.models.request_assignment import RequestAssignment
from app.models.role import Role
from app.models.user import User


@pytest.fixture()
def db() -> Session:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def _user(db: Session, email: str) -> User:
    role = Role(role_name="Organization")
    db.add(role)
    db.flush()
    user = User(email=email, fullname="Test Org", password="x", role_id=role.id, status="approved")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _request(db: Session, requestor: User, *, status: str = "pending") -> DocumentationRequest:
    row = DocumentationRequest(
        requestor_id=requestor.id,
        title="Calendar Sync Test",
        description="Desc",
        event_date=date.today() + timedelta(days=14),
        venue="Hall A",
        start_time="09:00",
        end_time="11:00",
        status=status,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def test_pending_does_not_create_calendar(db: Session) -> None:
    org = _user(db, "cal-pending@example.com")
    req = _request(db, org, status="pending")
    assert event_cal_crud.sync_calendar_from_request(db, req) is None
    assert event_cal_crud.get_event_for_request(db, req.id) is None


def test_approve_creates_single_upcoming_event(db: Session) -> None:
    org = _user(db, "cal-approve@example.com")
    req = _request(db, org, status="pending")
    req.status = "approved"
    db.commit()
    event = event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    assert event is not None
    assert event.request_id == req.id
    assert event.status == "upcoming"
    assert event.assigned_member_id is None

    again = event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    assert again is not None
    assert again.id == event.id
    count = db.scalar(
        select(EventCalendar.id).where(EventCalendar.request_id == req.id)
    )
    rows = list(db.scalars(select(EventCalendar).where(EventCalendar.request_id == req.id)))
    assert len(rows) == 1


def test_approve_visible_in_member_event_list(db: Session) -> None:
    org = _user(db, "cal-list@example.com")
    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    visible = event_cal_crud.list_member_events(db)
    assert any(e.request_id == req.id for e in visible)


def test_reject_cancels_existing_event(db: Session) -> None:
    org = _user(db, "cal-reject@example.com")
    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    req.status = "rejected"
    db.commit()
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    event = event_cal_crud.get_event_for_request(db, req.id)
    assert event is not None
    assert event.status == "cancelled"
    assert not any(e.request_id == req.id for e in event_cal_crud.list_member_events(db))


def test_double_approve_sync_still_one_event(db: Session) -> None:
    org = _user(db, "cal-double-approve@example.com")
    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    e1 = event_cal_crud.get_event_for_request(db, req.id)
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    e2 = event_cal_crud.get_event_for_request(db, req.id)
    assert e1 is not None and e2 is not None
    assert e1.id == e2.id
    assert len(list(db.scalars(select(EventCalendar).where(EventCalendar.request_id == req.id)))) == 1


def test_assign_reuses_calendar_event(db: Session) -> None:
    org = _user(db, "cal-assign-org@example.com")
    member_role = Role(role_name="Member")
    db.add(member_role)
    db.flush()
    member = User(
        email="cal-assign-member@example.com",
        fullname="Member",
        password="x",
        role_id=member_role.id,
        status="approved",
    )
    db.add(member)
    db.commit()
    db.refresh(member)

    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    event_before = event_cal_crud.get_event_for_request(db, req.id)
    assert event_before is not None
    event_id = event_before.id

    assignment, event_after = assignment_crud.create_assignment(
        db,
        request=req,
        member_id=member.id,
        assigned_by=member.id,
        task_role="photographer",
    )
    assert assignment.status == PENDING_ACCEPTANCE
    assert event_after.id == event_id
    assert event_after.assigned_member_id == member.id
    assert event_after.status == "assigned"


def test_two_assignments_one_calendar_event(db: Session) -> None:
    org = _user(db, "cal-two-assign-org@example.com")
    member_role = Role(role_name="Member")
    db.add(member_role)
    db.flush()
    m1 = User(email="cal-m1@example.com", fullname="M1", password="x", role_id=member_role.id, status="approved")
    m2 = User(email="cal-m2@example.com", fullname="M2", password="x", role_id=member_role.id, status="approved")
    db.add_all([m1, m2])
    db.commit()
    db.refresh(m1)
    db.refresh(m2)

    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()

    assignment_crud.create_assignment(
        db, request=req, member_id=m1.id, assigned_by=m1.id, task_role="photographer"
    )
    assignment_crud.create_assignment(
        db, request=req, member_id=m2.id, assigned_by=m1.id, task_role="videographer"
    )
    events = list(db.scalars(select(EventCalendar).where(EventCalendar.request_id == req.id)))
    assert len(events) == 1


def test_reschedule_updates_pending_event(db: Session) -> None:
    org = _user(db, "cal-resched@example.com")
    req = _request(db, org, status="approved")
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    new_date = req.event_date + timedelta(days=7)
    req.event_date = new_date
    req.start_time = "10:00"
    req.end_time = "12:00"
    req.status = "pending"
    db.commit()
    event_cal_crud.sync_calendar_from_request(db, req)
    db.commit()
    event = event_cal_crud.get_event_for_request(db, req.id)
    assert event is not None
    assert event.start_date == new_date
    assert event.status == "pending"
