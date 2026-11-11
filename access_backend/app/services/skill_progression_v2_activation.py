"""Operator-controlled Skill Progression v2 cohort capture and activation seal."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError, ProgrammingError, OperationalError
from sqlalchemy.orm import Session, joinedload

from app.models.enums import RoleName, UserStatus
from app.models.member_ranking import MemberRanking
from app.models.role import Role
from app.models.skill_progression_v2_activation import (
    ACTIVATION_STATUS_DRAFT,
    ACTIVATION_STATUS_REVOKED,
    ACTIVATION_STATUS_SEALED,
    SkillProgressionV2Activation,
    SkillProgressionV2CohortMember,
)
from app.models.user import User
from app.services.skill_progression_policy import POLICY_V1, POLICY_V2


class SkillV2ActivationError(RuntimeError):
    """Fail-closed operator / concurrency error for capture or seal."""


VALID_FLOORS = frozenset({"Beginner", "Intermediate", "Advanced", "Expert"})


def _dialect_name(db: Session) -> str:
    return db.get_bind().dialect.name


def _lock_activation_row(
    db: Session,
    *,
    activation_id: int,
    required_status: str | None = None,
) -> dict:
    """Row lock on Postgres; re-read without FOR UPDATE on SQLite test engines."""
    if _dialect_name(db) == "sqlite":
        row = db.execute(
            text(
                "SELECT id, status FROM skill_progression_v2_activation WHERE id = :id"
            ),
            {"id": activation_id},
        ).mappings().one_or_none()
    else:
        row = db.execute(
            text(
                "SELECT id, status FROM skill_progression_v2_activation "
                "WHERE id = :id FOR UPDATE"
            ),
            {"id": activation_id},
        ).mappings().one_or_none()
    if row is None:
        raise SkillV2ActivationError("Activation row missing under lock.")
    if required_status is not None and row["status"] != required_status:
        raise SkillV2ActivationError(
            f"Activation status={row['status']!r}, expected {required_status!r}."
        )
    return dict(row)


def activation_schema_ready(db: Session) -> bool:
    """True when seal/cohort tables exist (migration applied).

    Uses a SAVEPOINT probe so a missing-table error does not abort the
    caller's open unit-of-work (Inspector/reflection is unsafe mid-flush on SQLite).
    """
    try:
        with db.begin_nested():
            db.execute(text("SELECT 1 FROM skill_progression_v2_activation WHERE 0=1"))
            db.execute(text("SELECT 1 FROM skill_progression_v2_cohort_members WHERE 0=1"))
        return True
    except (ProgrammingError, OperationalError, DBAPIError):
        return False
    except Exception:
        return False


@dataclass(frozen=True)
class CohortCaptureCandidate:
    user_id: int
    ranking_id: int
    fullname: str
    computed_tier_v1: str
    existing_floor: str | None
    admin_override: str | None
    already_in_draft: bool


@dataclass(frozen=True)
class CohortCapturePlan:
    mode: str
    activation_id: int | None
    candidates: tuple[CohortCaptureCandidate, ...]
    would_write_floors: int
    would_add_cohort_rows: int
    skipped_existing_matching: int


@dataclass(frozen=True)
class SealPlan:
    mode: str
    activation_id: int
    cohort_user_ids: tuple[int, ...]
    approved_user_ids: tuple[int, ...]
    missing_floors: tuple[int, ...]
    approved_not_in_cohort: tuple[int, ...]
    cohort_not_approved: tuple[int, ...]
    ready: bool
    blocked_reason: str | None


def list_approved_members(db: Session) -> list[User]:
    return list(
        db.scalars(
            select(User)
            .options(joinedload(User.member_ranking), joinedload(User.skill_level))
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
            .order_by(User.id)
        )
        .unique()
        .all()
    )


def get_sealed_activation(db: Session) -> SkillProgressionV2Activation | None:
    if not activation_schema_ready(db):
        return None
    return db.scalar(
        select(SkillProgressionV2Activation).where(
            SkillProgressionV2Activation.status == ACTIVATION_STATUS_SEALED
        )
    )


def get_open_draft_activation(db: Session) -> SkillProgressionV2Activation | None:
    if not activation_schema_ready(db):
        return None
    return db.scalar(
        select(SkillProgressionV2Activation)
        .where(SkillProgressionV2Activation.status == ACTIVATION_STATUS_DRAFT)
        .order_by(SkillProgressionV2Activation.id.desc())
    )


def is_user_in_sealed_cohort(db: Session, user_id: int) -> bool:
    seal = get_sealed_activation(db)
    if seal is None:
        return False
    row = db.scalar(
        select(SkillProgressionV2CohortMember.id).where(
            SkillProgressionV2CohortMember.activation_id == seal.id,
            SkillProgressionV2CohortMember.user_id == user_id,
        )
    )
    return row is not None


def sealed_cohort_user_ids(db: Session, activation_id: int) -> list[int]:
    rows = db.scalars(
        select(SkillProgressionV2CohortMember.user_id)
        .where(SkillProgressionV2CohortMember.activation_id == activation_id)
        .order_by(SkillProgressionV2CohortMember.user_id)
    ).all()
    return list(rows)


def _valid_floor(raw: str | None) -> str | None:
    if not raw or not str(raw).strip():
        return None
    label = str(raw).strip()
    if label not in VALID_FLOORS:
        return None
    return label


def protected_cohort_members_missing_floors(
    db: Session,
    activation: SkillProgressionV2Activation | None = None,
) -> list[int]:
    """Sealed cohort members without a valid earned floor on member_rankings."""
    seal = activation or get_sealed_activation(db)
    if seal is None:
        return []
    missing: list[int] = []
    members = db.scalars(
        select(SkillProgressionV2CohortMember).where(
            SkillProgressionV2CohortMember.activation_id == seal.id
        )
    ).all()
    for row in members:
        ranking = db.scalar(
            select(MemberRanking).where(MemberRanking.user_id == row.user_id)
        )
        if ranking is None or _valid_floor(ranking.skill_tier_grandfather_floor) is None:
            missing.append(row.user_id)
    return sorted(missing)


def plan_cohort_capture(db: Session) -> CohortCapturePlan:
    """Dry-run: propose earned v1 floors for all currently approved members."""
    from app.services.skill_progression import build_skill_progression_snapshot

    if not activation_schema_ready(db):
        raise SkillV2ActivationError(
            "Activation schema missing. Run migrate_skill_progression_v2_activation.py "
            "on an approved isolated/target database first."
        )
    if get_sealed_activation(db) is not None:
        raise SkillV2ActivationError(
            "A sealed v2 activation already exists. Capture against sealed activations is blocked."
        )
    draft = get_open_draft_activation(db)
    existing_ids: set[int] = set()
    if draft is not None:
        existing_ids = set(sealed_cohort_user_ids(db, draft.id))

    candidates: list[CohortCaptureCandidate] = []
    would_write = 0
    would_add = 0
    skipped = 0
    for user in list_approved_members(db):
        ranking = user.member_ranking
        if ranking is None:
            raise SkillV2ActivationError(
                f"Approved member user_id={user.id} has no member_rankings row."
            )
        snap = build_skill_progression_snapshot(db, user.id)
        floor = snap.computed_tier_v1
        if floor not in VALID_FLOORS:
            raise SkillV2ActivationError(
                f"Invalid computed_tier_v1={floor!r} for user_id={user.id}"
            )
        existing = _valid_floor(ranking.skill_tier_grandfather_floor)
        in_draft = user.id in existing_ids
        if existing == floor and in_draft:
            skipped += 1
        else:
            if existing != floor:
                would_write += 1
            if not in_draft:
                would_add += 1
        candidates.append(
            CohortCaptureCandidate(
                user_id=user.id,
                ranking_id=ranking.id,
                fullname=user.fullname,
                computed_tier_v1=floor,
                existing_floor=existing,
                admin_override=(
                    str(ranking.competency_level_override).strip()
                    if ranking.competency_level_override
                    else None
                ),
                already_in_draft=in_draft,
            )
        )
    return CohortCapturePlan(
        mode="DRY-RUN",
        activation_id=draft.id if draft else None,
        candidates=tuple(candidates),
        would_write_floors=would_write,
        would_add_cohort_rows=would_add,
        skipped_existing_matching=skipped,
    )


def apply_cohort_capture(
    db: Session,
    *,
    actor_user_id: int | None = None,
    notes: str | None = None,
) -> CohortCapturePlan:
    """
    Write earned v1 floors + draft cohort membership for currently approved members.

    Idempotent when floor and cohort row already match computed_tier_v1.
    Does not seal activation.
    """
    from app.services.skill_progression import build_skill_progression_snapshot

    plan = plan_cohort_capture(db)
    now = datetime.now(timezone.utc)

    draft = get_open_draft_activation(db)
    if draft is None:
        draft = SkillProgressionV2Activation(
            status=ACTIVATION_STATUS_DRAFT,
            cohort_member_count=0,
            notes=notes,
            created_by_user_id=actor_user_id,
        )
        db.add(draft)
        db.flush()

    activation_id = int(draft.id)
    _lock_activation_row(
        db, activation_id=activation_id, required_status=ACTIVATION_STATUS_DRAFT
    )

    for cand in plan.candidates:
        ranking_q = select(MemberRanking).where(
            MemberRanking.id == cand.ranking_id, MemberRanking.user_id == cand.user_id
        )
        if _dialect_name(db) != "sqlite":
            ranking_q = ranking_q.with_for_update()
        ranking = db.scalar(ranking_q)
        if ranking is None:
            raise SkillV2ActivationError(
                f"Ranking row missing for user_id={cand.user_id} under lock."
            )
        # Recompute under lock — never trust stale dry-run floor if metrics changed.
        snap = build_skill_progression_snapshot(db, cand.user_id)
        floor = snap.computed_tier_v1
        if floor not in VALID_FLOORS:
            raise SkillV2ActivationError(f"Invalid floor {floor!r} for user_id={cand.user_id}")

        ranking.skill_tier_grandfather_floor = floor
        ranking.skill_tier_grandfather_captured_at = now
        ranking.skill_tier_grandfather_from_policy = POLICY_V1

        existing = db.scalar(
            select(SkillProgressionV2CohortMember).where(
                SkillProgressionV2CohortMember.activation_id == activation_id,
                SkillProgressionV2CohortMember.user_id == cand.user_id,
            )
        )
        if existing is None:
            db.add(
                SkillProgressionV2CohortMember(
                    activation_id=activation_id,
                    user_id=cand.user_id,
                    ranking_id=ranking.id,
                    floor_at_capture=floor,
                    captured_at=now,
                    captured_by_user_id=actor_user_id,
                )
            )
        else:
            existing.floor_at_capture = floor
            existing.ranking_id = ranking.id
            existing.captured_at = now
            existing.captured_by_user_id = actor_user_id

    # Drop draft cohort rows for members no longer approved (keep seal window consistent).
    approved_ids = {c.user_id for c in plan.candidates}
    for row in db.scalars(
        select(SkillProgressionV2CohortMember).where(
            SkillProgressionV2CohortMember.activation_id == activation_id
        )
    ).all():
        if row.user_id not in approved_ids:
            db.delete(row)

    db.execute(
        text(
            "UPDATE skill_progression_v2_activation SET "
            "cohort_member_count = :count, notes = COALESCE(:notes, notes) "
            "WHERE id = :id AND status = :draft"
        ),
        {
            "count": len(approved_ids),
            "notes": notes,
            "id": activation_id,
            "draft": ACTIVATION_STATUS_DRAFT,
        },
    )
    db.flush()

    return CohortCapturePlan(
        mode="APPLY",
        activation_id=activation_id,
        candidates=plan.candidates,
        would_write_floors=plan.would_write_floors,
        would_add_cohort_rows=plan.would_add_cohort_rows,
        skipped_existing_matching=plan.skipped_existing_matching,
    )


def plan_seal(db: Session) -> SealPlan:
    draft = get_open_draft_activation(db)
    if draft is None:
        raise SkillV2ActivationError("No draft activation to seal. Run cohort capture first.")
    if get_sealed_activation(db) is not None:
        raise SkillV2ActivationError("A sealed activation already exists.")

    cohort_ids = tuple(sealed_cohort_user_ids(db, draft.id))
    approved_ids = tuple(u.id for u in list_approved_members(db))
    approved_set = set(approved_ids)
    cohort_set = set(cohort_ids)
    missing_floors = tuple(protected_cohort_members_missing_floors(db, draft))
    approved_not_in_cohort = tuple(sorted(approved_set - cohort_set))
    cohort_not_approved = tuple(sorted(cohort_set - approved_set))

    blocked = None
    if not cohort_ids:
        blocked = "Draft cohort is empty."
    elif missing_floors:
        blocked = f"Protected cohort missing valid floors for user_ids={list(missing_floors)}"
    elif approved_not_in_cohort:
        blocked = (
            "Approved members not in draft cohort "
            f"(re-run capture): user_ids={list(approved_not_in_cohort)}"
        )
    elif cohort_not_approved:
        blocked = (
            "Cohort contains non-approved members "
            f"(re-run capture): user_ids={list(cohort_not_approved)}"
        )

    return SealPlan(
        mode="DRY-RUN",
        activation_id=draft.id,
        cohort_user_ids=cohort_ids,
        approved_user_ids=approved_ids,
        missing_floors=missing_floors,
        approved_not_in_cohort=approved_not_in_cohort,
        cohort_not_approved=cohort_not_approved,
        ready=blocked is None,
        blocked_reason=blocked,
    )


def apply_seal(
    db: Session,
    *,
    actor_user_id: int | None = None,
    notes: str | None = None,
) -> SealPlan:
    """
    Seal draft activation transactionally.

    Concurrency: acquires the shared Member-approval / seal coordination lock,
    locks the draft activation row, re-reads approved members, requires exact set
    match with cohort membership and valid floors, then flips status to sealed
    in the same transaction (caller commits). No internal commit.
    """
    from app.services.skill_progression_activation_coord import (
        acquire_member_approval_seal_coordination_lock,
    )

    # Fast-fail outside the coordination lock (CLI confirmation happens before apply).
    early = plan_seal(db)
    if not early.ready:
        raise SkillV2ActivationError(early.blocked_reason or "Seal not ready.")

    # Serialize with Member approval/re-approval until this transaction ends.
    acquire_member_approval_seal_coordination_lock(db)
    _lock_activation_row(
        db, activation_id=early.activation_id, required_status=ACTIVATION_STATUS_DRAFT
    )

    # Re-validate under coordination + row locks (closes TOCTOU vs approval).
    refreshed = plan_seal(db)
    if not refreshed.ready:
        raise SkillV2ActivationError(
            refreshed.blocked_reason
            or "Seal blocked after lock (possible concurrent member approval)."
        )
    if set(refreshed.approved_user_ids) != set(refreshed.cohort_user_ids):
        raise SkillV2ActivationError(
            "Approved member set diverged from cohort under lock; re-run capture."
        )
    if refreshed.activation_id != early.activation_id:
        raise SkillV2ActivationError("Draft activation changed under lock; retry seal.")

    activation = db.get(SkillProgressionV2Activation, refreshed.activation_id)
    if activation is None:
        raise SkillV2ActivationError("Activation row disappeared under lock.")
    # Prefer SQL update to avoid SQLite/ORM identity stale races after raw locks.
    result = db.execute(
        text(
            "UPDATE skill_progression_v2_activation SET "
            "status = :status, sealed_at = :sealed_at, sealed_by_user_id = :actor, "
            "cohort_member_count = :count, notes = COALESCE(:notes, notes) "
            "WHERE id = :id AND status = :draft"
        ),
        {
            "status": ACTIVATION_STATUS_SEALED,
            "sealed_at": datetime.now(timezone.utc),
            "actor": actor_user_id,
            "count": len(refreshed.cohort_user_ids),
            "notes": notes,
            "id": activation.id,
            "draft": ACTIVATION_STATUS_DRAFT,
        },
    )
    if result.rowcount != 1:
        raise SkillV2ActivationError(
            "Seal UPDATE affected no draft row (concurrent seal or status change)."
        )
    db.expire(activation)

    return SealPlan(
        mode="APPLY",
        activation_id=activation.id,
        cohort_user_ids=refreshed.cohort_user_ids,
        approved_user_ids=refreshed.approved_user_ids,
        missing_floors=(),
        approved_not_in_cohort=(),
        cohort_not_approved=(),
        ready=True,
        blocked_reason=None,
    )


def revoke_seal(
    db: Session,
    *,
    actor_user_id: int | None = None,
    reason: str | None = None,
) -> SkillProgressionV2Activation:
    """Rollback helper: revoke sealed activation (effective policy falls back when env is v2)."""
    seal = get_sealed_activation(db)
    if seal is None:
        raise SkillV2ActivationError("No sealed activation to revoke.")
    _lock_activation_row(
        db, activation_id=seal.id, required_status=ACTIVATION_STATUS_SEALED
    )
    db.execute(
        text(
            "UPDATE skill_progression_v2_activation SET "
            "status = :status, revoked_at = :revoked_at, "
            "revoked_by_user_id = :actor, revoke_reason = :reason "
            "WHERE id = :id AND status = :sealed"
        ),
        {
            "status": ACTIVATION_STATUS_REVOKED,
            "revoked_at": datetime.now(timezone.utc),
            "actor": actor_user_id,
            "reason": reason or "operator_revoke",
            "id": seal.id,
            "sealed": ACTIVATION_STATUS_SEALED,
        },
    )
    db.expire(seal)
    return db.get(SkillProgressionV2Activation, seal.id) or seal


def assert_write_guards_for_operator_apply(*, allow_shared_dev: bool) -> None:
    """Fail-closed host/policy checks for CLI --apply (does not replace staging guards)."""
    from app.config import settings
    from app.services.skill_progression_policy import configured_skill_progression_policy

    if configured_skill_progression_policy() != POLICY_V1:
        raise SkillV2ActivationError(
            "SKILL_PROGRESSION_ACTIVE_POLICY must be v1 during cohort capture/seal apply."
        )
    host = (settings.db_host or "").strip().lower()
    if host not in {"localhost", "127.0.0.1", "::1"}:
        raise SkillV2ActivationError(f"DB_HOST={settings.db_host!r} is not an allowed local host.")
    if settings.db_name == "postgres" and not allow_shared_dev:
        raise SkillV2ActivationError(
            "Refusing --apply on shared-dev DB_NAME=postgres without "
            "--allow-shared-dev (explicit operator override)."
        )
    forbidden = {"access_uat"}
    if settings.db_name in forbidden:
        raise SkillV2ActivationError(f"Refusing --apply on forbidden database {settings.db_name!r}.")
