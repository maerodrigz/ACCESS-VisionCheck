"""Shared transaction lock coordinating Member approval and v2 activation sealing.

PostgreSQL: pg_advisory_xact_lock (held until transaction commit/rollback).
SQLite: no-op (unit tests); real concurrency coverage is Postgres-only.
"""

from __future__ import annotations

from collections.abc import Callable

from sqlalchemy import text
from sqlalchemy.orm import Session

# Stable application key — must match for approval + seal paths.
# Chosen to avoid colliding with unrelated advisory lock usages in this codebase.
SKILL_V2_APPROVAL_SEAL_COORD_LOCK_KEY = 872_014_020

# Test-only hook invoked after the lock is acquired (deterministic concurrency tests).
_AFTER_ACQUIRE_HOOK: Callable[[Session], None] | None = None


def acquire_member_approval_seal_coordination_lock(db: Session) -> None:
    """Acquire the shared activation/approval coordination lock for this transaction.

    Call before:
    - transitioning a Member account to approved, or
    - final seal validation + persistence.

    Do not hold across operator prompts; acquire only inside the DB transaction
    that performs the write, then commit/rollback promptly.
    """
    bind = db.get_bind()
    dialect = bind.dialect.name
    if dialect == "postgresql":
        db.execute(
            text("SELECT pg_advisory_xact_lock(:key)"),
            {"key": SKILL_V2_APPROVAL_SEAL_COORD_LOCK_KEY},
        )
    # SQLite / others: single-threaded unit tests; concurrency verified on Postgres.
    hook = _AFTER_ACQUIRE_HOOK
    if hook is not None:
        hook(db)
    return


def set_after_acquire_hook_for_tests(hook: Callable[[Session], None] | None) -> None:
    """Install/clear the post-acquire hook. For isolated concurrency tests only."""
    global _AFTER_ACQUIRE_HOOK
    _AFTER_ACQUIRE_HOOK = hook


def member_approval_requires_activation_coord_lock(
    *,
    previous_status: str | None,
    new_status: str,
    role_name: str | None,
) -> bool:
    """True when this status change can race with activation sealing."""
    from app.models.enums import RoleName, UserStatus

    if (new_status or "").strip().lower() != UserStatus.APPROVED:
        return False
    if (previous_status or "").strip().lower() == UserStatus.APPROVED:
        return False
    role = (role_name or "").strip().lower()
    return role == RoleName.MEMBER.strip().lower()
