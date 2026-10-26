from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import evaluation as eval_crud
from app.database import get_db
from app.models.user import User
from app.schemas.member_api import EvaluationOut
from app.services.member_score_release import evaluation_row_for_member
from app.services.supabase_storage import normalize_supabase_storage_url

router = APIRouter(prefix="/evaluations", tags=["Evaluations"])


def _evaluation_out_for_row(db: Session, ev) -> EvaluationOut:
    ai = eval_crud.get_ai_for_media(db, ev.media_id)
    review_status = ai.review_status if ai else None
    (
        criteria_json,
        overall_score,
        feedback,
        sharpness_score,
        brightness_score,
        contrast_score,
        blur_score,
        noise_score,
        quality_level,
        recommendation,
    ) = evaluation_row_for_member(
        criteria_json=ev.criteria_json,
        review_status=review_status,
        overall_score=ev.overall_score,
        feedback=ev.feedback,
        sharpness_score=ev.sharpness_score,
        brightness_score=ev.brightness_score,
        contrast_score=ev.contrast_score,
        blur_score=ev.blur_score,
        noise_score=ev.noise_score,
        quality_level=ev.quality_level,
        recommendation=ev.recommendation,
    )
    storage_removed = ev.media.storage_removed_at is not None
    file_url = (
        ""
        if storage_removed
        else normalize_supabase_storage_url(ev.media.file_url or "")
    )
    return EvaluationOut(
        id=ev.id,
        media_id=ev.media_id,
        file_name=ev.media.file_name,
        file_url=file_url,
        sharpness_score=sharpness_score,
        brightness_score=brightness_score,
        contrast_score=contrast_score,
        blur_score=blur_score,
        noise_score=noise_score,
        overall_score=overall_score,
        feedback=feedback,
        evaluated_at=ev.evaluated_at,
        ai_probability=ai.ai_probability if ai else None,
        detection_result=ai.detection_result if ai else None,
        review_status=review_status,
        admin_remarks=ai.admin_remarks if ai else None,
        quality_level=quality_level,
        recommendation=recommendation,
        criteria_json=criteria_json,
        storage_removed=storage_removed,
    )


@router.get("", response_model=list[EvaluationOut])
def list_evaluations(
    mine: bool = True,
    media_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    if media_id is not None:
        if not mine:
            raise HTTPException(status_code=400, detail="media_id filter requires mine=true")
        ev = eval_crud.get_for_media(db, media_id)
        if ev is None or ev.media.uploaded_by != current_user.id:
            return []
        return [_evaluation_out_for_row(db, ev)]

    rows = eval_crud.list_for_user(db, current_user.id) if mine else []
    result = []
    for ev in rows:
        result.append(_evaluation_out_for_row(db, ev))
    return result
