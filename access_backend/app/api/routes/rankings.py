from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_approved
from app.crud import rankings_admin
from app.crud import user as user_crud
from app.database import get_db
from app.models.user import User
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/rankings", tags=["Rankings & Skills"])


class RankingRemarksUpdate(BaseModel):
    admin_remarks: str | None = Field(None, max_length=2000)
    notify_member: bool = False


class CompetencyLevelUpdate(BaseModel):
    competency_level: str | None = Field(
        None,
        max_length=40,
        description="Beginner, Intermediate, or Advanced — omit or null to use system recommendation",
    )


@router.get("")
def get_rankings(db: Session = Depends(get_db), _: User = Depends(require_approved)):
    """Skill classification and member rankings."""
    try:
        return user_crud.rankings(db)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "Unable to load member rankings",
                "details": str(exc),
            },
        ) from exc


@router.get("/summary")
def get_rankings_summary(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    try:
        rows = rankings_admin.list_rankings(db)
        return rankings_admin.rankings_summary(rows)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "Unable to load rankings summary",
                "details": str(exc),
            },
        ) from exc


@router.patch("/{user_id}/remarks", response_model=MessageResponse)
def update_ranking_remarks(
    user_id: int,
    body: RankingRemarksUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    rankings_admin.update_admin_remarks(db, user_id, body.admin_remarks)
    if body.notify_member and body.admin_remarks and body.admin_remarks.strip():
        from app.services import notification_events as notify_events

        notify_events.notify_member_admin_feedback(
            db,
            user_id,
            remarks=body.admin_remarks.strip(),
        )
        return MessageResponse(message="Ranking remarks updated and sent to member")
    return MessageResponse(message="Ranking remarks updated")


@router.patch("/{user_id}/competency-level")
def update_competency_level(
    user_id: int,
    body: CompetencyLevelUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    try:
        return rankings_admin.update_competency_level(db, user_id, body.competency_level)
    except ValueError as exc:
        if "not found" in str(exc).lower():
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        raise HTTPException(status_code=400, detail=str(exc)) from exc
