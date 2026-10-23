"""Option C calendar scopes, redaction, and authorization."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401

from app.crud import assignment as assignment_crud
from app.crud import event_calendar as event_cal_crud
from app.database import Base, get_db
from app.models.documentation_request import DocumentationRequest
from app.models.event_calendar import EventCalendar
from app.models.role import Role
from app.models.user import User
from main import app


@pytest.fixture()
def db() -> Session:
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(db: Session) -> TestClient:
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _role(db: Session, name: str) -> Role:
    existing = db.scalar(select(Role).where(Role.role_name == name))
    if existing is not None:
        return existing
    row = Role(role_name=name)
    db.add(row)
    db.flush()
    return row


def _user(db: Session, email: str, role_name: str) -> User:
    role = _role(db, role_name)
    user = User(
        email=email,
        fullname=email.split("@")[0],
        password="hash",
        role_id=role.id,
        status="approved",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _token_for(user: User) -> str:
    from app.core.security import create_access_token

    return create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": user.role.role_name,
        }
    )


def _request(
    db: Session, requestor: User, *, title: str = "Event A", status: str = "approved"
) -> DocumentationRequest:
    row = DocumentationRequest(
        requestor_id=requestor.id,
        title=title,
        description="Private description for " + title,
        event_date=date.today() + timedelta(days=10),
        venue="Hall",
        start_time="09:00",
        end_time="11:00",
        status=status,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    if status.lower() == "approved":
        event_cal_crud.sync_calendar_from_request(db, row)
        db.commit()
    return row


def test_unscoped_list_rejected(client: TestClient, db: Session) -> None:
    member = _user(db, "optc-member@example.com", "Member")
    token = _token_for(member)
    r = client.get("/api/events", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 422


def test_member_assignments_only_own(client: TestClient, db: Session) -> None:
    org_a = _user(db, "optc-org-a@example.com", "Organization")
    org_b = _user(db, "optc-org-b@example.com", "Organization")
    m_a = _user(db, "optc-ma@example.com", "Member")
    m_b = _user(db, "optc-mb@example.com", "Member")
    admin = _user(db, "optc-admin@example.com", "Admin")

    req_a = _request(db, org_a, title="Org A Event")
    req_b = _request(db, org_b, title="Org B Event")
    assignment_crud.create_assignment(
        db, request=req_a, member_id=m_a.id, assigned_by=admin.id, task_role="photographer"
    )
    assignment_crud.create_assignment(
        db, request=req_b, member_id=m_b.id, assigned_by=admin.id, task_role="photographer"
    )

    tok_a = _token_for(m_a)
    r = client.get(
        "/api/events?scope=assignments",
        headers={"Authorization": f"Bearer {tok_a}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert len(body) == 1
    assert body[0]["title"] == "Org A Event"
    assert body[0]["assignment_id"] is not None
    assert "Private description" in (body[0].get("description") or "")

    tok_b = _token_for(m_b)
    r_b = client.get(
        "/api/events?scope=assignments",
        headers={"Authorization": f"Bearer {tok_b}"},
    )
    assert r_b.status_code == 200
    assert len(r_b.json()) == 1
    assert r_b.json()[0]["title"] == "Org B Event"


def test_member_b_cannot_read_a_assignment_detail(client: TestClient, db: Session) -> None:
    org_a = _user(db, "optc2-org-a@example.com", "Organization")
    m_a = _user(db, "optc2-ma@example.com", "Member")
    m_b = _user(db, "optc2-mb@example.com", "Member")
    admin = _user(db, "optc2-admin@example.com", "Admin")
    req = _request(db, org_a, title="Secret Event")
    assignment_crud.create_assignment(
        db, request=req, member_id=m_a.id, assigned_by=admin.id, task_role="photographer"
    )
    event_id = event_cal_crud.get_event_for_request(db, req.id).id

    tok_b = _token_for(m_b)
    r = client.get(
        f"/api/events/{event_id}",
        headers={"Authorization": f"Bearer {tok_b}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert "description" not in data or data.get("description") in (None, "")
    assert "documentation_team" not in data
    assert "assignment_id" not in data


def test_campus_includes_unassigned_and_redacts(client: TestClient, db: Session) -> None:
    org = _user(db, "optc3-org@example.com", "Organization")
    member = _user(db, "optc3-member@example.com", "Member")
    _request(db, org, title="Unassigned Approved")
    tok = _token_for(member)
    r = client.get(
        "/api/events?scope=campus",
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 200
    assert len(r.json()) >= 1
    row = r.json()[0]
    assert set(row.keys()) <= {
        "id",
        "title",
        "start_date",
        "end_date",
        "start_time",
        "end_time",
        "venue",
        "location",
        "status",
    }
    assert "description" not in row
    assert "documentation_team" not in row
    assert "request_id" not in row


def test_requestor_scoped_to_own_org(client: TestClient, db: Session) -> None:
    org_a = _user(db, "optc4-org-a@example.com", "Organization")
    org_b = _user(db, "optc4-org-b@example.com", "Organization")
    _request(db, org_a, title="A Private")
    _request(db, org_b, title="B Private")

    tok_a = _token_for(org_a)
    r = client.get(
        "/api/events?scope=my-requests",
        headers={"Authorization": f"Bearer {tok_a}"},
    )
    assert r.status_code == 200
    titles = {row["title"] for row in r.json()}
    assert titles == {"A Private"}
    assert "description" in r.json()[0]


def test_requestor_detail_other_org_is_public_only(client: TestClient, db: Session) -> None:
    org_a = _user(db, "optc5-org-a@example.com", "Organization")
    org_b = _user(db, "optc5-org-b@example.com", "Organization")
    req_b = _request(db, org_b, title="B Event")
    event_id = event_cal_crud.get_event_for_request(db, req_b.id).id

    tok_a = _token_for(org_a)
    r = client.get(
        f"/api/events/{event_id}",
        headers={"Authorization": f"Bearer {tok_a}"},
    )
    assert r.status_code == 200
    assert "assignment_id" not in r.json()
    assert "description" not in r.json() or not r.json().get("description")


def test_admin_member_list_forbidden(client: TestClient, db: Session) -> None:
    admin = _user(db, "optc6-admin@example.com", "Admin")
    tok = _token_for(admin)
    r = client.get(
        "/api/events?scope=campus",
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 403


def test_admin_can_list_all_admin_route(client: TestClient, db: Session) -> None:
    org = _user(db, "optc7-org@example.com", "Organization")
    admin = _user(db, "optc7-admin@example.com", "Admin")
    _request(db, org)
    tok = _token_for(admin)
    r = client.get("/api/admin/events", headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 200
    assert len(r.json()) >= 1
    assert "description" in r.json()[0]


def test_invalid_scope_rejected(client: TestClient, db: Session) -> None:
    member = _user(db, "optc8-member@example.com", "Member")
    tok = _token_for(member)
    r = client.get(
        "/api/events?scope=my-requests",
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 422


def test_member_id_query_rejected(client: TestClient, db: Session) -> None:
    member = _user(db, "optc9-member@example.com", "Member")
    tok = _token_for(member)
    r = client.get(
        "/api/events?scope=campus&member_id=999",
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 422


def test_approve_and_assign_still_one_calendar_row(db: Session) -> None:
    org = _user(db, "optc10-org@example.com", "Organization")
    member = _user(db, "optc10-member@example.com", "Member")
    admin = _user(db, "optc10-admin@example.com", "Admin")
    req = _request(db, org, status="approved")
    e1 = event_cal_crud.get_event_for_request(db, req.id)
    assignment_crud.create_assignment(
        db, request=req, member_id=member.id, assigned_by=admin.id, task_role="photographer"
    )
    rows = list(db.scalars(select(EventCalendar).where(EventCalendar.request_id == req.id)))
    assert len(rows) == 1
    assert rows[0].id == e1.id
