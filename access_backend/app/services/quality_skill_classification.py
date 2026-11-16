"""Media quality Skill Classification (Photo/Video).

Separate from XP, achievements, competency_level_override, and skill progression
tiers (Beginner/Intermediate/Advanced/Expert on 0–100 skill_score).

This module classifies measured practice quality on the 1–5 overall scale using
Clarity Option C (v2) comparable evaluations only.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.crud import evaluation as eval_crud
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.services.media_evaluator import SCORING_FORMULA_V2
from app.services.skill_evaluation_eligibility import (
    practice_evaluation_eligible_for_skill,
)

MediaKind = Literal["photo", "video"]

NOT_YET_CLASSIFIED = "Not Yet Classified"
WINDOW_SIZE = 10
MIN_EVALS_TO_CLASSIFY = 3

# Highest-first: title, minimum unrounded average (/5), minimum qualifying count.
# Score bands are inclusive at the lower bound; Expert also covers up to 5.00.
_CLASSIFICATION_LADDER: tuple[tuple[str, float, int], ...] = (
    ("Expert", 4.50, 10),
    ("Advanced", 4.00, 8),
    ("Proficient", 3.00, 5),
    ("Developing", 2.00, 3),
    ("Beginner", 0.00, 3),
)

_TITLE_META: dict[str, dict[str, str]] = {
    "Beginner": {
        "meaning": "Learning the fundamentals of media quality.",
        "score_range": "0.00–1.99 / 5",
        "focus": "Steady framing, basic focus, and even lighting.",
    },
    "Developing": {
        "meaning": "Building basic technical skills and improving consistency.",
        "score_range": "2.00–2.99 / 5",
        "focus": "Reduce blur, improve exposure, and keep composition intentional.",
    },
    "Proficient": {
        "meaning": "Producing generally good-quality photos or videos.",
        "score_range": "3.00–3.99 / 5",
        "focus": "Consistent sharpness, balanced color, and clearer storytelling frames.",
    },
    "Advanced": {
        "meaning": "Consistently producing high-quality evaluated media.",
        "score_range": "4.00–4.49 / 5",
        "focus": "Refine detail, stability (for video), and repeatable quality under varied conditions.",
    },
    "Expert": {
        "meaning": "Demonstrating consistently excellent measured media quality.",
        "score_range": "4.50–5.00 / 5",
        "focus": "Maintain excellence across sessions; one strong upload alone does not grant Expert.",
    },
}


def overall_score_to_five(overall_score: float | None) -> float | None:
    """DB overall is typically 0–1; criteria may store 1–5. Never invent scores."""
    if overall_score is None:
        return None
    value = float(overall_score)
    if value <= 0:
        return None
    if value <= 1.0:
        return value * 5.0
    if value <= 5.0:
        return value
    # Unexpected 0–100 legacy: scale down.
    if value <= 100.0:
        return value / 20.0
    return None


def round_score_for_display(score_five: float | None) -> float | None:
    if score_five is None:
        return None
    return round(float(score_five), 2)


def _parse_criteria(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def scoring_formula_version(criteria_json: str | None) -> str:
    criteria = _parse_criteria(criteria_json)
    raw = str(criteria.get("scoring_formula_version") or "").strip().lower()
    if raw in {"v1", "v2"}:
        return raw
    analysis = criteria.get("analysis")
    if isinstance(analysis, dict):
        nested = str(analysis.get("scoring_formula_version") or "").strip().lower()
        if nested in {"v1", "v2"}:
            return nested
    return "v1"


def _is_video_media(media: MediaFile, criteria_json: str | None) -> bool:
    ft = (media.file_type or "").strip().lower()
    if ft == "video" or ft.startswith("video/"):
        return True
    name = (media.file_name or "").lower()
    url = (media.file_url or "").split("?", 1)[0].lower()
    for ext in (".mp4", ".mov", ".webm", ".mkv", ".avi"):
        if name.endswith(ext) or url.endswith(ext):
            return True
    criteria = _parse_criteria(criteria_json)
    mt = str(criteria.get("media_type") or "").strip().lower()
    return mt == "video"


def _aware(dt: datetime | None) -> datetime:
    if dt is None:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


@dataclass(frozen=True)
class ClassificationProgress:
    next_title: str | None
    score_gap: float | None
    evaluations_gap: int | None
    summary: str


@dataclass(frozen=True)
class MediaQualityClassification:
    media_kind: MediaKind
    title: str
    average_score: float | None
    average_score_display: float | None
    qualifying_evaluations: int
    window_size: int
    formula_version: str | None
    next_title: str | None
    score_gap: float | None
    evaluations_gap: int | None
    progress_summary: str
    classified: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class MemberQualitySkillClassification:
    photo: MediaQualityClassification
    video: MediaQualityClassification
    disclaimer: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "photo": self.photo.to_dict(),
            "video": self.video.to_dict(),
            "disclaimer": self.disclaimer,
            # Convenience mirrors for Admin / compact cards.
            "photo_title": self.photo.title,
            "video_title": self.video.title,
        }


def classification_guide() -> list[dict[str, Any]]:
    """Educational payload for About Skill Levels (not certifications)."""
    guide: list[dict[str, Any]] = []
    ordered = list(reversed(_CLASSIFICATION_LADDER))  # Beginner → Expert
    for i, (title, _min_score, min_count) in enumerate(ordered):
        meta = _TITLE_META[title]
        next_title = ordered[i + 1][0] if i + 1 < len(ordered) else None
        next_req = None
        if next_title is not None:
            n_min_score, n_min_count = next(
                (s, c) for t, s, c in _CLASSIFICATION_LADDER if t == next_title
            )
            next_req = {
                "title": next_title,
                "minimum_average_score": n_min_score,
                "minimum_evaluations": n_min_count,
            }
        guide.append(
            {
                "title": title,
                "meaning": meta["meaning"],
                "score_range": meta["score_range"],
                "minimum_evaluations": min_count,
                "focus": meta["focus"],
                "next": next_req,
            }
        )
    return guide


def _progress_toward_next(
    *,
    current_title: str,
    average_five: float,
    count: int,
) -> ClassificationProgress:
    if current_title == NOT_YET_CLASSIFIED:
        need = MIN_EVALS_TO_CLASSIFY - count
        return ClassificationProgress(
            next_title="Beginner",
            score_gap=None,
            evaluations_gap=max(0, need),
            summary=(
                "Complete at least 3 qualifying evaluations using the current scoring "
                "system to unlock your first skill classification."
            ),
        )
    if current_title == "Expert":
        return ClassificationProgress(
            next_title=None,
            score_gap=None,
            evaluations_gap=None,
            summary="Highest classification reached for this media type.",
        )

    # Find the next higher title on the ladder.
    titles_high_first = [t for t, _, _ in _CLASSIFICATION_LADDER]
    idx = titles_high_first.index(current_title)
    next_title, next_min_score, next_min_count = _CLASSIFICATION_LADDER[idx - 1]

    score_gap = max(0.0, next_min_score - average_five)
    evals_gap = max(0, next_min_count - count)
    parts: list[str] = []
    if evals_gap > 0:
        parts.append(
            f"{evals_gap} more qualifying evaluation{'s' if evals_gap != 1 else ''}"
        )
    if score_gap > 0:
        parts.append(f"raise average by {round_score_for_display(score_gap):.2f}")
    if not parts:
        summary = f"Requirements for {next_title} are met on the next refresh."
    else:
        summary = f"Toward {next_title}: need " + " and ".join(parts) + "."
    return ClassificationProgress(
        next_title=next_title,
        score_gap=round_score_for_display(score_gap) if score_gap > 0 else 0.0,
        evaluations_gap=evals_gap,
        summary=summary,
    )


def classify_from_scores(
    scores_five_newest_first: list[float],
    *,
    media_kind: MediaKind,
    formula_version: str | None,
) -> MediaQualityClassification:
    """Pure classifier — scores must already be on the 1–5 scale, newest first."""
    window = list(scores_five_newest_first[:WINDOW_SIZE])
    count = len(window)
    if count < MIN_EVALS_TO_CLASSIFY:
        progress = _progress_toward_next(
            current_title=NOT_YET_CLASSIFIED,
            average_five=0.0,
            count=count,
        )
        return MediaQualityClassification(
            media_kind=media_kind,
            title=NOT_YET_CLASSIFIED,
            average_score=None,
            average_score_display=None,
            qualifying_evaluations=count,
            window_size=WINDOW_SIZE,
            formula_version=formula_version,
            next_title=progress.next_title,
            score_gap=progress.score_gap,
            evaluations_gap=progress.evaluations_gap,
            progress_summary=progress.summary,
            classified=False,
        )

    # Unrounded mean for threshold decisions.
    average = sum(window) / count
    title = NOT_YET_CLASSIFIED
    for candidate, min_score, min_count in _CLASSIFICATION_LADDER:
        if average >= min_score and count >= min_count:
            title = candidate
            break

    progress = _progress_toward_next(
        current_title=title,
        average_five=average,
        count=count,
    )
    return MediaQualityClassification(
        media_kind=media_kind,
        title=title,
        average_score=average,
        average_score_display=round_score_for_display(average),
        qualifying_evaluations=count,
        window_size=WINDOW_SIZE,
        formula_version=formula_version,
        next_title=progress.next_title,
        score_gap=progress.score_gap,
        evaluations_gap=progress.evaluations_gap,
        progress_summary=progress.summary,
        classified=title != NOT_YET_CLASSIFIED,
    )


def _collect_comparable_scores(
    db: Session,
    user_id: int,
    *,
    preferred_formula: str = SCORING_FORMULA_V2,
) -> tuple[list[float], list[float], str | None]:
    """Return (photo_scores_newest_first, video_scores_newest_first, formula)."""
    rows = db.scalars(
        select(MediaEvaluation)
        .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
        .options(joinedload(MediaEvaluation.media))
        .where(
            MediaFile.uploaded_by == user_id,
            MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
        )
        .order_by(MediaEvaluation.evaluated_at.desc(), MediaEvaluation.id.desc())
    ).all()

    photo: list[float] = []
    video: list[float] = []
    formula_used: str | None = None

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
        version = scoring_formula_version(ev.criteria_json)
        if version != preferred_formula:
            # Do not mix incompatible scoring versions into the same classification.
            continue
        five = overall_score_to_five(ev.overall_score)
        if five is None:
            continue
        formula_used = preferred_formula
        if _is_video_media(media, ev.criteria_json):
            if len(video) < WINDOW_SIZE:
                video.append(five)
        else:
            if len(photo) < WINDOW_SIZE:
                photo.append(five)
        if len(photo) >= WINDOW_SIZE and len(video) >= WINDOW_SIZE:
            break

    return photo, video, formula_used


def classify_member_quality_skills(
    db: Session,
    user_id: int,
    *,
    preferred_formula: str = SCORING_FORMULA_V2,
) -> MemberQualitySkillClassification:
    photo_scores, video_scores, formula = _collect_comparable_scores(
        db,
        user_id,
        preferred_formula=preferred_formula,
    )
    disclaimer = (
        "Classifications are automated media-quality assessments from ACCESS VisionCheck "
        "practice evaluations. Photo and Video are separate. XP and achievements are separate. "
        "Older incompatible scoring versions are excluded. These titles are not professional certifications."
    )
    return MemberQualitySkillClassification(
        photo=classify_from_scores(
            photo_scores,
            media_kind="photo",
            formula_version=formula if photo_scores else None,
        ),
        video=classify_from_scores(
            video_scores,
            media_kind="video",
            formula_version=formula if video_scores else None,
        ),
        disclaimer=disclaimer,
    )


def admin_classification_summary(db: Session, user_id: int) -> dict[str, Any]:
    snap = classify_member_quality_skills(db, user_id)
    return {
        "quality_skill_photo_title": snap.photo.title,
        "quality_skill_video_title": snap.video.title,
        "quality_skill_photo_average": snap.photo.average_score_display,
        "quality_skill_video_average": snap.video.average_score_display,
        "quality_skill_photo_evaluations": snap.photo.qualifying_evaluations,
        "quality_skill_video_evaluations": snap.video.qualifying_evaluations,
    }
