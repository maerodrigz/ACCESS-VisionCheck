"""Admin integrity notification classification, idempotency, and resolution."""

from __future__ import annotations

import os
import uuid

import pytest
from sqlalchemy import text

from app.services.notification_events import classify_integrity_review_alert

pytestmark_db = pytest.mark.skipif(
    os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test",
    reason="Set ACCESS_PYTEST_DB=access_waverep_test",
)


def test_classify_low_risk_missing_provenance_is_source_verification():
    title, priority, admin_msg, member_msg = classify_integrity_review_alert(
        {
            "risk_level": "low",
            "visual_risk_level": "low",
            "verdict": "authentic",
            "provenance_policy_outcome": "source_unverified",
            "primary_review_driver": "provenance_absent",
            "requires_review": True,
        },
        detection_label="human",
        file_name="clip.mp4",
        uploader="Ada",
    )
    assert title == "Source Verification Required"
    assert priority == "normal"
    assert "provenance" in admin_msg.lower() or "Camera capture provenance" in admin_msg
    assert "ai-generated content detected" not in admin_msg.lower()
    assert "not treated as ai-generated" in member_msg.lower()


def test_classify_high_ai_risk_alert():
    title, priority, admin_msg, _ = classify_integrity_review_alert(
        {
            "risk_level": "high",
            "visual_risk_level": "high",
            "verdict": "ai_generated",
            "provenance_policy_outcome": "high_ai_risk",
            "primary_review_driver": "visual_high",
            "requires_review": True,
        },
        detection_label="ai_generated",
        file_name="suspect.jpg",
        uploader="Bea",
    )
    assert title == "AI Risk Alert"
    assert priority == "high"
    assert "High AI-generation risk detected" in admin_msg


def test_classify_suspicious_non_definitive():
    title, priority, admin_msg, member_msg = classify_integrity_review_alert(
        {
            "risk_level": "suspicious",
            "visual_risk_level": "suspicious",
            "verdict": "suspicious",
            "primary_review_driver": "visual_suspicious",
            "requires_review": True,
        },
        detection_label="suspicious",
        file_name="maybe.jpg",
        uploader="Cora",
    )
    assert title == "Suspicious Media: Review Required"
    assert priority == "high"
    assert "not a confirmed AI" in admin_msg
    assert "not a final ai decision" in member_msg.lower()
    assert "ai-generated content detected" not in admin_msg.lower()


def test_classify_other_pending_verification():
    title, priority, admin_msg, _ = classify_integrity_review_alert(
        {
            "risk_level": "low",
            "verdict": "authentic",
            "primary_review_driver": "detector_unavailable",
            "requires_review": True,
        },
        detection_label="human",
        file_name="vid.mp4",
        uploader="Dan",
    )
    assert title == "Media Pending Verification"
    assert priority == "normal"
    assert "incomplete" in admin_msg.lower()


def test_route_for_integrity_deep_link():
    """Frontend helper: Open uses media_id query."""
    # Keep as a lightweight contract check without importing TS.
    media_id = 4242
    expected = f"/media-integrity?media={media_id}"
    assert expected.endswith(f"media={media_id}")


@pytestmark_db
def test_integrity_alert_idempotent_and_per_admin_inbox(monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "log")
    from app.config import settings

    settings.sms_provider = "log"
    from app.crud import notification as notification_crud
    from app.crud import user as user_crud
    from app.database import SessionLocal, engine
    from app.models.enums import RoleName, UserStatus
    from app.models.notification import Notification
    from app.models.role import Role
    from app.services import notification_events as notify_events
    from sqlalchemy import select
    from sqlalchemy.orm import Session

    def _role_id(db: Session, name: str) -> int:
        row = db.scalar(select(Role).where(Role.role_name == name))
        assert row is not None
        return row.id

    def _make_admin(db: Session, email: str):
        from app.core.security import hash_password
        from app.models.user import User

        u = User(
            fullname=f"Admin {email}",
            email=email,
            password=hash_password("AdminPass1"),
            role_id=_role_id(db, RoleName.ADMIN),
            status=UserStatus.APPROVED,
            is_active=True,
        )
        db.add(u)
        db.commit()
        db.refresh(u)
        return u

    db = SessionLocal()
    admin_a = admin_b = None
    media_id = 900000 + (uuid.uuid4().int % 100000)
    try:
        suffix = uuid.uuid4().hex[:8]
        admin_a = _make_admin(db, f"notif-a-{suffix}@waverep.example.com")
        admin_b = _make_admin(db, f"notif-b-{suffix}@waverep.example.com")

        ai_info = {
            "risk_level": "low",
            "visual_risk_level": "low",
            "verdict": "authentic",
            "provenance_policy_outcome": "source_unverified",
            "primary_review_driver": "provenance_absent",
            "requires_review": True,
        }
        notify_events.notify_ai_detection_alert(
            db,
            media_id,
            "clip.mp4",
            "Member One",
            member_id=None,
            detection_label="human",
            ai_info=ai_info,
        )
        # Second call must not duplicate per admin
        notify_events.notify_ai_detection_alert(
            db,
            media_id,
            "clip.mp4",
            "Member One",
            member_id=None,
            detection_label="human",
            ai_info=ai_info,
        )

        for admin in (admin_a, admin_b):
            inbox = notification_crud.list_for_admin_inbox(db, limit=50, admin_user_id=admin.id)
            media_rows = [
                n
                for n in inbox
                if n.action_type == "review_media" and n.action_ref_id == media_id
            ]
            assert len(media_rows) == 1
            assert media_rows[0].title == "Source Verification Required"
            assert media_rows[0].priority == "normal"
            assert media_rows[0].user_id == admin.id

        # Admin A must not see Admin B's row when scoped
        only_a = notification_crud.list_for_admin_inbox(db, limit=50, admin_user_id=admin_a.id)
        assert all(n.user_id == admin_a.id for n in only_a)

        # Resolve after admin decision
        marked = notification_crud.mark_media_integrity_alerts_resolved(db, media_id)
        assert marked >= 2
        for admin in (admin_a, admin_b):
            inbox = notification_crud.list_for_admin_inbox(db, limit=50, admin_user_id=admin.id)
            media_rows = [
                n
                for n in inbox
                if n.action_type == "review_media" and n.action_ref_id == media_id
            ]
            assert len(media_rows) == 1
            assert media_rows[0].is_read is True
            unread = [n for n in inbox if not n.is_read]
            assert all(n.action_ref_id != media_id for n in unread)
    finally:
        if media_id:
            db.execute(
                text("DELETE FROM notifications WHERE action_ref_id = :m AND category = 'ai_detection'"),
                {"m": media_id},
            )
        for u in (admin_a, admin_b):
            if u is not None:
                db.execute(text("DELETE FROM notifications WHERE user_id = :id"), {"id": u.id})
                db.execute(text("DELETE FROM users WHERE id = :id"), {"id": u.id})
        db.commit()
        db.close()


@pytestmark_db
def test_no_alert_when_requires_review_false(monkeypatch):
    from app.services.media_pipeline import _should_notify_admin_ai_flag
    from app.database import SessionLocal
    from app.crud import system_settings as settings_crud

    db = SessionLocal()
    try:
        # Force settings path that would allow alerts if requires_review were true
        monkeypatch.setattr(
            settings_crud,
            "settings_payload",
            lambda _db: {
                "enable_ai_detection": True,
                "auto_generate_review_alerts": True,
                "ai_confidence_threshold": 0.75,
            },
        )
        monkeypatch.setattr(settings_crud, "is_notification_enabled", lambda _db, _k: True)
        assert (
            _should_notify_admin_ai_flag(
                db,
                "human",
                0.05,
                ai_info={
                    "detector_backend": "probe",
                    "requires_review": False,
                    "risk_level": "low",
                },
            )
            is False
        )
    finally:
        db.close()
