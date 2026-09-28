"""Enriched member rankings for admin leaderboard."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud import member_profile as profile_crud
from app.models.ai_detection_result import AiDetectionResult
from app.models.enums import RoleName, UserStatus
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.role import Role
from app.models.user import User
from app.services.skill_scoring import (
    build_skill_payload,
    competency_level_from_skill_score,
    effective_skill_level,
)


def _ai_counts(db: Session, user_id: int) -> tuple[int, int, int]:
    """Returns (human_verified, ai_confirmed, suspicious) based on admin review when available."""
    rows = db.execute(
        select(
            AiDetectionResult.detection_result,
            AiDetectionResult.ai_probability,
            AiDetectionResult.review_status,
        )
        .join(MediaFile, AiDetectionResult.media_id == MediaFile.id)
        .where(MediaFile.uploaded_by == user_id)
    ).all()
    human = ai_gen = suspicious = 0
    for result, prob, review_status in rows:
        status = (review_status or "pending_review").lower()
        if status == "automated_low_ai_risk":
            # PROBE low risk: not counted as admin-verified human or as a flag.
            continue
        if status in ("verified_human", "accepted_with_warning"):
            human += 1
            continue
        if status in ("confirmed_ai_generated", "verified_ai_generated", "rejected"):
            ai_gen += 1
            continue
        if status in ("needs_further_review", "reupload_requested", "pending_review"):
            label = (result or "").lower()
            if "ai" in label or "generated" in label:
                suspicious += 1
            elif prob >= 0.18:
                suspicious += 1
            else:
                human += 1
            continue
        label = (result or "").lower()
        if "ai" in label or "generated" in label:
            ai_gen += 1
        elif prob >= 0.18:
            suspicious += 1
        else:
            human += 1
    return human, ai_gen, suspicious


def _integrity_counts(db: Session, user_id: int) -> tuple[int, int]:
    """Confirmed violations vs open integrity warnings for competency review."""
    rows = db.execute(
        select(AiDetectionResult.review_status)
        .join(MediaFile, AiDetectionResult.media_id == MediaFile.id)
        .where(MediaFile.uploaded_by == user_id)
    ).all()
    violations = warnings = 0
    for (review_status,) in rows:
        status = (review_status or "pending_review").lower()
        if status in ("confirmed_ai_generated", "verified_ai_generated", "rejected"):
            violations += 1
        elif status in ("needs_further_review", "accepted_with_warning", "reupload_requested"):
            warnings += 1
    return violations, warnings


_VALID_COMPETENCY_LEVELS = frozenset({"beginner", "intermediate", "advanced"})
_OVERRIDE_UNSET = object()


def _normalize_competency_level(raw: str) -> str:
    label = raw.strip().lower()
    if label not in _VALID_COMPETENCY_LEVELS:
        raise ValueError("competency_level must be Beginner, Intermediate, or Advanced")
    return label.capitalize()


def resolve_member_skill_level(
    db: Session,
    user_id: int,
    *,
    skill_payload: dict | None = None,
    evaluation_count: int | None = None,
    level_override: str | None | object = _OVERRIDE_UNSET,
) -> tuple[str, str, str]:
    """Return (effective_level, competency_recommended, computed_level).

    effective_level is persisted on the user and shown in rankings/profile.
    When an admin override is set, it wins until cleared.
    """
    from app.models.member_ranking import MemberRanking

    if skill_payload is None:
        skill_payload = _skill_payload_for_user(db, user_id)
    if evaluation_count is None:
        evaluation_count, _ = profile_crud.evaluations_stats(db, user_id)

    override = level_override
    if override is _OVERRIDE_UNSET:
        row = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user_id))
        override = row.competency_level_override if row else None

    computed = effective_skill_level(skill_payload["skill_score"], evaluation_count)
    recommended = competency_level_from_skill_score(skill_payload["skill_score"])

    if override and str(override).strip():
        raw = str(override).strip()
        try:
            effective = _normalize_competency_level(raw)
        except ValueError:
            effective = computed
    else:
        effective = computed

    return effective, recommended, computed


def _skill_payload_for_user(db: Session, user_id: int) -> dict:
    total_uploads = profile_crud.uploads_count(db, user_id)
    approved_uploads = profile_crud.approved_uploads_count(db, user_id)
    _, avg_score = profile_crud.evaluations_stats(db, user_id)
    completed_tasks = profile_crud.assignments_completed(db, user_id)
    assigned_tasks = profile_crud.assignments_total(db, user_id)
    admin_eval = profile_crud.admin_evaluation_score(db, user_id)
    human, ai_gen, suspicious = _ai_counts(db, user_id)
    total_checked = human + ai_gen + suspicious
    return build_skill_payload(
        average_quality_score=avg_score,
        approved_uploads=approved_uploads,
        total_uploads=total_uploads,
        completed_tasks=completed_tasks,
        assigned_tasks=assigned_tasks,
        admin_evaluation_score=admin_eval,
        human_verified_uploads=human,
        total_checked_uploads=total_checked,
    )


def _ai_summary(human: int, ai_gen: int, suspicious: int) -> str:
    if human + ai_gen + suspicious == 0:
        return "No scans yet"
    parts = []
    if human:
        parts.append(f"{human} human")
    if ai_gen:
        parts.append(f"{ai_gen} AI")
    if suspicious:
        parts.append(f"{suspicious} suspicious")
    return ", ".join(parts)


def _participation_status(
    *,
    uploads: int,
    avg_score: float,
    ai_gen: int,
    suspicious: int,
    last_activity: datetime | None,
) -> str:
    if ai_gen > 0 or suspicious >= 2:
        return "under_review"
    if uploads == 0:
        return "inactive"
    if avg_score > 0 and avg_score < 0.60:
        return "needs_training"
    if uploads < 2 and avg_score < 0.70:
        return "needs_training"
    if last_activity:
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)
        la = last_activity if last_activity.tzinfo else last_activity.replace(tzinfo=timezone.utc)
        if la < cutoff:
            return "inactive"
    return "active"


def _month_start_utc() -> datetime:
    now = datetime.now(timezone.utc)
    return datetime(now.year, now.month, 1, tzinfo=timezone.utc)


def monthly_points_for_user(db: Session, user_id: int) -> int:
    """XP earned this calendar month from evaluations (same formula as media_pipeline)."""
    month_start = _month_start_utc()
    scores = db.scalars(
        select(MediaEvaluation.overall_score)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .where(
            MediaFile.uploaded_by == user_id,
            MediaEvaluation.evaluated_at >= month_start,
        )
    ).all()
    return sum(int(score * 100) for score in scores)


def list_rankings(db: Session) -> list[dict]:
    members = db.scalars(
        select(User)
        .options(joinedload(User.role), joinedload(User.member_ranking))
        .where(User.status == UserStatus.APPROVED, User.role.has(Role.role_name == RoleName.MEMBER))
    ).all()

    result: list[dict] = []
    for u in members:
        ranking = u.member_ranking
        points = ranking.total_points if ranking else 0
        monthly_points = monthly_points_for_user(db, u.id)
        total_uploads = profile_crud.uploads_count(db, u.id)
        approved_uploads = profile_crud.approved_uploads_count(db, u.id)
        eval_count, avg_score = profile_crud.evaluations_stats(db, u.id)
        completed_tasks = profile_crud.assignments_completed(db, u.id)
        assigned_tasks = profile_crud.assignments_total(db, u.id)
        admin_eval = profile_crud.admin_evaluation_score(db, u.id)
        human, ai_gen, suspicious = _ai_counts(db, u.id)
        total_checked = human + ai_gen + suspicious
        integrity_violations, integrity_warnings = _integrity_counts(db, u.id)
        last_upload = db.scalar(
            select(func.max(MediaFile.uploaded_at)).where(MediaFile.uploaded_by == u.id)
        )
        last_activity = last_upload or (ranking.updated_at if ranking else None)
        status = _participation_status(
            uploads=total_uploads,
            avg_score=avg_score,
            ai_gen=ai_gen,
            suspicious=suspicious,
            last_activity=last_activity,
        )

        skill = build_skill_payload(
            average_quality_score=avg_score,
            approved_uploads=approved_uploads,
            total_uploads=total_uploads,
            completed_tasks=completed_tasks,
            assigned_tasks=assigned_tasks,
            admin_evaluation_score=admin_eval,
            human_verified_uploads=human,
            total_checked_uploads=total_checked,
        )
        level_override = ranking.competency_level_override if ranking else None
        effective_level, competency_recommended, computed_level = resolve_member_skill_level(
            db,
            u.id,
            skill_payload=skill,
            evaluation_count=eval_count,
            level_override=level_override,
        )

        result.append(
            {
                "id": u.id,
                "user_id": u.id,
                "member_name": u.fullname,
                "name": u.fullname,
                "skill_level": effective_level,
                "computed_skill_level": computed_level,
                "skill_score": skill["skill_score"],
                "points": points,
                "monthly_points": monthly_points,
                "good_evaluations": points,
                "evaluation_count": eval_count,
                "uploads": total_uploads,
                "total_uploads": total_uploads,
                "approved_uploads": approved_uploads,
                "average_quality_score": skill["average_quality_score"],
                "avg_score": round(avg_score, 3),
                "profile_image": u.profile_image,
                "media_quality_score": skill["media_quality_score"],
                "approved_uploads_score": skill["approved_uploads_score"],
                "task_participation_score": skill["task_participation_score"],
                "completed_tasks": completed_tasks,
                "assigned_tasks": assigned_tasks,
                "admin_evaluation_score": skill["admin_evaluation_score"],
                "ai_authenticity_score": skill["ai_authenticity_score"],
                "ai_result_summary": _ai_summary(human, ai_gen, suspicious),
                "ai_human_count": human,
                "ai_flagged_count": ai_gen + suspicious,
                "participation_status": status,
                "last_activity": last_activity.isoformat() if last_activity else None,
                "admin_remarks": ranking.admin_remarks if ranking else None,
                "competency_level_override": level_override,
                "competency_recommended_level": competency_recommended,
                "integrity_violations": integrity_violations,
                "integrity_warnings": integrity_warnings,
                "rank_position": ranking.rank_position if ranking else None,
            }
        )

    result.sort(key=lambda x: (x["skill_score"], x["points"], x["uploads"]), reverse=True)
    for idx, row in enumerate(result, start=1):
        row["rank"] = idx
        row["rank_position"] = idx
    return result


def rankings_summary(rows: list[dict]) -> dict:
    if not rows:
        return {
            "total_ranked": 0,
            "top_performer_name": "—",
            "top_performer_points": 0,
            "most_active_uploader_name": "—",
            "most_active_uploads": 0,
            "needs_improvement_count": 0,
        }

    top = rows[0]
    most_uploads = max(rows, key=lambda r: r["uploads"])
    needs = sum(
        1
        for r in rows
        if r["participation_status"] in ("needs_training", "inactive")
        or (r.get("skill_score") or 0) < 60
    )

    return {
        "total_ranked": len(rows),
        "top_performer_name": top["member_name"],
        "top_performer_points": top["points"],
        "most_active_uploader_name": most_uploads["member_name"],
        "most_active_uploads": most_uploads["uploads"],
        "needs_improvement_count": needs,
    }


def update_admin_remarks(db: Session, user_id: int, remarks: str | None) -> None:
    from app.crud.member_ranking import get_or_create

    row = get_or_create(db, user_id)
    row.admin_remarks = remarks
    db.commit()


def update_competency_level(db: Session, user_id: int, competency_level: str | None) -> dict:
    """Set admin competency override, or clear it to use the system recommendation."""
    from app.crud.member_ranking import get_or_create
    from app.crud.user import _skill_level_id_for_name, get_by_id

    user = get_by_id(db, user_id)
    if not user:
        raise ValueError("User not found")

    row = get_or_create(db, user_id)
    skill = _skill_payload_for_user(db, user_id)

    if competency_level is None or not str(competency_level).strip():
        row.competency_level_override = None
    else:
        row.competency_level_override = _normalize_competency_level(competency_level)

    effective, recommended, computed = resolve_member_skill_level(
        db,
        user_id,
        skill_payload=skill,
        level_override=row.competency_level_override,
    )

    skill_id = _skill_level_id_for_name(db, effective)
    if skill_id:
        user.skill_level_id = skill_id

    db.commit()
    db.refresh(row)
    return {
        "competency_level_override": row.competency_level_override,
        "competency_recommended_level": recommended,
        "computed_skill_level": computed,
        "effective_level": effective,
        "skill_level": effective,
    }
