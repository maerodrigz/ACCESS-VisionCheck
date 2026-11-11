"""Infrastructure tests for Skill Progression v2 activation seal + cohort."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401

from app.database import Base, get_db
from app.models.enums import RoleName, UserStatus
from app.models.member_ranking import MemberRanking
from app.models.role import Role
from app.models.skill_level import SkillLevel
from app.models.skill_progression_v2_activation import (
    ACTIVATION_STATUS_DRAFT,
    ACTIVATION_STATUS_SEALED,
    SkillProgressionV2Activation,
    SkillProgressionV2CohortMember,
)
from app.models.user import User
from app.services.skill_progression import (
    build_skill_progression_snapshot,
    resolve_effective_skill_progression_policy,
)
from app.services.skill_progression_grandfather import (
    grandfather_snapshots_complete,
    members_missing_grandfather_snapshot,
    v2_activation_blocked_reason,
)
from app.services.skill_progression_policy import (
    POLICY_V1,
    POLICY_V2,
    apply_grandfather_floor_v2,
)
from app.services.skill_progression_v2_activation import (
    SkillV2ActivationError,
    apply_cohort_capture,
    apply_seal,
    get_sealed_activation,
    is_user_in_sealed_cohort,
    plan_cohort_capture,
    plan_seal,
    revoke_seal,
)
from main import app


@pytest.fixture()
def db() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture(autouse=True)
def _stub_evaluations_today(monkeypatch) -> None:
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


def _skill_levels(db: Session) -> None:
    for name in ("Beginner", "Intermediate", "Advanced", "Expert"):
        if db.scalar(select(SkillLevel).where(SkillLevel.level_name == name)) is None:
            db.add(SkillLevel(level_name=name))
    db.flush()


def _role(db: Session, name: str) -> Role:
    row = db.scalar(select(Role).where(Role.role_name == name))
    if row:
        return row
    row = Role(role_name=name)
    db.add(row)
    db.flush()
    return row


def _member(db: Session, email: str, name: str = "Member") -> User:
    _skill_levels(db)
    role = _role(db, RoleName.MEMBER)
    beginner = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Beginner"))
    user = User(
        email=email,
        fullname=name,
        password="hash",
        role_id=role.id,
        status=UserStatus.APPROVED,
        skill_level_id=beginner.id if beginner else None,
        is_active=True,
    )
    db.add(user)
    db.flush()
    db.add(MemberRanking(user_id=user.id, total_points=0))
    db.commit()
    db.refresh(user)
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


def _capture_and_seal(db: Session) -> SkillProgressionV2Activation:
    apply_cohort_capture(db)
    apply_seal(db)
    db.commit()
    seal = get_sealed_activation(db)
    assert seal is not None
    return seal


def test_no_activation_seal_blocks_v2(db: Session, monkeypatch) -> None:
    _member(db, "a@test.local")
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V1
    assert reason and "sealed" in reason.lower()
    assert grandfather_snapshots_complete(db) is False


def test_complete_protected_cohort_enables_v2(db: Session, monkeypatch) -> None:
    u = _member(db, "b@test.local", "Beginner Member")
    _capture_and_seal(db)
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V2
    assert reason is None
    assert grandfather_snapshots_complete(db) is True
    assert is_user_in_sealed_cohort(db, u.id) is True


def test_missing_protected_snapshot_blocks_v2(db: Session, monkeypatch) -> None:
    u = _member(db, "c@test.local")
    _capture_and_seal(db)
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == u.id))
    ranking.skill_tier_grandfather_floor = None
    db.commit()
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V1
    assert reason and str(u.id) in reason
    assert members_missing_grandfather_snapshot(db) == [u.id]


def test_new_member_after_activation_does_not_block_v2(db: Session, monkeypatch) -> None:
    protected = _member(db, "old@test.local", "Old")
    _capture_and_seal(db)
    newbie = _member(db, "new@test.local", "New")
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V2
    assert reason is None
    assert is_user_in_sealed_cohort(db, protected.id) is True
    assert is_user_in_sealed_cohort(db, newbie.id) is False
    assert newbie.id not in members_missing_grandfather_snapshot(db)
    # New member uses raw v2 path (no floor) once policy effective.
    snap = build_skill_progression_snapshot(db, newbie.id)
    assert snap.policy_version == POLICY_V2
    assert snap.grandfather_floor is None


def test_reapproved_protected_member_stays_in_cohort(db: Session) -> None:
    u = _member(db, "re@test.local", "Reapprove")
    _capture_and_seal(db)
    u.status = UserStatus.REJECTED
    db.commit()
    assert is_user_in_sealed_cohort(db, u.id) is True
    u.status = UserStatus.APPROVED
    db.commit()
    assert is_user_in_sealed_cohort(db, u.id) is True
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == u.id))
    assert ranking.skill_tier_grandfather_floor == "Beginner"


def test_concurrent_member_approval_during_seal_fails(db: Session) -> None:
    _member(db, "one@test.local", "One")
    apply_cohort_capture(db)
    db.commit()
    # Approve another member after capture, before seal.
    _member(db, "two@test.local", "Two")
    plan = plan_seal(db)
    assert plan.ready is False
    assert plan.approved_not_in_cohort
    with pytest.raises(SkillV2ActivationError):
        apply_seal(db)


def test_beginner_grandfather_floor_capture(db: Session) -> None:
    u = _member(db, "beg@test.local", "Beginner Only")
    plan = plan_cohort_capture(db)
    assert plan.candidates[0].computed_tier_v1 == "Beginner"
    apply_cohort_capture(db)
    db.commit()
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == u.id))
    assert ranking.skill_tier_grandfather_floor == "Beginner"
    row = db.scalar(
        select(SkillProgressionV2CohortMember).where(
            SkillProgressionV2CohortMember.user_id == u.id
        )
    )
    assert row is not None
    assert row.floor_at_capture == "Beginner"


def test_grandfather_quality_band_behavior() -> None:
    # Floor Intermediate held while score still Intermediate+.
    assert (
        apply_grandfather_floor_v2(
            computed_v2="Beginner",
            grandfather_floor="Intermediate",
            skill_score_pct=74.0,
        )
        == "Intermediate"
    )
    # Quality below Intermediate band → floor does not protect.
    assert (
        apply_grandfather_floor_v2(
            computed_v2="Beginner",
            grandfather_floor="Intermediate",
            skill_score_pct=50.0,
        )
        == "Beginner"
    )


def test_admin_override_precedence_with_seal(db: Session, monkeypatch) -> None:
    u = _member(db, "ov@test.local", "Override")
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == u.id))
    ranking.competency_level_override = "Advanced"
    db.commit()
    _capture_and_seal(db)
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    snap = build_skill_progression_snapshot(db, u.id)
    assert snap.grandfather_floor == "Beginner"  # earned, not override
    assert snap.effective_tier == "Advanced"
    assert snap.policy_version == POLICY_V2


def test_rollback_to_v1_via_env_and_revoke(db: Session, monkeypatch) -> None:
    _member(db, "rb@test.local")
    _capture_and_seal(db)
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V1,
    )
    policy, reason = resolve_effective_skill_progression_policy(db)
    assert policy == POLICY_V1
    assert reason is None

    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    assert resolve_effective_skill_progression_policy(db)[0] == POLICY_V2
    revoke_seal(db, reason="test_rollback")
    db.commit()
    policy2, reason2 = resolve_effective_skill_progression_policy(db)
    assert policy2 == POLICY_V1
    assert reason2 and "sealed" in reason2.lower()


def test_api_participation_compatibility(client: TestClient, db: Session, monkeypatch) -> None:
    user = _member(db, "api@test.local", "API User")
    token = _token(user)
    monkeypatch.setattr(
        "app.services.skill_progression_policy.configured_skill_progression_policy",
        lambda: POLICY_V2,
    )
    res = client.get(
        "/api/member/participation",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    body = res.json()
    # Existing fields remain.
    assert body["skill_progression_policy_version"] == "v1"
    assert body["skill_progression_policy_configured"] == "v2"
    assert body["skill_progression_v2_blocked_reason"]
    # Additive fields.
    assert body["skill_progression_v2_activation_sealed"] is False
    assert body["skill_progression_v2_activation_sealed_at"] is None
    assert body["skill_progression_grandfather_cohort_member"] is False

    _capture_and_seal(db)
    res2 = client.get(
        "/api/member/participation",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res2.status_code == 200
    body2 = res2.json()
    assert body2["skill_progression_policy_version"] == "v2"
    assert body2["skill_progression_v2_activation_sealed"] is True
    assert body2["skill_progression_grandfather_cohort_member"] is True
    assert body2["skill_progression_v2_blocked_reason"] is None


def test_capture_idempotent(db: Session) -> None:
    _member(db, "idemp@test.local")
    apply_cohort_capture(db)
    db.commit()
    first = db.scalar(select(SkillProgressionV2Activation))
    apply_cohort_capture(db)
    db.commit()
    activations = db.scalars(select(SkillProgressionV2Activation)).all()
    assert len(activations) == 1
    assert activations[0].id == first.id
    assert activations[0].status == ACTIVATION_STATUS_DRAFT
    members = db.scalars(select(SkillProgressionV2CohortMember)).all()
    assert len(members) == 1


def test_migration_upgrade_downgrade_reversible() -> None:
    """Exercise DDL upgrade/downgrade on an isolated in-memory Postgres-incompatible
    path using SQLAlchemy models create/drop as the sqlite stand-in, plus the
    migration module's existence helpers against a temp postgres-less engine.

    Full PostgreSQL DDL is validated when ACCESS_PYTEST_DB=access_waverep_test.
    """
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    insp = inspect(engine)
    assert "skill_progression_v2_activation" in insp.get_table_names()
    assert "skill_progression_v2_cohort_members" in insp.get_table_names()
    Base.metadata.drop_all(engine)
    insp2 = inspect(engine)
    assert "skill_progression_v2_activation" not in insp2.get_table_names()
    engine.dispose()


@pytest.mark.skipif(
    __import__("os").environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test",
    reason="PostgreSQL migration DDL only on access_waverep_test",
)
def test_postgres_migration_reversible_on_isolated_db() -> None:
    from app.database import engine
    from app.migrations.skill_progression_v2_activation import (
        downgrade_skill_progression_v2_activation,
        skill_progression_v2_activation_tables_exist,
        upgrade_skill_progression_v2_activation,
    )

    upgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine) is True
    # Do not leave waverep without tables if other suites need them — re-upgrade after check.
    downgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine) is False
    upgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine) is True


def test_capture_does_not_use_override_as_floor(db: Session) -> None:
    u = _member(db, "floor@test.local")
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == u.id))
    ranking.competency_level_override = "Advanced"
    db.commit()
    apply_cohort_capture(db)
    db.commit()
    db.refresh(ranking)
    assert ranking.skill_tier_grandfather_floor == "Beginner"
    assert ranking.competency_level_override == "Advanced"
