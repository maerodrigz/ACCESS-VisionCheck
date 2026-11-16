"""Idempotent duplicate POST vs genuine schedule conflicts."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy import create_engine

import app.models  # noqa: F401

from app.crud import documentation_request as req_crud
from app.database import Base
from app.models.documentation_request import DocumentationRequest
from app.models.role import Role
from app.models.user import User
from app.services.schedule_conflict import validate_request_schedule


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


def _org_role(db: Session) -> Role:
    role = db.scalar(select(Role).where(Role.role_name == "Organization"))
    if role is None:
        role = Role(role_name="Organization")
        db.add(role)
        db.flush()
    return role


def _org(db: Session, email: str) -> User:
    role = _org_role(db)
    user = User(email=email, fullname="Org", password="x", role_id=role.id, status="approved")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _pending(
    db: Session,
    org: User,
    *,
    title: str,
    event_date: date,
    start: str = "09:00",
    end: str = "11:00",
) -> DocumentationRequest:
    row = DocumentationRequest(
        requestor_id=org.id,
        title=title,
        description="d",
        event_date=event_date,
        venue="Hall",
        start_time=start,
        end_time=end,
        status="pending",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def test_identical_retry_finds_same_pending(db: Session) -> None:
    org = _org(db, "dup-a@example.com")
    day = date.today() + timedelta(days=20)
    first = _pending(db, org, title="Graduation 2026", event_date=day)
    dup = req_crud.find_recent_duplicate(
        db,
        org.id,
        "Graduation 2026",
        day,
        start_time="09:00",
        end_time="11:00",
    )
    assert dup is not None
    assert dup.id == first.id


def test_duplicate_does_not_match_other_requestor(db: Session) -> None:
    org_a = _org(db, "dup-b1@example.com")
    org_b = _org(db, "dup-b2@example.com")
    day = date.today() + timedelta(days=21)
    _pending(db, org_a, title="Same Title", event_date=day)
    dup = req_crud.find_recent_duplicate(
        db,
        org_b.id,
        "Same Title",
        day,
        start_time="09:00",
        end_time="11:00",
    )
    assert dup is None


def test_duplicate_retry_skips_schedule_conflict_with_own_pending(db: Session) -> None:
    """Second identical slot would overlap own pending row; idempotent path must not validate."""
    org = _org(db, "dup-c@example.com")
    day = date.today() + timedelta(days=22)
    _pending(db, org, title="Overlap Self", event_date=day)
    dup = req_crud.find_recent_duplicate(
        db,
        org.id,
        "Overlap Self",
        day,
        start_time="09:00",
        end_time="11:00",
    )
    assert dup is not None
    with pytest.raises(ValueError, match="overlap"):
        validate_request_schedule(
            db,
            event_date=day,
            start_time="09:00",
            end_time="11:00",
        )


def test_different_title_same_slot_conflicts(db: Session) -> None:
    org = _org(db, "dup-d@example.com")
    day = date.today() + timedelta(days=23)
    _pending(db, org, title="Event A", event_date=day)
    with pytest.raises(ValueError, match="overlap"):
        validate_request_schedule(
            db,
            event_date=day,
            start_time="09:00",
            end_time="11:00",
        )


def test_duplicate_different_time_not_matched(db: Session) -> None:
    org = _org(db, "dup-e@example.com")
    day = date.today() + timedelta(days=24)
    first = _pending(db, org, title="Workshop", event_date=day, start="09:00", end="11:00")
    dup = req_crud.find_recent_duplicate(
        db,
        org.id,
        "Workshop",
        day,
        start_time="14:00",
        end_time="16:00",
    )
    assert dup is None
    assert first.id is not None
