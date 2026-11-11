"""PostgreSQL concurrency regression for v2 activation seal vs Member approval.

Requires ACCESS_PYTEST_DB=access_waverep_test (isolated DB). Uses separate sessions
and Event barriers — not sleep-only timing.
"""

from __future__ import annotations

import os
import threading
import time
import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401

from app.crud import user as user_crud
from app.migrations.isolated_test_database_url import isolated_test_database_url
from app.migrations.skill_progression_v2_activation import (
    skill_progression_v2_activation_tables_exist,
    upgrade_skill_progression_v2_activation,
)
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
from app.services import skill_progression_activation_coord as coord
from app.services.skill_progression_v2_activation import (
    SkillV2ActivationError,
    apply_seal,
    get_sealed_activation,
    is_user_in_sealed_cohort,
    plan_seal,
)

pytestmark = pytest.mark.skipif(
    os.environ.get("ACCESS_PYTEST_DB", "").strip() != "access_waverep_test",
    reason="Seal concurrency tests require isolated PostgreSQL access_waverep_test",
)

_MARKER = "v2seal_conc_"


@pytest.fixture()
def pg_engine():
    url = isolated_test_database_url()
    engine = create_engine(url, pool_pre_ping=True, pool_size=8, max_overflow=4)
    if not skill_progression_v2_activation_tables_exist(engine):
        upgrade_skill_progression_v2_activation(engine)
    yield engine
    engine.dispose()


@pytest.fixture()
def SessionLocal(pg_engine):
    return sessionmaker(autocommit=False, autoflush=False, bind=pg_engine)


@pytest.fixture(autouse=True)
def _clear_hook():
    coord.set_after_acquire_hook_for_tests(None)
    yield
    coord.set_after_acquire_hook_for_tests(None)


@pytest.fixture()
def clean_db(SessionLocal):
    db = SessionLocal()
    try:
        _cleanup(db)
        yield SessionLocal
    finally:
        try:
            _cleanup(db)
        except Exception:
            db.rollback()
        db.close()


def _cleanup(db: Session) -> None:
    emails = db.scalars(select(User.email).where(User.email.like(f"{_MARKER}%"))).all()
    if not emails:
        # Still drop fixture activations tagged in notes
        db.execute(
            text(
                "DELETE FROM skill_progression_v2_cohort_members WHERE activation_id IN "
                "(SELECT id FROM skill_progression_v2_activation WHERE notes LIKE :p)"
            ),
            {"p": f"%{_MARKER}%"},
        )
        db.execute(
            text("DELETE FROM skill_progression_v2_activation WHERE notes LIKE :p"),
            {"p": f"%{_MARKER}%"},
        )
        db.commit()
        return

    user_ids = list(
        db.scalars(select(User.id).where(User.email.like(f"{_MARKER}%"))).all()
    )
    if user_ids:
        db.execute(
            text(
                "DELETE FROM skill_progression_v2_cohort_members WHERE user_id = ANY(:ids)"
            ),
            {"ids": user_ids},
        )
        db.execute(
            text("DELETE FROM member_rankings WHERE user_id = ANY(:ids)"),
            {"ids": user_ids},
        )
        db.execute(text("DELETE FROM users WHERE id = ANY(:ids)"), {"ids": user_ids})
    db.execute(
        text(
            "DELETE FROM skill_progression_v2_cohort_members WHERE activation_id IN "
            "(SELECT id FROM skill_progression_v2_activation WHERE notes LIKE :p)"
        ),
        {"p": f"%{_MARKER}%"},
    )
    db.execute(
        text("DELETE FROM skill_progression_v2_activation WHERE notes LIKE :p"),
        {"p": f"%{_MARKER}%"},
    )
    db.commit()


def _ensure_role_skill(db: Session) -> tuple[int, int]:
    role = db.scalar(select(Role).where(Role.role_name == RoleName.MEMBER))
    if role is None:
        role = Role(role_name=RoleName.MEMBER)
        db.add(role)
        db.flush()
    beginner = db.scalar(select(SkillLevel).where(SkillLevel.level_name == "Beginner"))
    if beginner is None:
        beginner = SkillLevel(level_name="Beginner")
        db.add(beginner)
        db.flush()
    db.commit()
    return role.id, beginner.id


def _email(label: str) -> str:
    return f"{_MARKER}{label}_{uuid.uuid4().hex[:10]}@test.local"


def _make_member(
    db: Session,
    *,
    role_id: int,
    skill_id: int,
    label: str,
    status: str = UserStatus.APPROVED,
    floor: str | None = "Beginner",
) -> User:
    user = User(
        email=_email(label),
        fullname=label,
        password="hash",
        role_id=role_id,
        skill_level_id=skill_id,
        status=status,
        is_active=True,
        approved_at=datetime.now(timezone.utc) if status == UserStatus.APPROVED else None,
    )
    db.add(user)
    db.flush()
    ranking = MemberRanking(user_id=user.id, total_points=0)
    if floor:
        ranking.skill_tier_grandfather_floor = floor
    db.add(ranking)
    db.commit()
    db.refresh(user)
    return user


def _revoke_any_seal(db: Session) -> None:
    """Clear sealed/draft activations so plan_seal can succeed on waverep fixtures."""
    db.execute(text("DELETE FROM skill_progression_v2_cohort_members"))
    db.execute(text("DELETE FROM skill_progression_v2_activation"))
    db.commit()


def _all_approved_members(db: Session) -> list[User]:
    return list(
        db.scalars(
            select(User)
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
            .order_by(User.id)
        ).all()
    )


def _ensure_floor(db: Session, user: User, floor: str = "Beginner") -> MemberRanking:
    ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user.id))
    if ranking is None:
        ranking = MemberRanking(user_id=user.id, total_points=0)
        db.add(ranking)
        db.flush()
    if not ranking.skill_tier_grandfather_floor:
        ranking.skill_tier_grandfather_floor = floor
    return ranking


def _enroll_draft(db: Session, members: list[User], *, notes: str) -> int:
    """Enroll fixture members plus every other approved Member (waverep may have seeds)."""
    _revoke_any_seal(db)
    # Ensure requested fixtures are included; expand to full approved set for seal readiness.
    by_id = {u.id: u for u in members}
    for u in _all_approved_members(db):
        by_id.setdefault(u.id, u)
    cohort = list(by_id.values())

    draft = SkillProgressionV2Activation(
        status=ACTIVATION_STATUS_DRAFT,
        cohort_member_count=0,
        notes=notes,
    )
    db.add(draft)
    db.flush()
    now = datetime.now(timezone.utc)
    for user in cohort:
        ranking = _ensure_floor(db, user)
        db.add(
            SkillProgressionV2CohortMember(
                activation_id=draft.id,
                user_id=user.id,
                ranking_id=ranking.id,
                floor_at_capture=str(ranking.skill_tier_grandfather_floor),
                captured_at=now,
            )
        )
    draft.cohort_member_count = len(cohort)
    db.commit()
    plan = plan_seal(db)
    assert plan.ready, plan.blocked_reason
    return int(draft.id)


def test_1_approval_commits_before_seal_begins(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A1")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P1", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t1")
    pending_id = pending.id
    setup.close()

    s_approve = SessionLocal()
    pend = s_approve.get(User, pending_id)
    assert pend is not None
    # Ensure role relationship for update_status
    _ = pend.role
    user_crud.update_status(s_approve, pend, UserStatus.APPROVED)
    s_approve.close()

    s_seal = SessionLocal()
    with pytest.raises(SkillV2ActivationError) as exc:
        apply_seal(s_seal, notes=f"{_MARKER}t1-seal")
    assert "not in draft cohort" in str(exc.value).lower() or "re-run capture" in str(exc.value).lower()
    s_seal.rollback()
    s_seal.close()


def test_2_approval_starts_during_seal_validation(clean_db) -> None:
    """Approval blocked while seal holds coord lock; after seal, member is outside cohort."""
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A2")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P2", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t2")
    pending_id = int(pending.id)
    setup.close()

    seal_locked = threading.Event()
    allow_seal_continue = threading.Event()
    approve_started = threading.Event()
    approve_done = threading.Event()
    errors: list[BaseException] = []
    seal_ok = {"done": False}

    def after_acquire(_db: Session) -> None:
        seal_locked.set()
        assert allow_seal_continue.wait(timeout=10), "seal continue timeout"

    coord.set_after_acquire_hook_for_tests(after_acquire)

    def run_seal() -> None:
        s = SessionLocal()
        try:
            apply_seal(s, notes=f"{_MARKER}t2-seal")
            s.commit()
            seal_ok["done"] = True
        except BaseException as exc:  # noqa: BLE001
            s.rollback()
            errors.append(exc)
        finally:
            s.close()

    def run_approve() -> None:
        assert seal_locked.wait(timeout=10)
        approve_started.set()
        s = SessionLocal()
        try:
            pend = s.get(User, pending_id)
            assert pend is not None
            _ = pend.role
            # Blocks on advisory lock until seal commits/rolls back.
            user_crud.update_status(s, pend, UserStatus.APPROVED)
            approve_done.set()
        except BaseException as exc:  # noqa: BLE001
            s.rollback()
            errors.append(exc)
        finally:
            s.close()

    t_seal = threading.Thread(target=run_seal, name="seal")
    t_approve = threading.Thread(target=run_approve, name="approve")
    t_seal.start()
    assert seal_locked.wait(timeout=10)
    t_approve.start()
    assert approve_started.wait(timeout=10)
    # While seal holds lock, approval must not finish.
    time.sleep(0.3)
    assert not approve_done.is_set()
    allow_seal_continue.set()
    t_seal.join(timeout=15)
    t_approve.join(timeout=15)
    assert not errors, errors
    assert seal_ok["done"]
    assert approve_done.is_set()

    check = SessionLocal()
    assert get_sealed_activation(check) is not None
    assert is_user_in_sealed_cohort(check, pending_id) is False
    check.close()


def test_3_toctou_approval_between_validate_and_update_blocked(clean_db) -> None:
    """Former failing reproduction: approval cannot sneak in after validate before UPDATE."""
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A3")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P3", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t3")
    pending_id = int(pending.id)
    setup.close()

    after_validate = threading.Event()
    allow_update = threading.Event()
    approve_done = threading.Event()
    errors: list[BaseException] = []

    original_plan = plan_seal
    call_count = {"n": 0}

    def plan_with_barrier(db: Session):
        plan = original_plan(db)
        call_count["n"] += 1
        # Second plan_seal in apply_seal is the under-lock revalidate.
        if call_count["n"] >= 2 and plan.ready:
            after_validate.set()
            assert allow_update.wait(timeout=10), "update continue timeout"
        return plan

    import app.services.skill_progression_v2_activation as act

    act.plan_seal = plan_with_barrier  # type: ignore[assignment]
    try:
        def run_seal() -> None:
            s = SessionLocal()
            try:
                apply_seal(s, notes=f"{_MARKER}t3-seal")
                s.commit()
            except BaseException as exc:  # noqa: BLE001
                s.rollback()
                errors.append(exc)
            finally:
                s.close()

        def run_approve() -> None:
            assert after_validate.wait(timeout=10)
            s = SessionLocal()
            try:
                pend = s.get(User, pending_id)
                assert pend is not None
                _ = pend.role
                user_crud.update_status(s, pend, UserStatus.APPROVED)
                approve_done.set()
            except BaseException as exc:  # noqa: BLE001
                s.rollback()
                errors.append(exc)
            finally:
                s.close()

        t_seal = threading.Thread(target=run_seal)
        t_approve = threading.Thread(target=run_approve)
        t_seal.start()
        assert after_validate.wait(timeout=10)
        t_approve.start()
        time.sleep(0.4)
        # Critical: approval must still be blocked while seal holds lock post-validate.
        assert not approve_done.is_set(), "TOCTOU regression: approval committed during seal window"
        allow_update.set()
        t_seal.join(timeout=15)
        t_approve.join(timeout=15)
        assert not errors, errors
        assert approve_done.is_set()
    finally:
        act.plan_seal = original_plan  # type: ignore[assignment]

    check = SessionLocal()
    seal = get_sealed_activation(check)
    assert seal is not None and seal.status == ACTIVATION_STATUS_SEALED
    assert is_user_in_sealed_cohort(check, pending_id) is False
    # Newly approved after seal is not grandfathered into cohort.
    check.close()


def test_4_seal_commits_before_new_approval(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A4")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P4", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t4")
    pending_id = int(pending.id)
    setup.close()

    s_seal = SessionLocal()
    apply_seal(s_seal, notes=f"{_MARKER}t4-seal")
    s_seal.commit()
    s_seal.close()

    s_approve = SessionLocal()
    pend = s_approve.get(User, pending_id)
    assert pend is not None
    _ = pend.role
    user_crud.update_status(s_approve, pend, UserStatus.APPROVED)
    s_approve.close()

    check = SessionLocal()
    assert is_user_in_sealed_cohort(check, pending_id) is False
    check.close()


def test_5_two_concurrent_seal_attempts(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A5")
    _enroll_draft(setup, [a], notes=f"{_MARKER}t5")
    setup.close()

    first_locked = threading.Event()
    allow_first = threading.Event()
    results: list[str] = []
    lock = threading.Lock()

    def after_acquire(_db: Session) -> None:
        # Only the first acquirer should pause; second blocks on DB lock.
        if not first_locked.is_set():
            first_locked.set()
            assert allow_first.wait(timeout=10)

    coord.set_after_acquire_hook_for_tests(after_acquire)

    def run(label: str) -> None:
        s = SessionLocal()
        try:
            apply_seal(s, notes=f"{_MARKER}t5-{label}")
            s.commit()
            with lock:
                results.append(f"{label}:ok")
        except SkillV2ActivationError as exc:
            s.rollback()
            with lock:
                results.append(f"{label}:err:{exc}")
        except BaseException as exc:  # noqa: BLE001
            s.rollback()
            with lock:
                results.append(f"{label}:boom:{exc}")
        finally:
            s.close()

    t1 = threading.Thread(target=run, args=("one",))
    t2 = threading.Thread(target=run, args=("two",))
    t1.start()
    assert first_locked.wait(timeout=10)
    t2.start()
    time.sleep(0.3)
    allow_first.set()
    t1.join(timeout=15)
    t2.join(timeout=15)

    oks = [r for r in results if r.endswith(":ok")]
    errs = [r for r in results if ":err:" in r or ":boom:" in r]
    assert len(oks) == 1, results
    assert len(errs) == 1, results

    check = SessionLocal()
    seals = list(
        check.scalars(
            select(SkillProgressionV2Activation).where(
                SkillProgressionV2Activation.status == ACTIVATION_STATUS_SEALED,
                SkillProgressionV2Activation.notes.like(f"%{_MARKER}t5%"),
            )
        )
    )
    assert len(seals) == 1
    check.close()


def test_6_approval_transaction_rollback(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A6")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P6", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t6")
    pending_id = int(pending.id)
    setup.close()

    s_approve = SessionLocal()
    pend = s_approve.get(User, pending_id)
    assert pend is not None
    _ = pend.role
    coord.acquire_member_approval_seal_coordination_lock(s_approve)
    pend.status = UserStatus.APPROVED
    s_approve.flush()
    s_approve.rollback()
    s_approve.close()

    s_seal = SessionLocal()
    apply_seal(s_seal, notes=f"{_MARKER}t6-seal")
    s_seal.commit()
    assert is_user_in_sealed_cohort(s_seal, pending_id) is False
    # pending still pending
    pend2 = s_seal.get(User, pending_id)
    assert pend2 is not None and pend2.status == UserStatus.PENDING
    s_seal.close()


def test_7_seal_transaction_rollback(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A7")
    pending = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="P7", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t7")
    pending_id = int(pending.id)
    setup.close()

    s_seal = SessionLocal()
    apply_seal(s_seal, notes=f"{_MARKER}t7-seal")
    s_seal.rollback()
    s_seal.close()

    check = SessionLocal()
    assert get_sealed_activation(check) is None
    draft = check.scalar(
        select(SkillProgressionV2Activation).where(
            SkillProgressionV2Activation.status == ACTIVATION_STATUS_DRAFT,
            SkillProgressionV2Activation.notes.like(f"%{_MARKER}t7%"),
        )
    )
    assert draft is not None

    # Approval after rolled-back seal should still serialize cleanly, then seal can succeed
    # only if cohort matches — approval of pending will block seal.
    pend = check.get(User, pending_id)
    assert pend is not None
    _ = pend.role
    user_crud.update_status(check, pend, UserStatus.APPROVED)
    check.close()

    s2 = SessionLocal()
    with pytest.raises(SkillV2ActivationError):
        apply_seal(s2, notes=f"{_MARKER}t7-seal2")
    s2.rollback()
    s2.close()


def test_8_reapproval_of_grandfathered_member(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A8", floor="Intermediate")
    _enroll_draft(setup, [a], notes=f"{_MARKER}t8")
    aid = int(a.id)
    floor_before = setup.scalar(
        select(MemberRanking.skill_tier_grandfather_floor).where(MemberRanking.user_id == aid)
    )
    setup.close()

    s = SessionLocal()
    apply_seal(s, notes=f"{_MARKER}t8-seal")
    s.commit()
    user = s.get(User, aid)
    assert user is not None
    _ = user.role
    user_crud.update_status(s, user, UserStatus.REJECTED, rejection_reason="temp")
    user = s.get(User, aid)
    assert user is not None
    _ = user.role
    user_crud.update_status(s, user, UserStatus.APPROVED)
    assert is_user_in_sealed_cohort(s, aid) is True
    floor_after = s.scalar(
        select(MemberRanking.skill_tier_grandfather_floor).where(MemberRanking.user_id == aid)
    )
    assert floor_after == floor_before == "Intermediate"
    s.close()


def test_9_multiple_approval_entry_points(clean_db) -> None:
    SessionLocal = clean_db
    setup = SessionLocal()
    role_id, skill_id = _ensure_role_skill(setup)
    a = _make_member(setup, role_id=role_id, skill_id=skill_id, label="A9")
    p_status = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="PS", status=UserStatus.PENDING, floor=None
    )
    p_admin = _make_member(
        setup, role_id=role_id, skill_id=skill_id, label="PA", status=UserStatus.PENDING, floor=None
    )
    _enroll_draft(setup, [a], notes=f"{_MARKER}t9")
    p_status_id = int(p_status.id)
    p_admin_id = int(p_admin.id)
    setup.close()

    # Path A: update_status
    s1 = SessionLocal()
    u1 = s1.get(User, p_status_id)
    assert u1 is not None
    _ = u1.role
    user_crud.update_status(s1, u1, UserStatus.APPROVED)
    s1.close()

    s_seal = SessionLocal()
    with pytest.raises(SkillV2ActivationError):
        apply_seal(s_seal, notes=f"{_MARKER}t9-seal")
    s_seal.rollback()
    # Reject the extra approved so we can test update_user_by_admin path in isolation
    extra = s_seal.get(User, p_status_id)
    assert extra is not None
    _ = extra.role
    user_crud.update_status(s_seal, extra, UserStatus.REJECTED, rejection_reason="reset")
    s_seal.close()

    # Path B: update_user_by_admin
    s2 = SessionLocal()
    u2 = s2.get(User, p_admin_id)
    assert u2 is not None
    _ = u2.role
    user_crud.update_user_by_admin(
        s2,
        u2,
        name=u2.fullname,
        email=u2.email,
        role=RoleName.MEMBER,
        skill_level="Beginner",
        status=UserStatus.APPROVED,
    )
    s2.close()

    s3 = SessionLocal()
    with pytest.raises(SkillV2ActivationError):
        apply_seal(s3, notes=f"{_MARKER}t9-seal-b")
    s3.rollback()
    s3.close()


def test_shared_dev_postgres_unchanged() -> None:
    """Sanity: this suite targets access_waverep_test URL only."""
    url = isolated_test_database_url().lower()
    assert "/access_waverep_test" in url
    assert not url.rstrip("/").endswith("/postgres")
