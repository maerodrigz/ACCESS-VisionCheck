from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import evaluation as eval_crud
from app.crud import submission_chain as chain_crud
from app.database import get_db
from app.models.submission_chain import SubmissionChain
from app.models.user import User
from app.schemas.member_api import EvaluationOut
from app.services.member_score_release import evaluation_row_for_member
from app.services.submission_chain_read import chain_metadata_for_media, chains_by_ids
from app.services.supabase_storage import normalize_supabase_storage_url

router = APIRouter(prefix="/evaluations", tags=["Evaluations"])


def _evaluation_out_for_row(
    db: Session,
    ev,
    *,
    ai=None,
    chain=None,
) -> EvaluationOut:
    if ai is None:
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
    chain_meta = chain_metadata_for_media(db, ev.media, chain=chain)
    chain_row = chain
    if chain_row is None and chain_meta.get("submission_chain_id"):
        chain_row = db.get(SubmissionChain, int(chain_meta["submission_chain_id"]))
    can_reupload = chain_crud.member_can_reupload(
        db,
        member_id=ev.media.uploaded_by or 0,
        media=ev.media,
        chain=chain_row,
        ai_review_status=review_status,
    )
    replacement_verified = chain_crud.member_replacement_verified(db, chain_row, ev.media)
    member_feedback = feedback
    if (review_status or "").strip().lower() == "reupload_requested":
        remarks = ((ai.admin_remarks if ai else None) or "").strip()
        member_feedback = remarks if remarks else (
            "An administrator requested a new upload. Open the evaluation report to re-upload."
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
        feedback=member_feedback,
        evaluated_at=ev.evaluated_at,
        ai_probability=ai.ai_probability if ai else None,
        detection_result=ai.detection_result if ai else None,
        review_status=review_status,
        admin_remarks=ai.admin_remarks if ai else None,
        quality_level=quality_level,
        recommendation=recommendation,
        criteria_json=criteria_json,
        storage_removed=storage_removed,
        can_reupload=can_reupload,
        replacement_verified=replacement_verified,
        **chain_meta,
    )


@router.get("/chains/{root_media_id}")
def get_submission_chain_history(
    root_media_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    from app.services.submission_chain_timeline import member_chain_history

    chain = db.scalar(select(SubmissionChain).where(SubmissionChain.root_media_id == root_media_id))
    if chain is None:
        chain = chain_crud.get_chain_for_media(db, root_media_id)
    if chain is None or chain.member_id != current_user.id:
        raise HTTPException(status_code=404, detail="Submission chain not found")
    try:
        return member_chain_history(db, chain=chain, member_id=current_user.id)
    except PermissionError:
        raise HTTPException(status_code=404, detail="Submission chain not found") from None


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
    if not rows:
        return []
    media_ids = [ev.media_id for ev in rows]
    ai_map = eval_crud.ai_by_media_ids(db, media_ids)
    chain_ids = [
        ev.media.submission_chain_id
        for ev in rows
        if ev.media is not None and ev.media.submission_chain_id
    ]
    chain_map = chains_by_ids(db, chain_ids)
    return [
        _evaluation_out_for_row(
            db,
            ev,
            ai=ai_map.get(ev.media_id),
            chain=chain_map.get(ev.media.submission_chain_id)
            if ev.media is not None and ev.media.submission_chain_id
            else None,
        )
        for ev in rows
    ]
