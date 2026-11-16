"""
Isolated staging verification for Skill Progression v2 activation infrastructure.

HARD RULE: only access_waverep_test. Never touches shared-dev postgres.
Ephemeral fixture users are created and cleaned up in this script.
"""

from __future__ import annotations

import os
import sys
import traceback
import uuid
from datetime import datetime, timezone
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

os.environ["ACCESS_PYTEST_DB"] = "access_waverep_test"

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import Session, sessionmaker

from app.migrations.isolated_test_database_url import isolated_test_database_url
from app.migrations.skill_progression_v2_activation import (
    downgrade_skill_progression_v2_activation,
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
from app.services.skill_progression import (
    build_skill_progression_snapshot,
    resolve_effective_skill_progression_policy,
)
from app.services.skill_progression_grandfather import grandfather_snapshots_complete
from app.services.skill_progression_policy import POLICY_V1, POLICY_V2
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
from app.crud import user as user_crud

MARKER = "v2act_verify_"
REPORT: list[str] = []


def log(msg: str) -> None:
    print(msg)
    REPORT.append(msg)


def assert_db(engine) -> None:
    with engine.connect() as conn:
        name = conn.execute(text("SELECT current_database()")).scalar()
    if name != "access_waverep_test":
        raise SystemExit(f"REFUSING: connected to {name!r}, expected access_waverep_test")


def shared_dev_untouched() -> None:
    from app.config import settings
    from app.database import engine as shared_engine

    with shared_engine.connect() as conn:
        name = conn.execute(text("SELECT current_database()")).scalar()
        tables = set(
            conn.execute(
                text(
                    "SELECT tablename FROM pg_tables "
                    "WHERE schemaname='public' AND tablename LIKE 'skill_progression_v2%'"
                )
            ).scalars()
        )
    log(f"SHARED-DEV check: current_database={name} skill_v2_tables={sorted(tables)}")
    if name != "postgres":
        log(f"WARN: expected shared-dev name postgres, got {name}")
    if tables:
        raise SystemExit(f"FAIL: shared-dev unexpectedly has {tables}")
    log("SHARED-DEV: untouched (no v2 activation tables)")


def xp_skill_fingerprint(db: Session) -> dict:
    pts = db.execute(text("SELECT COALESCE(SUM(total_points),0) FROM member_rankings")).scalar()
    skill_ids = db.execute(
        text("SELECT COUNT(*) FROM users WHERE skill_level_id IS NOT NULL")
    ).scalar()
    cols = {
        c["name"]
        for c in inspect(db.get_bind()).get_columns("member_rankings")
    }
    floors = 0
    if "skill_tier_grandfather_floor" in cols:
        floors = db.execute(
            text(
                "SELECT COUNT(*) FROM member_rankings "
                "WHERE skill_tier_grandfather_floor IS NOT NULL "
                "AND trim(skill_tier_grandfather_floor) <> ''"
            )
        ).scalar()
    return {
        "sum_total_points": int(pts or 0),
        "floors_set": int(floors or 0),
        "users_with_skill_level": int(skill_ids or 0),
        "has_grandfather_cols": "skill_tier_grandfather_floor" in cols,
    }


def ensure_grandfather_columns(engine) -> None:
    """Prerequisite columns from earlier skill progression work (isolated DB only)."""
    from migrate_skill_progression_grandfather import NEW_COLUMNS

    insp = inspect(engine)
    existing = {c["name"] for c in insp.get_columns("member_rankings")}
    missing = [c for c in NEW_COLUMNS if c not in existing]
    if not missing:
        log("Prerequisite grandfather columns already present on member_rankings")
        return
    with engine.begin() as conn:
        for col, typedef in NEW_COLUMNS.items():
            if col not in existing:
                conn.execute(
                    text(f"ALTER TABLE member_rankings ADD COLUMN {col} {typedef}")
                )
                log(f"Added prerequisite column member_rankings.{col}")


def verify_schema(engine) -> None:
    insp = inspect(engine)
    tables = set(insp.get_table_names())
    assert "skill_progression_v2_activation" in tables
    assert "skill_progression_v2_cohort_members" in tables

    act_cols = {c["name"] for c in insp.get_columns("skill_progression_v2_activation")}
    cohort_cols = {c["name"] for c in insp.get_columns("skill_progression_v2_cohort_members")}
    for col in (
        "id",
        "status",
        "cohort_member_count",
        "sealed_at",
        "sealed_by_user_id",
        "revoked_at",
    ):
        assert col in act_cols, col
    for col in (
        "id",
        "activation_id",
        "user_id",
        "ranking_id",
        "floor_at_capture",
        "captured_at",
    ):
        assert col in cohort_cols, col

    fks = insp.get_foreign_keys("skill_progression_v2_cohort_members")
    fk_targets = {(tuple(fk["constrained_columns"]), fk["referred_table"]) for fk in fks}
    assert (("activation_id",), "skill_progression_v2_activation") in fk_targets
    assert (("user_id",), "users") in fk_targets
    assert (("ranking_id",), "member_rankings") in fk_targets

    uniq = insp.get_unique_constraints("skill_progression_v2_cohort_members")
    uniq_cols = {tuple(u["column_names"]) for u in uniq}
    # UniqueConstraint may also appear as unique index
    indexes = insp.get_indexes("skill_progression_v2_cohort_members")
    idx_cols = {tuple(i["column_names"]) for i in indexes if i.get("unique")}
    assert ("activation_id", "user_id") in uniq_cols or ("activation_id", "user_id") in idx_cols

    with engine.connect() as conn:
        partial = conn.execute(
            text(
                "SELECT indexname FROM pg_indexes "
                "WHERE tablename='skill_progression_v2_activation' "
                "AND indexname='uq_skill_progression_v2_one_sealed'"
            )
        ).scalar()
    assert partial == "uq_skill_progression_v2_one_sealed"
    log("SCHEMA: tables, FKs, unique(activation_id,user_id), one-sealed index OK")


def ensure_roles_skills(db: Session) -> tuple[int, dict[str, int]]:
    role = db.scalar(select(Role).where(Role.role_name == RoleName.MEMBER))
    if role is None:
        role = Role(role_name=RoleName.MEMBER)
        db.add(role)
        db.flush()
    levels: dict[str, int] = {}
    for name in ("Beginner", "Intermediate", "Advanced", "Expert"):
        row = db.scalar(select(SkillLevel).where(SkillLevel.level_name == name))
        if row is None:
            row = SkillLevel(level_name=name)
            db.add(row)
            db.flush()
        levels[name] = row.id
    db.commit()
    return role.id, levels


def ensure_rankings_for_approved_members(db: Session) -> int:
    """Create missing member_rankings rows (0 XP) so capture can run on this DB."""
    from app.services.skill_progression_v2_activation import list_approved_members

    created = 0
    for user in list_approved_members(db):
        if user.member_ranking is None:
            db.add(MemberRanking(user_id=user.id, total_points=0))
            created += 1
    if created:
        db.commit()
    return created


def cleanup_fixtures(db: Session) -> None:
    emails = db.scalars(
        select(User.email).where(User.email.like(f"{MARKER}%"))
    ).all()
    if not emails:
        return
    ids = db.scalars(select(User.id).where(User.email.like(f"{MARKER}%"))).all()
    if ids:
        # Remove cohort rows referencing fixture users first if tables exist
        try:
            db.execute(
                text(
                    "DELETE FROM skill_progression_v2_cohort_members "
                    "WHERE user_id = ANY(:ids)"
                ),
                {"ids": list(ids)},
            )
        except Exception:
            db.rollback()
        db.execute(text("DELETE FROM member_rankings WHERE user_id = ANY(:ids)"), {"ids": list(ids)})
        db.execute(text("DELETE FROM users WHERE id = ANY(:ids)"), {"ids": list(ids)})
    # Remove activations created by this run (notes marker)
    try:
        db.execute(
            text(
                "DELETE FROM skill_progression_v2_activation "
                "WHERE notes LIKE :m OR notes IS NULL AND status IN ('draft','sealed','revoked')"
            ),
            {"m": f"%{MARKER}%"},
        )
        # Safer: delete all activation rows that only reference cleaned fixtures — wipe test activations
        db.execute(text("DELETE FROM skill_progression_v2_cohort_members"))
        db.execute(text("DELETE FROM skill_progression_v2_activation"))
    except Exception:
        db.rollback()
        return
    db.commit()


def create_fixture_member(
    db: Session,
    *,
    role_id: int,
    levels: dict[str, int],
    label: str,
    stored_tier: str,
    points: int,
    status: str = UserStatus.APPROVED,
) -> User:
    email = f"{MARKER}{label}_{uuid.uuid4().hex[:8]}@staging.local"
    user = User(
        email=email,
        fullname=label,
        password="hash",
        role_id=role_id,
        status=status,
        skill_level_id=levels[stored_tier],
        is_active=True,
        approved_at=datetime.now(timezone.utc) if status == UserStatus.APPROVED else None,
    )
    db.add(user)
    db.flush()
    db.add(MemberRanking(user_id=user.id, total_points=points))
    db.commit()
    db.refresh(user)
    return user


def force_computed_v1_via_mock_stats(monkeypatch_target: dict[int, tuple[float, int, int]]):
    """Patch eligible stats so computed_tier_v1 matches desired staging simulation."""

    class _Stats:
        def __init__(self, avg: float, count: int, days: int):
            self.average_score = avg
            self.count = count
            self.distinct_upload_days = days
            self.photo_count = count
            self.video_count = 0
            self.photo_average_score = avg
            self.video_average_score = 0.0

    def _fake(db, user_id: int):
        avg, count, days = monkeypatch_target.get(user_id, (0.0, 0, 0))
        return _Stats(avg, count, days)

    return _fake


def section_migration(engine, SessionLocal) -> None:
    log("\n=== 1. MIGRATION SAFETY ===")
    assert_db(engine)
    ensure_grandfather_columns(engine)
    db = SessionLocal()
    before = xp_skill_fingerprint(db)
    db.close()
    log(f"fingerprint before upgrade: {before}")

    upgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine)
    verify_schema(engine)

    db = SessionLocal()
    after = xp_skill_fingerprint(db)
    db.close()
    log(f"fingerprint after upgrade: {after}")
    assert before == after, "XP/skill fingerprint changed by migration DDL"
    log("Migration did not change XP sums or skill_level assignments")

    upgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine)
    log("Idempotent re-upgrade OK")

    downgrade_skill_progression_v2_activation(engine)
    assert not skill_progression_v2_activation_tables_exist(engine)
    log("Downgrade removed tables OK")

    db = SessionLocal()
    after_down = xp_skill_fingerprint(db)
    db.close()
    assert before == after_down
    log("Fingerprint unchanged after downgrade")

    upgrade_skill_progression_v2_activation(engine)
    assert skill_progression_v2_activation_tables_exist(engine)
    log("Re-upgrade after downgrade OK (leave schema present for remaining sections)")


def _capture_ready_draft(SessionLocal, *, label: str) -> int:
    """Capture a draft cohort for concurrency fixtures; returns pending user id."""
    from unittest.mock import patch

    from app.services.skill_progression_v2_activation import list_approved_members as _lam

    db = SessionLocal()
    cleanup_fixtures(db)
    role_id, levels = ensure_roles_skills(db)
    create_fixture_member(
        db, role_id=role_id, levels=levels, label=f"{label}A", stored_tier="Beginner", points=10
    )
    create_fixture_member(
        db, role_id=role_id, levels=levels, label=f"{label}B", stored_tier="Beginner", points=10
    )
    pending = create_fixture_member(
        db,
        role_id=role_id,
        levels=levels,
        label=f"{label}Pending",
        stored_tier="Beginner",
        points=0,
        status=UserStatus.PENDING,
    )
    pending_id = int(pending.id)
    stats_map = {pending_id: (0.0, 0, 0)}
    ensure_rankings_for_approved_members(db)
    for u in _lam(db):
        stats_map.setdefault(u.id, (0.0, 0, 0))
    with patch(
        "app.services.skill_progression.eligible_skill_evaluation_stats",
        force_computed_v1_via_mock_stats(stats_map),
    ):
        apply_cohort_capture(db, notes=f"{MARKER}{label}")
        db.commit()
    plan = plan_seal(db)
    assert plan.ready, plan.blocked_reason
    db.close()
    return pending_id


def section_concurrency(engine, SessionLocal) -> dict:
    """Regression: shared pg_advisory_xact_lock closes seal/approval TOCTOU."""
    log("\n=== 2. ACTIVATION CONCURRENCY ===")
    import threading
    import time

    from app.services import skill_progression_activation_coord as coord
    import app.services.skill_progression_v2_activation as act_mod

    results = {
        "approval_before_seal_aborts": False,
        "toctou_window_blocked": False,
        "post_seal_member_excluded": False,
    }

    # Race A: approval commits before seal begins -> apply_seal aborts
    pending_id = _capture_ready_draft(SessionLocal, label="Conc")
    s_approve = SessionLocal()
    pend = s_approve.get(User, pending_id)
    assert pend is not None
    _ = pend.role
    user_crud.update_status(s_approve, pend, UserStatus.APPROVED)
    s_approve.close()
    s_seal = SessionLocal()
    try:
        apply_seal(s_seal, notes=f"{MARKER}conc-seal")
        s_seal.rollback()
        log("CONCURRENCY UNEXPECTED: seal succeeded after pre-seal approval")
    except SkillV2ActivationError as exc:
        results["approval_before_seal_aborts"] = True
        log(f"CONCURRENCY PASS: approval before seal aborted apply_seal ({exc})")
        s_seal.rollback()
    finally:
        s_seal.close()

    # Race B (former TOCTOU): approval after under-lock revalidate, before UPDATE
    pending_id = _capture_ready_draft(SessionLocal, label="Toc")
    after_validate = threading.Event()
    allow_update = threading.Event()
    approve_done = threading.Event()
    errors: list[BaseException] = []
    original_plan = act_mod.plan_seal
    call_count = {"n": 0}

    def plan_with_barrier(db: Session):
        plan = original_plan(db)
        call_count["n"] += 1
        if call_count["n"] >= 2 and plan.ready:
            after_validate.set()
            assert allow_update.wait(timeout=15), "seal update continue timeout"
        return plan

    act_mod.plan_seal = plan_with_barrier  # type: ignore[assignment]
    coord.set_after_acquire_hook_for_tests(None)
    try:

        def run_seal() -> None:
            s = SessionLocal()
            try:
                apply_seal(s, notes=f"{MARKER}toc-seal")
                s.commit()
            except BaseException as exc:  # noqa: BLE001
                s.rollback()
                errors.append(exc)
            finally:
                s.close()

        def run_approve() -> None:
            assert after_validate.wait(timeout=15)
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
        assert after_validate.wait(timeout=15)
        t_approve.start()
        time.sleep(0.4)
        if approve_done.is_set():
            log("CONCURRENCY FAIL: approval committed during post-validate seal window")
            allow_update.set()
        else:
            results["toctou_window_blocked"] = True
            log("CONCURRENCY PASS: former TOCTOU window blocked by advisory lock")
            allow_update.set()
        t_seal.join(timeout=20)
        t_approve.join(timeout=20)
        assert not errors, errors
        assert approve_done.is_set()
    finally:
        act_mod.plan_seal = original_plan  # type: ignore[assignment]
        coord.set_after_acquire_hook_for_tests(None)

    check = SessionLocal()
    sealed = get_sealed_activation(check)
    in_cohort = is_user_in_sealed_cohort(check, pending_id)
    results["post_seal_member_excluded"] = sealed is not None and not in_cohort
    log(
        f"CONCURRENCY PASS: seal committed; late-approved member in_cohort={in_cohort}"
    )
    cleanup_fixtures(check)
    check.close()
    return results


def section_capture_seal_new_member_rollback(SessionLocal) -> None:
    log("\n=== 3–5. CAPTURE / SEAL / NEW MEMBER / ROLLBACK ===")
    from unittest.mock import patch

    db = SessionLocal()
    cleanup_fixtures(db)
    role_id, levels = ensure_roles_skills(db)

    # Simulate the four members with computed v1 targets via eligible stats mocks.
    # Override on makoy must not become floor.
    shan = create_fixture_member(
        db, role_id=role_id, levels=levels, label="Shan Lee", stored_tier="Intermediate", points=658
    )
    makoy = create_fixture_member(
        db, role_id=role_id, levels=levels, label="makoy gas", stored_tier="Intermediate", points=230
    )
    dan = create_fixture_member(
        db, role_id=role_id, levels=levels, label="Dan Thee", stored_tier="Intermediate", points=224
    )
    mela = create_fixture_member(
        db, role_id=role_id, levels=levels, label="Mela Dee", stored_tier="Beginner", points=0
    )
    makoy_rank = db.scalar(select(MemberRanking).where(MemberRanking.user_id == makoy.id))
    assert makoy_rank is not None
    makoy_rank.competency_level_override = "Advanced"
    db.commit()

    ensure_rankings_for_approved_members(db)

    # Intermediate: >=60% and >=3 evals; Beginner: 0
    stats_map = {
        shan.id: (0.734, 9, 6),
        makoy.id: (0.765, 3, 2),
        dan.id: (0.749, 3, 1),
        mela.id: (0.0, 0, 0),
    }
    from app.services.skill_progression_v2_activation import list_approved_members as _lam2

    for u in _lam2(db):
        stats_map.setdefault(u.id, (0.0, 0, 0))
    fake = force_computed_v1_via_mock_stats(stats_map)

    with patch("app.services.skill_progression.eligible_skill_evaluation_stats", fake):
        for uid, expected in (
            (shan.id, "Intermediate"),
            (makoy.id, "Intermediate"),
            (dan.id, "Intermediate"),
            (mela.id, "Beginner"),
        ):
            snap = build_skill_progression_snapshot(db, uid)
            assert snap.computed_tier_v1 == expected, (uid, snap.computed_tier_v1)
            log(f"computed_v1 {snap and uid} OK -> {expected}")

        plan = plan_cohort_capture(db)
        log(
            f"capture dry-run candidates={len(plan.candidates)} "
            f"would_write={plan.would_write_floors}"
        )
        for c in plan.candidates:
            log(
                f"  {c.fullname!r} computed_v1={c.computed_tier_v1} "
                f"override={c.admin_override!r}"
            )
            if c.fullname == "makoy gas":
                assert c.computed_tier_v1 == "Intermediate"
                assert c.admin_override == "Advanced"

        apply_cohort_capture(db, notes=f"{MARKER}capture")
        db.commit()

        for uid, expected in (
            (shan.id, "Intermediate"),
            (makoy.id, "Intermediate"),
            (dan.id, "Intermediate"),
            (mela.id, "Beginner"),
        ):
            ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == uid))
            assert ranking.skill_tier_grandfather_floor == expected
            assert ranking.skill_tier_grandfather_from_policy == "v1"
        # Override preserved, not used as floor
        makoy_rank = db.scalar(select(MemberRanking).where(MemberRanking.user_id == makoy.id))
        assert makoy_rank.competency_level_override == "Advanced"
        log("CAPTURE: floors from computed_v1; makoy override not used as floor")

        seal_plan = plan_seal(db)
        assert seal_plan.ready, seal_plan.blocked_reason
        apply_seal(db, notes=f"{MARKER}seal")
        db.commit()
        assert get_sealed_activation(db) is not None
        assert grandfather_snapshots_complete(db) is True
        log("SEAL: complete")

    # Configure v2 via monkeypatch of settings + policy function
    from app.config import settings

    old_policy = settings.skill_progression_active_policy
    settings.skill_progression_active_policy = "v2"
    try:
        with patch(
            "app.services.skill_progression_policy.configured_skill_progression_policy",
            return_value=POLICY_V2,
        ), patch(
            "app.services.skill_progression.eligible_skill_evaluation_stats",
            fake,
        ):
            eff, reason = resolve_effective_skill_progression_policy(db)
            assert eff == POLICY_V2, (eff, reason)
            assert reason is None
            log("ACTIVATION: effective policy v2")

            # New member after seal
            newbie = create_fixture_member(
                db,
                role_id=role_id,
                levels=levels,
                label="NewAfterSeal",
                stored_tier="Beginner",
                points=0,
            )
            stats_map[newbie.id] = (0.0, 0, 0)
            fake2 = force_computed_v1_via_mock_stats(stats_map)
            with patch(
                "app.services.skill_progression.eligible_skill_evaluation_stats",
                fake2,
            ):
                eff2, reason2 = resolve_effective_skill_progression_policy(db)
                assert eff2 == POLICY_V2 and reason2 is None
                assert is_user_in_sealed_cohort(db, newbie.id) is False
                assert is_user_in_sealed_cohort(db, shan.id) is True
                snap_new = build_skill_progression_snapshot(db, newbie.id)
                assert snap_new.policy_version == POLICY_V2
                assert snap_new.grandfather_floor is None
                log(
                    "NEW MEMBER: uses v2, not in cohort, does not reblock "
                    f"(effective={eff2})"
                )

        # Rollback configured policy to v1
        with patch(
            "app.services.skill_progression_policy.configured_skill_progression_policy",
            return_value=POLICY_V1,
        ):
            eff3, reason3 = resolve_effective_skill_progression_policy(db)
            assert eff3 == POLICY_V1
            assert reason3 is None
            # Floors intact
            for uid, expected in (
                (shan.id, "Intermediate"),
                (makoy.id, "Intermediate"),
                (dan.id, "Intermediate"),
                (mela.id, "Beginner"),
            ):
                ranking = db.scalar(select(MemberRanking).where(MemberRanking.user_id == uid))
                assert ranking.skill_tier_grandfather_floor == expected
            assert get_sealed_activation(db) is not None
            log("ROLLBACK env->v1: effective v1; floors + seal row retained")

        # Optional revoke seal while configured v2 -> blocked again
        with patch(
            "app.services.skill_progression_policy.configured_skill_progression_policy",
            return_value=POLICY_V2,
        ):
            revoke_seal(db, reason=f"{MARKER}rollback_test")
            db.commit()
            eff4, reason4 = resolve_effective_skill_progression_policy(db)
            assert eff4 == POLICY_V1
            assert reason4 and "sealed" in reason4.lower()
            log("REVOKE seal with configured v2: effective fails closed to v1")
    finally:
        settings.skill_progression_active_policy = old_policy
        cleanup_fixtures(db)
        db.close()


def main() -> int:
    url = isolated_test_database_url()
    engine = create_engine(url, pool_pre_ping=True)
    assert_db(engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    log("Isolated staging verification starting")
    log(f"target={url.rsplit('@', 1)[-1]}")

    shared_dev_untouched()
    section_migration(engine, SessionLocal)
    shared_dev_untouched()

    conc = section_concurrency(engine, SessionLocal)
    section_capture_seal_new_member_rollback(SessionLocal)
    shared_dev_untouched()

    # Leave waverep with tables present (re-upgrade already done) but no fixture seal
    db = SessionLocal()
    cleanup_fixtures(db)
    db.close()

    log("\n=== SUMMARY ===")
    log(f"concurrency.approval_before_seal_aborts={conc['approval_before_seal_aborts']}")
    log(f"concurrency.toctou_window_blocked={conc['toctou_window_blocked']}")
    log(f"concurrency.post_seal_member_excluded={conc['post_seal_member_excluded']}")
    if not all(conc.values()):
        log("DEFECT: concurrency regression — shared advisory lock path incomplete")
        return 1
    log("TOCTOU closed: Member approval and seal share pg_advisory_xact_lock")
    log("shared-dev migration NOT applied; approval still required before shared-dev DDL")
    log("DONE")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        traceback.print_exc()
        raise SystemExit(1)
