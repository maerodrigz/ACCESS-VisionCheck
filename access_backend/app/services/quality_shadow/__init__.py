"""Quality shadow scoring (Phase 2) — research-only, optional, async.

When QUALITY_SHADOW_ENABLED=false (default), nothing is scheduled and MUSIQ/TF
are never imported. When enabled, hybrid classical + MUSIQ OPQ run off the
request path and write anonymized JSONL/CSV logs only. Production evaluation
payloads, XP, feedback, and DB evaluation rows are never modified.
"""

from app.services.quality_shadow.worker import (
    maybe_schedule_quality_shadow,
    shutdown_quality_shadow_executor,
)

__all__ = [
    "maybe_schedule_quality_shadow",
    "shutdown_quality_shadow_executor",
]
