"""Self-registration no longer requires Email OTP verification."""

from __future__ import annotations

from app.schemas.auth import RegisterRequest


def test_register_request_token_optional():
    body = RegisterRequest(
        name="Test Member",
        email="phase0.member@example.com",
        password="secret12",
        role="Member",
        student_id="2026-00001",
        contact_number="09171234567",
    )
    assert body.email_verification_token is None
    assert body.contact_number == "09171234567"


def test_register_handler_skips_email_otp_gate(monkeypatch):
    from app.api.routes import auth as auth_routes
    from app.models.enums import UserStatus

    class _FakeUser:
        id = 99
        email = "phase0.member@example.com"
        fullname = "Test Member"
        student_id = "2026-00001"
        status = UserStatus.PENDING

        class _Role:
            role_name = "Member"

        role = _Role()

    calls: dict[str, object] = {}

    def _fake_get_by_email(_db, email: str):
        return None

    def _fake_conflict(_db, phone: str, exclude_user_id=None):
        return None

    def _fake_assert_password(_db, password: str):
        return None

    def _fake_create_user(db, name, email, password, role, **kwargs):
        calls["create"] = {
            "name": name,
            "email": email,
            "role": role,
            "contact_number": kwargs.get("contact_number"),
            "student_id": kwargs.get("student_id"),
        }
        return _FakeUser()

    def _fake_notify(**kwargs):
        calls["notify"] = True

    monkeypatch.setattr(auth_routes.user_crud, "get_by_email", _fake_get_by_email)
    monkeypatch.setattr(auth_routes.user_crud, "find_verified_phone_conflict", _fake_conflict)
    monkeypatch.setattr(auth_routes, "assert_password_meets_policy", _fake_assert_password)
    monkeypatch.setattr(auth_routes.user_crud, "create_user", _fake_create_user)
    monkeypatch.setattr(auth_routes.registration_email, "notify_registration_received_async", _fake_notify)

    body = RegisterRequest(
        name="Test Member",
        email="phase0.member@example.com",
        password="secret12",
        role="Member",
        student_id="2026-00001",
        contact_number="09171234567",
    )
    resp = auth_routes.register(body, db=None)  # type: ignore[arg-type]
    assert "pending" in resp.message.lower() or "awaiting" in resp.message.lower()
    assert calls["create"]["contact_number"] == "+639171234567"
    assert calls.get("notify") is True
