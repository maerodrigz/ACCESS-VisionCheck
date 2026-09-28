from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.ai_detection_result import AiDetectionResult
from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile


def list_all(db: Session) -> list[MediaEvaluation]:
    return list(
        db.scalars(
            select(MediaEvaluation)
            .options(
                joinedload(MediaEvaluation.media).joinedload(MediaFile.uploader),
                joinedload(MediaEvaluation.media).joinedload(MediaFile.request),
            )
            .order_by(MediaEvaluation.evaluated_at.desc())
        )
    )


def list_all_ai(db: Session) -> list[AiDetectionResult]:
    return list(
        db.scalars(
            select(AiDetectionResult)
            .options(
                joinedload(AiDetectionResult.media).joinedload(MediaFile.uploader),
            )
            .order_by(AiDetectionResult.created_at.desc())
        )
    )


def list_for_user(db: Session, user_id: int) -> list[MediaEvaluation]:
    return list(
        db.scalars(
            select(MediaEvaluation)
            .join(MediaFile, MediaEvaluation.media_id == MediaFile.id)
            .options(joinedload(MediaEvaluation.media))
            .where(
                MediaFile.uploaded_by == user_id,
                MediaFile.media_category == MEDIA_CATEGORY_EVALUATION,
            )
            .order_by(MediaEvaluation.evaluated_at.desc())
        )
    )


def get_for_media(db: Session, media_id: int) -> MediaEvaluation | None:
    return db.scalar(
        select(MediaEvaluation)
        .where(MediaEvaluation.media_id == media_id)
        .order_by(MediaEvaluation.evaluated_at.desc())
    )


def get_by_id(db: Session, evaluation_id: int) -> MediaEvaluation | None:
    return db.scalar(
        select(MediaEvaluation)
        .options(
            joinedload(MediaEvaluation.media).joinedload(MediaFile.uploader),
            joinedload(MediaEvaluation.media).joinedload(MediaFile.request),
        )
        .where(MediaEvaluation.id == evaluation_id)
    )


def update_feedback(db: Session, evaluation: MediaEvaluation, feedback: str | None) -> MediaEvaluation:
    evaluation.feedback = feedback
    db.commit()
    db.refresh(evaluation)
    return evaluation


def summary_stats(db: Session) -> dict:
    rows = list_all(db)
    total = len(rows)
    if total == 0:
        return {
            "total_evaluated": 0,
            "average_overall_score": 0.0,
            "human_media_count": 0,
            "ai_suspicious_count": 0,
        }
    avg = sum(r.overall_score for r in rows) / total
    human = 0
    ai_suspicious = 0
    for ev in rows:
        ai = get_ai_for_media(db, ev.media_id)
        if not ai or not ai.detection_result:
            ai_suspicious += 1
        elif ai.detection_result == "human":
            human += 1
        else:
            ai_suspicious += 1
    return {
        "total_evaluated": total,
        "average_overall_score": round(avg, 3),
        "human_media_count": human,
        "ai_suspicious_count": ai_suspicious,
    }


def create_evaluation(db: Session, data: dict) -> MediaEvaluation:
    row = MediaEvaluation(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_ai_for_media(db: Session, media_id: int) -> AiDetectionResult | None:
    return db.scalar(
        select(AiDetectionResult)
        .where(AiDetectionResult.media_id == media_id)
        .order_by(AiDetectionResult.created_at.desc())
    )


def get_ai_by_id(db: Session, ai_id: int) -> AiDetectionResult | None:
    return db.scalar(
        select(AiDetectionResult)
        .options(joinedload(AiDetectionResult.media).joinedload(MediaFile.uploader))
        .where(AiDetectionResult.id == ai_id)
    )


def update_ai_review(
    db: Session,
    row: AiDetectionResult,
    *,
    review_status: str | None = None,
    admin_remarks: str | None = None,
    reviewed_by_admin: bool | None = None,
    reviewed_by: int | None = None,
) -> AiDetectionResult:
    from app.services.ai_review_workflow import apply_ai_review

    if reviewed_by is not None or review_status is not None:
        return apply_ai_review(
            db,
            row,
            review_status=review_status,
            admin_remarks=admin_remarks,
            reviewed_by=reviewed_by,
        )
    if admin_remarks is not None:
        row.admin_remarks = admin_remarks
    if reviewed_by_admin is not None:
        row.reviewed_by_admin = reviewed_by_admin
    db.commit()
    db.refresh(row)
    return row


def ai_detection_summary(db: Session) -> dict:
    rows = list_all_ai(db)
    total = len(rows)
    human = 0
    ai_gen = 0
    suspicious = 0
    pending_review = 0
    for row in rows:
        label = row.detection_result or ""
        prob = row.ai_probability
        status = (row.review_status or "pending_review").lower()
        if status in ("pending_review", "needs_further_review"):
            pending_review += 1
        if "ai" in label.lower() or "generated" in label.lower():
            ai_gen += 1
        elif prob >= 0.18:
            suspicious += 1
        else:
            human += 1
    return {
        "total_scanned": total,
        "human_count": human,
        "ai_generated_count": ai_gen,
        "suspicious_count": suspicious,
        "pending_review_count": pending_review,
    }


def create_ai_result(db: Session, data: dict) -> AiDetectionResult:
    row = AiDetectionResult(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row
