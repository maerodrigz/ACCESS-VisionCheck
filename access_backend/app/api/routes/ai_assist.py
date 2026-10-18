"""Authenticated Gemini proxy — keeps API keys on the server."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_approved
from app.crud import system_settings as settings_crud
from app.database import get_db
from app.models.user import User
from app.schemas.ai_assist import (
    AdminDailySummaryIn,
    AdminDailySummaryOut,
    MediaEvaluationFeedbackIn,
    MediaEvaluationFeedbackOut,
    RubricFeedbackIn,
    RubricFeedbackOut,
)
from app.services import gemini_service

router = APIRouter(prefix="/ai", tags=["AI Assist"])


@router.post("/media-evaluation-feedback", response_model=MediaEvaluationFeedbackOut)
def media_evaluation_feedback(
    body: MediaEvaluationFeedbackIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
) -> MediaEvaluationFeedbackOut:
    if not settings_crud.is_ai_media_evaluation_enabled(db):
        raise HTTPException(
            status_code=503,
            detail="AI media evaluation is disabled by the system administrator.",
        )
    ev = body.evaluation if isinstance(body.evaluation, dict) else {}
    if ev.get("member_scores_released") is False:
        raise HTTPException(
            status_code=403,
            detail="Evaluation scores are held until administrative review completes.",
        )
    ai = ev.get("ai_detection") if isinstance(ev.get("ai_detection"), dict) else {}
    if ai.get("requires_review") is True:
        raise HTTPException(
            status_code=403,
            detail="Evaluation scores are held until administrative review completes.",
        )
    first_name = gemini_service.first_name_from_fullname(current_user.fullname)
    feedback = gemini_service.generate_media_evaluation_feedback(
        body.evaluation,
        member_first_name=first_name,
    )
    if feedback is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Gemini feedback is temporarily unavailable. "
                "Check GEMINI_API_KEY and GEMINI_MODEL in the backend .env, then restart the server."
            ),
        )
    return MediaEvaluationFeedbackOut(feedback=feedback)


@router.post("/rubric-feedback", response_model=RubricFeedbackOut)
def rubric_feedback(
    body: RubricFeedbackIn,
    _: User = Depends(require_approved),
) -> RubricFeedbackOut:
    text = gemini_service.generate_rubric_feedback(
        scores=body.scores,
        title=body.title,
        total_score=body.total_score,
        max_score=body.max_score,
    )
    return RubricFeedbackOut(text=text)


@router.post("/admin-daily-summary", response_model=AdminDailySummaryOut)
def admin_daily_summary(
    body: AdminDailySummaryIn,
    _: User = Depends(require_admin),
) -> AdminDailySummaryOut:
    summary = gemini_service.generate_admin_daily_summary(
        pending_requests=body.pending_requests,
        today_events=body.today_events,
        media_pending=body.media_pending,
        unread_notifications=body.unread_notifications,
        pending_members=body.pending_members,
    )
    return AdminDailySummaryOut(summary=summary)
