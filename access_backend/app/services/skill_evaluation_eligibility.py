"""Central rules for which practice evaluations count toward skill tier and progress."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.config import settings
from app.crud import evaluation as eval_crud
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.services.member_score_release import member_may_view_scores

# Terminal integrity outcomes — never count toward skill, regardless of stored scores.
_SKILL_EXCLUDED_REVIEW_STATUSES = frozenset(
    {
        "confirmed_ai_generated",
        "verified_ai_generated",
        "rejected",
        "reupload_requested",
        "pending_review",
        "needs_further_review",
    }
)


def _parse_criteria(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def practice_evaluation_eligible_for_skill(
    *,
    criteria_json: str | None,
    review_status: str | None,
    overall_score: float,
) -> bool:
    """True when this practice eval may affect skill averages and tier gates."""
    status = (review_status or "").strip().lower()
    if status in _SKILL_EXCLUDED_REVIEW_STATUSES:
        return False

    criteria = _parse_criteria(criteria_json)
    if not member_may_view_scores(criteria, review_status):
        return False

    if overall_score is None or float(overall_score) <= 0:
        return False

    ai = criteria.get("ai_detection") if isinstance(criteria.get("ai_detection"), dict) else {}
    verdict = str(ai.get("verdict") or "").lower()
    if verdict in ("ai_generated", "ai"):
        return False

    return True


def _is_video_media(media: MediaFile) -> bool:
    ft = (media.file_type or "").strip().lower()
    return ft == "video" or ft.startswith("video/")


def eligible_upload_calendar_date(uploaded_at: datetime | None) -> date | None:
    """Calendar date for skill progression (EVALUATION_DAILY_TIMEZONE, usually Asia/Manila)."""
    if uploaded_at is None:
        return None
    tz_name = (settings.evaluation_daily_timezone or "Asia/Manila").strip()
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo("Asia/Manila")
    if uploaded_at.tzinfo is None:
        uploaded_at = uploaded_at.replace(tzinfo=timezone.utc)
    return uploaded_at.astimezone(tz).date()


@dataclass(frozen=True)
class EligibleSkillEvaluationStats:
    count: int
    average_score: float
    photo_count: int
    video_count: int
    photo_average_score: float
    video_average_score: float
    distinct_upload_days: int


def eligible_skill_evaluation_stats(db: Session, user_id: int) -> EligibleSkillEvaluationStats:
    """Aggregates released, integrity-eligible member_evaluation rows only."""
    rows = db.scalars(
        select(MediaEvaluation)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .options(joinedload(MediaEvaluation.media))
        .where(
            MediaFile.uploaded_by == user_id,
            MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
        )
        .order_by(MediaEvaluation.evaluated_at.desc())
    ).all()

    scores: list[float] = []
    photo_scores: list[float] = []
    video_scores: list[float] = []
    upload_days: set[date] = set()

    for ev in rows:
        media = ev.media
        if media is None:
            continue
        ai = eval_crud.get_ai_for_media(db, ev.media_id)
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
