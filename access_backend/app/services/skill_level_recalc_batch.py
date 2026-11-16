"""Shared read-only helpers for skill tier batch dry-run and apply verification."""

from __future__ import annotations

import csv
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud.rankings_admin import resolve_member_skill_level
from app.models.ai_detection_result import AiDetectionResult
from app.models.enums import RoleName, UserStatus
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.role import Role
from app.models.user import User
from app.services.member_score_release import member_may_view_scores
from app.services.skill_evaluation_eligibility import (
    eligible_skill_evaluation_stats,
    practice_evaluation_eligible_for_skill,
)
from app.services.skill_scoring import effective_skill_level, media_quality_percent

BACKEND_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REPORT_DIR = BACKEND_ROOT / "backups" / "skill_recalc"


@dataclass
class MemberSkillRecalcRow:
    user_id: int
    name: str
    email: str
    stored_skill_level: str
    competency_level_override: str
    eligible_eval_count: int
    total_practice_eval_rows: int
    eligible_quality_avg_pct: float
    skill_score_quality_only: float
    computed_skill_tier: str
    effective_tier_after_recalc: str
    competency_recommended: str
    stored_differs_from_computed: bool
    stored_differs_from_effective: bool
    would_persist_change: bool
    override_blocks_formula: bool


@dataclass
class EligibilityAuditSummary:
    practice_rows_scanned: int
    eligible_rows_counted: int
    excluded_pending_or_withheld: int
    excluded_rejected_or_ai: int
    excluded_unreleased_score: int
    excluded_zero_score: int
    leak_count: int
    leak_samples: list[dict[str, Any]]


def _normalize_tier(name: str | None) -> str:
    return (name or "").strip()


def tiers_equal(a: str | None, b: str | None) -> bool:
    return _normalize_tier(a).lower() == _normalize_tier(b).lower()


def load_approved_members(db: Session) -> list[User]:
    return list(
        db.scalars(
            select(User)
            .options(joinedload(User.skill_level), joinedload(User.member_ranking))
            .join(Role, User.role_id == Role.id)
            .where(User.status == UserStatus.APPROVED, Role.role_name == RoleName.MEMBER)
            .order_by(User.id)
        )
        .unique()
        .all()
    )


def count_total_practice_eval_rows(db: Session, user_id: int) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(MediaEvaluation)
            .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
            .where(
                MediaFile.uploaded_by == user_id,
                MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
            )
        )
        or 0
    )


def build_member_recalc_row(db: Session, user: User) -> MemberSkillRecalcRow:
    uid = user.id
    eligible = eligible_skill_evaluation_stats(db, uid)
    total_rows = count_total_practice_eval_rows(db, uid)
    quality_pct = media_quality_percent(eligible.average_score)
    computed_tier = effective_skill_level(quality_pct, eligible.count)
    effective, recommended, computed_from_resolve = resolve_member_skill_level(db, uid)
    assert computed_from_resolve == computed_tier

    override_raw = ""
    ranking = user.member_ranking
    if ranking and ranking.competency_level_override:
        override_raw = str(ranking.competency_level_override).strip()

    stored = user.skill_level.level_name if user.skill_level else ""
    override_blocks = bool(override_raw) and not tiers_equal(effective, computed_tier)

    return MemberSkillRecalcRow(
        user_id=uid,
        name=user.fullname or "",
        email=user.email or "",
        stored_skill_level=stored,
        competency_level_override=override_raw,
        eligible_eval_count=eligible.count,
        total_practice_eval_rows=total_rows,
        eligible_quality_avg_pct=round(quality_pct, 2),
        skill_score_quality_only=round(quality_pct, 2),
        computed_skill_tier=computed_tier,
        effective_tier_after_recalc=effective,
        competency_recommended=recommended,
        stored_differs_from_computed=not tiers_equal(stored, computed_tier),
        stored_differs_from_effective=not tiers_equal(stored, effective),
        would_persist_change=not tiers_equal(stored, effective),
        override_blocks_formula=override_blocks,
    )


def audit_skill_eligibility(db: Session, *, user_id: int | None = None) -> EligibilityAuditSummary:
    """Verify eligible aggregates never include pending, withheld, rejected, or AI-confirmed rows."""
    q = (
        select(MediaEvaluation, MediaFile, AiDetectionResult)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .outerjoin(AiDetectionResult, AiDetectionResult.media_id == MediaFile.id)
        .where(MediaFile.media_category == MEDIA_CATEGORY_EVALUATION)
    )
    if user_id is not None:
        q = q.where(MediaFile.uploaded_by == user_id)

    rows = db.execute(q).all()
    leaks: list[dict[str, Any]] = []
    excluded_pending = excluded_rejected = excluded_unreleased = excluded_zero = 0
    eligible_count = 0

    for ev, media, ai in rows:
        review_status = ai.review_status if ai else None
        criteria = ev.criteria_json
        score = float(ev.overall_score or 0)
        eligible = practice_evaluation_eligible_for_skill(
            criteria_json=criteria,
            review_status=review_status,
            overall_score=score,
        )
        crit_dict: dict = {}
        if criteria:
            try:
                crit_dict = json.loads(criteria)
            except json.JSONDecodeError:
                crit_dict = {}

        if eligible:
            eligible_count += 1
            if not member_may_view_scores(crit_dict, review_status):
                leaks.append(
                    {
                        "media_id": ev.media_id,
                        "user_id": media.uploaded_by,
                        "review_status": review_status,
                        "reason": "eligible_flag_but_scores_withheld",
                    }
                )
            continue

        status = (review_status or "").strip().lower()
        if status in (
            "pending_review",
            "needs_further_review",
            "reupload_requested",
        ):
            excluded_pending += 1
        elif status in ("confirmed_ai_generated", "verified_ai_generated", "rejected"):
            excluded_rejected += 1
        elif score <= 0:
            excluded_zero += 1
        elif not member_may_view_scores(crit_dict, review_status):
            excluded_unreleased += 1
        else:
            excluded_unreleased += 1

    return EligibilityAuditSummary(
        practice_rows_scanned=len(rows),
        eligible_rows_counted=eligible_count,
        excluded_pending_or_withheld=excluded_pending,
        excluded_rejected_or_ai=excluded_rejected,
        excluded_unreleased_score=excluded_unreleased,
        excluded_zero_score=excluded_zero,
        leak_count=len(leaks),
        leak_samples=leaks[:20],
    )


def write_reports(
    *,
    db_name: str,
    members: list[MemberSkillRecalcRow],
    audit: EligibilityAuditSummary,
    report_dir: Path | None = None,
    label: str = "dry_run",
) -> dict[str, Path]:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out_dir = (report_dir or DEFAULT_REPORT_DIR) / f"{label}_{ts}"
    out_dir.mkdir(parents=True, exist_ok=True)

    csv_path = out_dir / "member_skill_recalc.csv"
    if members:
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(asdict(members[0]).keys()))
            writer.writeheader()
            for row in members:
                writer.writerow(asdict(row))

    summary = {
        "generated_at_utc": ts,
        "database": db_name,
        "approved_members": len(members),
        "would_persist_change": sum(1 for m in members if m.would_persist_change),
        "stored_differs_from_computed": sum(1 for m in members if m.stored_differs_from_computed),
        "override_active": sum(1 for m in members if m.competency_level_override),
        "eligibility_audit": asdict(audit),
        "csv": str(csv_path),
    }
    summary_path = out_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return {"dir": out_dir, "csv": csv_path, "summary": summary_path}


def print_summary(summary_path: Path) -> None:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    print(f"database={data.get('database')}")
    print(f"approved_members={data.get('approved_members')}")
    print(f"would_persist_change={data.get('would_persist_change')}")
    print(f"stored_differs_from_computed={data.get('stored_differs_from_computed')}")
    audit = data.get("eligibility_audit") or {}
    print(f"eligibility_leak_count={audit.get('leak_count')}")
    print(f"report_dir={summary_path.parent}")
