"""Enriched member rankings for admin leaderboard."""

from __future__ import annotations

import logging
import time
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.crud import member_profile as profile_crud
from app.models.ai_detection_result import AiDetectionResult
from app.models.enums import RoleName, UserStatus
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.request_assignment import RequestAssignment
from app.models.role import Role
from app.models.submission_chain import SubmissionChain
from app.models.user import User
from app.services.supabase_storage import apply_display_profile_images
from app.services.skill_evaluation_eligibility import (
    EligibleSkillEvaluationStats,
    _is_video_media,
    eligible_skill_evaluation_stats,
    eligible_upload_calendar_date,
    practice_evaluation_eligible_for_skill,
)
from app.services.skill_scoring import (
    build_skill_payload,
    competency_level_from_skill_score,
    effective_skill_level,
)

logger = logging.getLogger("ACCESS.api")


def _classify_ai_rows(rows) -> tuple[int, int, int]:
    """Returns (human_verified, ai_confirmed, suspicious) for already loaded detection rows."""
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
    return _classify_ai_rows(rows)


def _integrity_from_statuses(statuses) -> tuple[int, int]:
    """Confirmed violations vs open integrity warnings for competency review."""
    violations = warnings = 0
    for review_status in statuses:
        status = (review_status or "pending_review").lower()
        if status in ("confirmed_ai_generated", "verified_ai_generated", "rejected"):
            violations += 1
        elif status in ("needs_further_review", "accepted_with_warning", "reupload_requested"):
            warnings += 1
    return violations, warnings


def _integrity_counts(db: Session, user_id: int) -> tuple[int, int]:
    rows = db.execute(
        select(AiDetectionResult.review_status)
        .join(MediaFile, AiDetectionResult.media_id == MediaFile.id)
        .where(MediaFile.uploaded_by == user_id)
    ).all()
    return _integrity_from_statuses(status for (status,) in rows)


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
    distinct_upload_days: int | None = None,
    ranking_row: object = _OVERRIDE_UNSET,
    resolved_policy: tuple[str, str | None] | None = None,
) -> tuple[str, str, str]:
    """Return (effective_level, competency_recommended, computed_level).

    effective_level is persisted on the user and shown in rankings/profile.
    When an admin override is set, it wins until cleared.
    """
    from app.services.skill_progression import build_skill_progression_snapshot

    score_override = None
    if skill_payload is not None:
        score_override = float(skill_payload.get("skill_score") or 0)
    snapshot_kwargs: dict = {}
    if ranking_row is not _OVERRIDE_UNSET:
        snapshot_kwargs["ranking_row"] = ranking_row
    if resolved_policy is not None:
        snapshot_kwargs["resolved_policy"] = resolved_policy
    snap = build_skill_progression_snapshot(
        db,
        user_id,
        skill_score_pct=score_override,
        eligible_count=evaluation_count,
        distinct_days=distinct_upload_days,
        level_override=level_override,
        **snapshot_kwargs,
    )
    return snap.effective_tier, snap.competency_recommended, snap.computed_tier_active


def _skill_payload_for_user(db: Session, user_id: int) -> dict:
    total_uploads = profile_crud.uploads_count(db, user_id)
    approved_uploads = profile_crud.approved_uploads_count(db, user_id)
    eligible = eligible_skill_evaluation_stats(db, user_id)
    avg_score = eligible.average_score
    completed_tasks = profile_crud.assignments_completed(db, user_id)
    assigned_tasks = profile_crud.assignments_total(db, user_id)
    admin_eval = profile_crud.admin_evaluation_score(db, user_id)
    human, ai_gen, suspicious = _ai_counts(db, user_id)
    total_checked = human + ai_gen + suspicious
    payload = build_skill_payload(
        average_quality_score=avg_score,
        approved_uploads=approved_uploads,
        total_uploads=total_uploads,
        completed_tasks=completed_tasks,
        assigned_tasks=assigned_tasks,
        admin_evaluation_score=admin_eval,
        human_verified_uploads=human,
        total_checked_uploads=total_checked,
    )
    payload["skill_eligible_evaluation_count"] = eligible.count
    payload["skill_eligible_distinct_upload_days"] = eligible.distinct_upload_days
    payload["skill_eligible_photo_count"] = eligible.photo_count
    payload["skill_eligible_video_count"] = eligible.video_count
    payload["skill_eligible_photo_average"] = round(
        eligible.photo_average_score * 100.0 if eligible.photo_average_score <= 1.0 else eligible.photo_average_score,
        2,
    )
    payload["skill_eligible_video_average"] = round(
        eligible.video_average_score * 100.0 if eligible.video_average_score <= 1.0 else eligible.video_average_score,
        2,
    )
    return payload


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
    """XP awarded this UTC calendar month from submission-chain awards.

    Attribution policy: use ``submission_chains.xp_awarded_at`` (when XP was
    actually credited), including delayed admin releases that cross a month
    boundary. Amount is ``xp_awarded_total`` (already rounded at award time).

    Chains with awarded points but a missing ``xp_awarded_at`` are excluded
    (cannot attribute safely). Legacy awards without a chain row are not
    reconstructed from evaluation scores; they remain in all-time
    ``member_rankings.total_points`` only.
    """
    month_start = _month_start_utc()
    total = db.scalar(
        select(func.coalesce(func.sum(SubmissionChain.xp_awarded_total), 0)).where(
            SubmissionChain.member_id == user_id,
            SubmissionChain.xp_awarded_total > 0,
            SubmissionChain.xp_awarded_at.is_not(None),
            SubmissionChain.xp_awarded_at >= month_start,
        )
    )
    return int(total or 0)


_ACCEPTED_ASSIGNMENT_STATUSES = frozenset({"accepted", "in_progress", "completed", "done"})


def _display_hundred(score: float) -> float:
    return round(score * 100.0 if score <= 1.0 else score, 2)


def _ai_is_later(candidate: AiDetectionResult, current: AiDetectionResult) -> bool:
    """Match ``ORDER BY created_at DESC NULLS FIRST``, then higher id."""
    candidate_missing = candidate.created_at is None
    current_missing = current.created_at is None
    if candidate_missing != current_missing:
        return candidate_missing
    if candidate.created_at != current.created_at:
        return (candidate.created_at or current.created_at) > (current.created_at or candidate.created_at)
    return candidate.id > current.id


def _eligible_from_evaluations(evaluations, latest_ai: dict[int, AiDetectionResult]) -> EligibleSkillEvaluationStats:
    scores: list[float] = []
    photo_scores: list[float] = []
    video_scores: list[float] = []
    upload_days: set = set()
    for ev in evaluations:
        media = ev.media
        if media is None or media.media_category != MEDIA_CATEGORY_EVALUATION:
            continue
        ai = latest_ai.get(ev.media_id)
        review_status = ai.review_status if ai else None
        if not practice_evaluation_eligible_for_skill(
            criteria_json=ev.criteria_json,
            review_status=review_status,
            overall_score=float(ev.overall_score or 0),
        ):
            continue
        score = float(ev.overall_score)
        scores.append(score)
        day = eligible_upload_calendar_date(media.uploaded_at)
        if day is not None:
            upload_days.add(day)
        if _is_video_media(media):
            video_scores.append(score)
        else:
            photo_scores.append(score)

    def _avg(values: list[float]) -> float:
        if not values:
            return 0.0
        return sum(values) / len(values)

    return EligibleSkillEvaluationStats(
        count=len(scores),
        average_score=_avg(scores),
        photo_count=len(photo_scores),
        video_count=len(video_scores),
        photo_average_score=_avg(photo_scores),
        video_average_score=_avg(video_scores),
        distinct_upload_days=len(upload_days),
    )


def _admin_score_from_evaluations(evaluations) -> float:
    rows = [
        ev.overall_score
        for ev in evaluations
        if ev.feedback is not None and ev.feedback != ""
    ]
    if not rows:
        return 0.0
    avg = sum(rows) / len(rows)
    return round(avg * 100.0 if avg <= 1.0 else min(100.0, avg), 2)


def _evaluation_average(evaluations) -> float:
    """Second value of ``evaluations_stats``: mean of stored overall scores, not a row count."""
    if not evaluations:
        return 0.0
    return sum(ev.overall_score for ev in evaluations) / len(evaluations)


def _skill_payload_from_stats(
    *,
    eligible: EligibleSkillEvaluationStats,
    total_uploads: int,
    approved_uploads: int,
    completed_tasks: int,
    assigned_tasks: int,
    admin_eval: float,
    human: int,
    total_checked: int,
) -> dict:
    payload = build_skill_payload(
        average_quality_score=eligible.average_score,
        approved_uploads=approved_uploads,
        total_uploads=total_uploads,
        completed_tasks=completed_tasks,
        assigned_tasks=assigned_tasks,
        admin_evaluation_score=admin_eval,
        human_verified_uploads=human,
        total_checked_uploads=total_checked,
    )
    payload["skill_eligible_evaluation_count"] = eligible.count
    payload["skill_eligible_distinct_upload_days"] = eligible.distinct_upload_days
    payload["skill_eligible_photo_count"] = eligible.photo_count
    payload["skill_eligible_video_count"] = eligible.video_count
    payload["skill_eligible_photo_average"] = _display_hundred(eligible.photo_average_score)
    payload["skill_eligible_video_average"] = _display_hundred(eligible.video_average_score)
    return payload


def list_rankings(db: Session) -> list[dict]:
    started = time.perf_counter()
    members = db.scalars(
        select(User)
        .options(joinedload(User.role), joinedload(User.member_ranking))
        .where(User.status == UserStatus.APPROVED, User.role.has(Role.role_name == RoleName.MEMBER))
    ).unique().all()

    ids = [u.id for u in members]
    monthly_by_user: dict[int, int] = {}
    uploads_by_user: dict[int, int] = {}
    last_upload_by_user: dict[int, object] = {}
    assigned_by_user: dict[int, int] = {}
    completed_by_user: dict[int, int] = {}
    evals_by_user: dict[int, list] = {user_id: [] for user_id in ids}
    ai_by_user: dict[int, list] = {user_id: [] for user_id in ids}
    latest_ai_by_media: dict[int, AiDetectionResult] = {}

    if ids:
        month_start = _month_start_utc()
        for user_id, total in db.execute(
            select(
                SubmissionChain.member_id,
                func.coalesce(func.sum(SubmissionChain.xp_awarded_total), 0),
            )
            .where(
                SubmissionChain.member_id.in_(ids),
                SubmissionChain.xp_awarded_total > 0,
                SubmissionChain.xp_awarded_at.is_not(None),
                SubmissionChain.xp_awarded_at >= month_start,
            )
            .group_by(SubmissionChain.member_id)
        ):
            monthly_by_user[user_id] = int(total or 0)

        for user_id, count, last_upload in db.execute(
            select(
                MediaFile.uploaded_by,
                func.count(),
                func.max(MediaFile.uploaded_at),
            )
            .where(MediaFile.uploaded_by.in_(ids))
            .group_by(MediaFile.uploaded_by)
        ):
            uploads_by_user[user_id] = int(count or 0)
            last_upload_by_user[user_id] = last_upload

        for user_id, status_name, count in db.execute(
            select(
                RequestAssignment.member_id,
                RequestAssignment.status,
                func.count(),
            )
            .where(RequestAssignment.member_id.in_(ids))
            .group_by(RequestAssignment.member_id, RequestAssignment.status)
        ):
            assigned_by_user[user_id] = assigned_by_user.get(user_id, 0) + int(count or 0)
            if status_name in _ACCEPTED_ASSIGNMENT_STATUSES:
                completed_by_user[user_id] = completed_by_user.get(user_id, 0) + int(count or 0)

        evaluations = db.scalars(
            select(MediaEvaluation)
            .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
            .options(joinedload(MediaEvaluation.media))
            .where(MediaFile.uploaded_by.in_(ids))
        ).unique().all()
        for ev in evaluations:
            owner = ev.media.uploaded_by if ev.media is not None else None
            if owner in evals_by_user:
                evals_by_user[owner].append(ev)

        for owner_id, detection in db.execute(
            select(MediaFile.uploaded_by, AiDetectionResult)
            .join(MediaFile, AiDetectionResult.media_id == MediaFile.id)
            .where(MediaFile.uploaded_by.in_(ids))
        ):
            if owner_id in ai_by_user:
                ai_by_user[owner_id].append(detection)
            current = latest_ai_by_media.get(detection.media_id)
            if current is None or _ai_is_later(detection, current):
                latest_ai_by_media[detection.media_id] = detection

    from app.services.skill_progression import resolve_effective_skill_progression_policy

    resolved_policy = resolve_effective_skill_progression_policy(db)
    result: list[dict] = []
    for u in members:
        ranking = u.member_ranking
        points = ranking.total_points if ranking else 0
        monthly_points = monthly_by_user.get(u.id, 0)
        user_evals = evals_by_user.get(u.id, [])
        total_uploads = uploads_by_user.get(u.id, 0)
        approved_uploads = len({
            ev.media_id
            for ev in user_evals
            if ev.overall_score is not None and ev.overall_score >= 0.60
        })
        eligible = _eligible_from_evaluations(user_evals, latest_ai_by_media)
        eval_count = eligible.count
        avg_score = eligible.average_score
        all_eval_count = _evaluation_average(user_evals)
        completed_tasks = completed_by_user.get(u.id, 0)
        assigned_tasks = assigned_by_user.get(u.id, 0)
        admin_eval = _admin_score_from_evaluations(user_evals)
        human, ai_gen, suspicious = _classify_ai_rows(
            (row.detection_result, row.ai_probability, row.review_status) for row in ai_by_user.get(u.id, [])
        )
        total_checked = human + ai_gen + suspicious
        integrity_violations, integrity_warnings = _integrity_from_statuses(
            row.review_status for row in ai_by_user.get(u.id, [])
        )
        last_upload = last_upload_by_user.get(u.id)
        last_activity = last_upload or (ranking.updated_at if ranking else None)
        status = _participation_status(
            uploads=total_uploads,
            avg_score=avg_score,
            ai_gen=ai_gen,
            suspicious=suspicious,
            last_activity=last_activity,
        )

        skill = _skill_payload_from_stats(
            eligible=eligible,
            total_uploads=total_uploads,
            approved_uploads=approved_uploads,
            completed_tasks=completed_tasks,
            assigned_tasks=assigned_tasks,
            admin_eval=admin_eval,
            human=human,
            total_checked=total_checked,
        )
        level_override = ranking.competency_level_override if ranking else None
        effective_level, competency_recommended, computed_level = resolve_member_skill_level(
            db,
            u.id,
            skill_payload=skill,
            evaluation_count=eval_count,
            distinct_upload_days=eligible.distinct_upload_days,
            level_override=level_override,
            ranking_row=ranking,
            resolved_policy=resolved_policy,
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
                "total_evaluation_rows": all_eval_count,
                "skill_eligible_photo_count": skill.get("skill_eligible_photo_count", 0),
                "skill_eligible_video_count": skill.get("skill_eligible_video_count", 0),
                "skill_eligible_photo_average": skill.get("skill_eligible_photo_average", 0),
                "skill_eligible_video_average": skill.get("skill_eligible_video_average", 0),
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

    # Skill-oriented order for admin/competency surfaces (unchanged).
    result.sort(key=lambda x: (x["skill_score"], x["points"], x["uploads"]), reverse=True)
    for idx, row in enumerate(result, start=1):
        row["rank"] = idx
        row["rank_position"] = idx

    assign_xp_rank_positions(result)
    apply_display_profile_images(result)
    logger.info(
        "list_rankings members=%s seconds=%.3f",
        len(members),
        time.perf_counter() - started,
    )
    return result


def assign_xp_rank_positions(rows: list[dict]) -> None:
    """Set ``xp_rank_position`` from all-time awarded XP (points), independent of skill sort.

    Ordering: XP descending, name ascending (case-insensitive), user_id ascending.
    """
    xp_ordered = sorted(
        rows,
        key=lambda x: (
            -int(x.get("points") or 0),
            str(x.get("name") or "").lower(),
            int(x.get("user_id") or 0),
        ),
    )
    for idx, row in enumerate(xp_ordered, start=1):
        row["xp_rank_position"] = idx


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
