"""Documentation assignment status constants and service-point rules."""

from __future__ import annotations

# Member must accept/decline before the assignment is confirmed.
PENDING_ACCEPTANCE = "pending_acceptance"
ACCEPTED = "accepted"
DECLINED = "declined"
IN_PROGRESS = "in_progress"
COMPLETED = "completed"

# Legacy rows created before pending_acceptance workflow.
LEGACY_ASSIGNED = "assigned"

ACTIVE_ASSIGNMENT_STATUSES = (
    PENDING_ACCEPTANCE,
    ACCEPTED,
    IN_PROGRESS,
    LEGACY_ASSIGNED,
)

TERMINAL_ASSIGNMENT_STATUSES = (DECLINED, COMPLETED, "done")

# Service points on assignment completion are disabled — rankings use evaluation uploads.
DOCUMENTATION_SERVICE_POINTS = 0

DECLINE_REASONS = (
    "schedule_conflict",
    "academic_obligation",
    "already_assigned",
    "unable_to_attend",
    "other",
)


def normalize_assignment_status(status: str | None) -> str:
    s = (status or LEGACY_ASSIGNED).strip().lower()
    if s == LEGACY_ASSIGNED:
        return PENDING_ACCEPTANCE
    return s


def display_assignment_status(status: str | None) -> str:
    s = normalize_assignment_status(status)
    return {
        PENDING_ACCEPTANCE: "Pending Acceptance",
        ACCEPTED: "Accepted",
        DECLINED: "Declined",
        IN_PROGRESS: "In Progress",
        COMPLETED: "Completed",
    }.get(s, s.replace("_", " ").title())
