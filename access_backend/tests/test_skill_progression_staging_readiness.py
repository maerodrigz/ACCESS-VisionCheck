"""Staging readiness: GET /member/participation contract and skill progression DB fixtures."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401

from app.config import settings
from app.crud import member_milestone as milestone_crud
from app.crud import user as user_crud
from app.database import Base, get_db
from app.models.ai_detection_result import AiDetectionResult
from app.models.enums import RoleName, UserStatus
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.member_ranking import MemberRanking
from app.models.role import Role
from app.models.skill_level import SkillLevel
from app.models.user import User
from app.services import member_milestones as milestone_service
from app.services.skill_evaluation_eligibility import eligible_skill_evaluation_stats
from app.services.skill_progression import build_skill_progression_snapshot
from app.services.skill_progression_grandfather import (
    grandfather_snapshots_complete,
    v2_activation_blocked_reason,
)
from app.services.skill_progression_policy import POLICY_V2
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


@pytest.fixture(autouse=True)
def _stub_evaluations_today_count(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.api.routes.member.media_crud.count_member_evaluations_today",
        lambda _db, _uid: 0,
    )


@pytest.fixture()
def client(db: Session) -> TestClient:
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app, base_url="http://127.0.0.1") as c:
        yield c
    app.dependency_overrides.clear()


def _role(db: Session, name: str) -> Role:
    row = Role(role_name=name)
    db.add(row)
    db.flush()
    return row


def _skill_levels(db: Session) -> None:
    for name in ("Beginner", "Intermediate", "Advanced", "Expert"):
        db.add(SkillLevel(level_name=name))
    db.flush()


def _member(db: Session, email: str = "prog-member@test.local") -> User:
    _skill_levels(db)
    role = _role(db, RoleName.MEMBER)
    beginner = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Beginner"))
    user = User(
        email=email,
        fullname="Progress Member",
        password="hash",
        role_id=role.id,
        status=UserStatus.APPROVED,
        skill_level_id=beginner.id if beginner else None,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    ranking = MemberRanking(user_id=user.id, total_points=100)
    db.add(ranking)
    db.commit()
    return user


def _token(user: User) -> str:
    from app.core.security import create_access_token

    return create_access_token(
        {
            "userId": user.id,
            "name": user.fullname,
            "email": user.email,
            "role": user.role.role_name,
        }
    )


def _practice_eval(
    db: Session,
    user_id: int,
    *,
    overall: float,
    uploaded_at: datetime,
    criteria: dict | None = None,
    review_status: str = "verified_human",
    evaluated_at: datetime | None = None,
) -> None:
    media = MediaFile(
        uploaded_by=user_id,
        file_name="practice.jpg",
        file_type="image/jpeg",
        file_url="https://example.test/p.jpg",
        media_category=MEDIA_CATEGORY_EVALUATION,
        uploaded_at=uploaded_at,
    )
    db.add(media)
    db.flush()
    crit = criteria if criteria is not None else {"member_scores_released": True}
    ev = MediaEvaluation(
        media_id=media.id,
        sharpness_score=overall,
        brightness_score=overall,
        contrast_score=overall,
        blur_score=overall,
        noise_score=overall,
        overall_score=overall,
        criteria_json=json.dumps(crit),
        evaluated_at=evaluated_at or uploaded_at,
    )
    db.add(ev)
    db.add(
        AiDetectionResult(
            media_id=media.id,
            ai_probability=0.05,
            detection_result="human",
            review_status=review_status,
        )
    )
    db.commit()


def _participation(client: TestClient, user: User) -> dict:
    r = client.get(
        "/api/member/participation",
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert r.status_code == 200, r.text
    return r.json()


PARTICIPATION_SKILL_KEYS = {
    "skill_eligible_evaluations_count",
    "skill_eligible_distinct_upload_days",
    "skill_quality_average",
    "skill_computed_tier",
    "skill_effective_tier",
    "skill_computed_tier_v2_preview",
    "skill_next_tier_required_evaluations",
    "skill_next_tier_required_days",
    "skill_remaining_eligible_evaluations",
    "skill_remaining_distinct_upload_days",
    "skill_remaining_quality_points",
    "skill_progression_policy_version",
    "skill_progression_policy_configured",
    "skill_progression_v2_blocked_reason",
}


def test_participation_contract_v1_effective_policy(client: TestClient, db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v1")
    user = _member(db)
    for i in range(3):
        _practice_eval(
            db,
            user.id,
            overall=0.65,
            uploaded_at=datetime(2026, 1, 1 + i, 10, 0, tzinfo=timezone.utc),
        )
    body = _participation(client, user)
    assert PARTICIPATION_SKILL_KEYS.issubset(body.keys())
    assert body["skill_progression_policy_version"] == "v1"
    assert body["skill_progression_policy_configured"] == "v1"
    assert body["skill_progression_v2_blocked_reason"] is None
    assert body["skill_next_tier_required_days"] is None
    assert body["skill_effective_tier"] == "Intermediate"
    assert body["daily_evaluation_limit"] == 3


def test_participation_contract_v2_isolated_when_ready(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    assert ranking is not None
    ranking.skill_tier_grandfather_floor = "Beginner"
    db.commit()
    base = datetime(2026, 2, 1, 10, 0, tzinfo=timezone.utc)
    for i in range(2):
        _practice_eval(
            db,
            user.id,
            overall=0.65,
            uploaded_at=base + timedelta(days=i),
        )
    body = _participation(client, user)
    assert body["skill_progression_policy_version"] == "v2"
    assert body["skill_progression_policy_configured"] == "v2"
    assert body["skill_progression_v2_blocked_reason"] is None
    assert body["skill_effective_tier"] == "Beginner"
    assert body["skill_next_tier_required_days"] == 2
    assert body["skill_next_tier_required_evaluations"] == 3


def test_participation_configured_v2_blocked_without_snapshots(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db)
    body = _participation(client, user)
    assert body["skill_progression_policy_configured"] == "v2"
    assert body["skill_progression_policy_version"] == "v1"
    assert body["skill_progression_v2_blocked_reason"] is not None
    assert "grandfather" in body["skill_progression_v2_blocked_reason"].lower()


def test_participation_backward_compat_defaults(client: TestClient, db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v1")
    user = _member(db)
    body = _participation(client, user)
    assert body["skill_computed_tier"] == "Beginner"
    assert body["skill_remaining_distinct_upload_days"] == 0
    assert body["skill_next_tier_required_evaluations"] == 3
    assert "total_points" in body
    assert "evaluations_today" in body


def test_grandfathered_advanced_member_v2_floor(db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    assert ranking is not None
    ranking.skill_tier_grandfather_floor = "Advanced"
    db.commit()
    for i in range(5):
        _practice_eval(
            db,
            user.id,
            overall=0.78,
            uploaded_at=datetime(2026, 3, 1 + i, 12, 0, tzinfo=timezone.utc),
        )
    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_v1 == "Intermediate"
    assert snap.computed_tier_v2 == "Advanced"
    assert snap.effective_tier == "Advanced"


def test_grandfathered_expert_quality_drop_not_floored(db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    assert ranking is not None
    ranking.skill_tier_grandfather_floor = "Expert"
    db.commit()
    _practice_eval(
        db,
        user.id,
        overall=0.55,
        uploaded_at=datetime(2026, 4, 1, 8, 0, tzinfo=timezone.utc),
    )
    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_v2 == "Beginner"
    assert snap.effective_tier == "Beginner"


def test_admin_downward_override_precedence(db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    assert ranking is not None
    ranking.skill_tier_grandfather_floor = "Expert"
    ranking.competency_level_override = "Intermediate"
    db.commit()
    for i in range(12):
        _practice_eval(
            db,
            user.id,
            overall=0.92,
            uploaded_at=datetime(2026, 5, 1 + (i % 10), 9, 0, tzinfo=timezone.utc),
        )
    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_v2 == "Expert"
    assert snap.effective_tier == "Intermediate"
    assert snap.admin_override == "Intermediate"


def test_pending_and_withheld_evaluations_excluded(db: Session) -> None:
    user = _member(db)
    _practice_eval(
        db,
        user.id,
        overall=0.9,
        uploaded_at=datetime(2026, 6, 1, 10, 0, tzinfo=timezone.utc),
        criteria={"member_scores_released": False},
        review_status="needs_further_review",
    )
    _practice_eval(
        db,
        user.id,
        overall=0.9,
        uploaded_at=datetime(2026, 6, 2, 10, 0, tzinfo=timezone.utc),
        review_status="pending_review",
    )
    _practice_eval(
        db,
        user.id,
        overall=0.9,
        uploaded_at=datetime(2026, 6, 3, 10, 0, tzinfo=timezone.utc),
        review_status="confirmed_ai_generated",
    )
    stats = eligible_skill_evaluation_stats(db, user.id)
    assert stats.count == 0
    assert stats.distinct_upload_days == 0


def test_manila_upload_day_uses_uploaded_at_not_evaluated_at(db: Session) -> None:
    user = _member(db)
    upload_utc = datetime(2026, 6, 1, 18, 30, tzinfo=timezone.utc)
    eval_late = datetime(2026, 6, 5, 12, 0, tzinfo=timezone.utc)
    _practice_eval(
        db,
        user.id,
        overall=0.7,
        uploaded_at=upload_utc,
        evaluated_at=eval_late,
    )
    with patch.object(settings, "evaluation_daily_timezone", "Asia/Manila"):
        stats = eligible_skill_evaluation_stats(db, user.id)
    assert stats.count == 1
    assert stats.distinct_upload_days == 1


def test_grandfather_snapshots_complete_after_floor(db: Session) -> None:
    user = _member(db)
    assert grandfather_snapshots_complete(db) is False
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    ranking.skill_tier_grandfather_floor = "Beginner"
    db.commit()
    assert grandfather_snapshots_complete(db) is True
    assert v2_activation_blocked_reason(db) is None


def test_override_member_earned_floor_snapshot(db: Session) -> None:
    user = _member(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    ranking.competency_level_override = "Beginner"
    db.commit()
    for i in range(10):
        _practice_eval(
            db,
            user.id,
            overall=0.92,
            uploaded_at=datetime(2026, 7, 1 + i, 10, 0, tzinfo=timezone.utc),
        )
    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_v1 == "Expert"
    assert snap.effective_tier == "Beginner"
    ranking.skill_tier_grandfather_floor = snap.computed_tier_v1
    db.commit()
    monkeypatch_policy = patch(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        return_value=POLICY_V2,
    )
    with monkeypatch_policy:
        snap2 = build_skill_progression_snapshot(db, user.id)
    assert snap2.grandfather_floor == "Expert"
    assert snap2.effective_tier == "Beginner"


def test_tier_milestone_no_duplicate_on_recalc(db: Session) -> None:
    user = _member(db)
    with patch.object(milestone_service, "_award") as award:
        milestone_service.on_skill_level_recalculated(
            db,
            user.id,
            old_level="Intermediate",
            new_level="Intermediate",
            old_computed_tier="Intermediate",
            new_computed_tier="Intermediate",
        )
        award.assert_not_called()
    row = milestone_crud.create_if_new(
        db,
        user.id,
        milestone_kind="skill_tier",
        milestone_key="Advanced",
        title="Skill tier: Advanced",
        message="Once",
    )
    db.commit()
    assert row is not None
    dup = milestone_crud.create_if_new(
        db,
        user.id,
        milestone_kind="skill_tier",
        milestone_key="Advanced",
        title="Skill tier: Advanced",
        message="Twice",
    )
    assert dup is None


def test_recalc_milestone_only_on_computed_change(db: Session) -> None:
    user = _member(db)
    with patch.object(milestone_service, "_award") as award:
        milestone_service.on_skill_level_recalculated(
            db,
            user.id,
            old_level="Beginner",
            new_level="Expert",
            old_computed_tier="Beginner",
            new_computed_tier="Beginner",
        )
        award.assert_not_called()


def test_stored_skill_level_id_can_differ_until_recalc(db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v1")
    user = _member(db)
    for i in range(6):
        _practice_eval(
            db,
            user.id,
            overall=0.8,
            uploaded_at=datetime(2026, 8, 1 + i, 10, 0, tzinfo=timezone.utc),
        )
    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_active == "Advanced"
    assert user.skill_level.level_name == "Beginner"
    user_loaded = user_crud.get_by_id(db, user.id)
    assert user_loaded is not None
    assert user_loaded.skill_level.level_name == "Beginner"


def _set_grandfather_floor(db: Session, user_id: int, floor: str = "Beginner") -> None:
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user_id))
    assert ranking is not None
    ranking.skill_tier_grandfather_floor = floor
    db.commit()


def test_tier_fields_carlos_strict_v2_beginner_grandfather_intermediate(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db, email="carlos-like@test.local")
    _set_grandfather_floor(db, user.id, "Intermediate")
    base = datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc)
    for i in range(3):
        _practice_eval(db, user.id, overall=0.81, uploaded_at=base.replace(hour=10 + i))

    snap = build_skill_progression_snapshot(db, user.id)
    assert snap.computed_tier_v2_raw == "Beginner"
    assert snap.computed_tier_v2 == "Intermediate"
    assert snap.effective_tier == "Intermediate"

    body = _participation(client, user)
    assert body["skill_computed_tier_v2_strict"] == "Beginner"
    assert body["skill_computed_tier_v2_grandfather_adjusted"] == "Intermediate"
    assert body["skill_effective_tier"] == "Intermediate"
    assert body["skill_next_tier_required_evaluations"] == 12
    assert body["skill_next_tier_required_days"] == 10


def test_tier_fields_admin_override_beats_grandfather(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db, email="override@test.local")
    _set_grandfather_floor(db, user.id, "Advanced")
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    assert ranking is not None
    ranking.competency_level_override = "Intermediate"
    db.commit()

    body = _participation(client, user)
    assert body["skill_admin_competency_override"] == "Intermediate"
    assert body["skill_effective_tier"] == "Intermediate"


def test_tier_fields_stored_legacy_exposed(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db, email="stale-stored@test.local")
    _set_grandfather_floor(db, user.id, "Beginner")
    expert = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Expert"))
    assert expert is not None
    user.skill_level_id = expert.id
    db.commit()

    body = _participation(client, user)
    assert body["skill_tier_stored_legacy"] == "Expert"
    assert body["skill_effective_tier"] == "Beginner"


def test_profile_effective_tier_matches_participation(
    client: TestClient, db: Session, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v2")
    user = _member(db, email="profile-sync@test.local")
    _set_grandfather_floor(db, user.id, "Beginner")
    expert = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Expert"))
    assert expert is not None
    user.skill_level_id = expert.id
    db.commit()

    part = _participation(client, user)
    prof = client.get(
        "/api/member/profile",
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert prof.status_code == 200, prof.text
    body = prof.json()
    assert body["skill_effective_tier"] == part["skill_effective_tier"]
    assert body["skill_level"] == part["skill_effective_tier"]
    assert body["skill_tier_stored_legacy"] == "Expert"
    assert body["skill_effective_tier"] == "Beginner"


def test_tier_fields_v1_additive_keys(client: TestClient, db: Session, monkeypatch) -> None:
    monkeypatch.setattr(settings, "skill_progression_active_policy", "v1")
    user = _member(db, email="v1-fields@test.local")
    body = _participation(client, user)
    assert body["skill_computed_tier"] == body["skill_computed_tier_v1"]
    assert body["skill_computed_tier_v2_preview"] == body["skill_computed_tier_v2_grandfather_adjusted"]
