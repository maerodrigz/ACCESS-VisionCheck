"""Member profile and participation records."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import require_approved
from app.crud import assignment_member_feedback as member_rating_crud
from app.crud import media as media_crud
from app.crud import member_milestone as milestone_crud
from app.crud import member_profile as profile_crud
from app.crud import member_ranking as ranking_crud
from app.crud import system_settings as settings_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.user import User
from app.schemas.member_api import (
    MemberMilestoneOut,
    MemberMilestonesOut,
    MemberReceivedRatingOut,
    MemberReceivedRatingsOut,
    ParticipationOut,
    ProfileOut,
    ProfileUpdate,
)
from app.core.security import verify_password
from app.services.media_upload_config import evaluation_rules
from app.services.security_policy import assert_password_meets_policy

router = APIRouter(prefix="/member", tags=["Member"])


def _profile_out(db: Session, user: User) -> ProfileOut:
    ranking = ranking_crud.get_or_create(db, user.id)
    skill = user.skill_level.level_name if user.skill_level else None
    return ProfileOut(
        id=user.id,
        name=user.fullname,
        email=user.email,
        role=user.role.role_name,
        status=user.status,
        student_id=user.student_id,
        contact_number=user.contact_number,
        adviser_name=user.adviser_name,
        profile_image=user.profile_image,
        skill_level=skill,
        total_points=ranking.total_points,
        rank_position=ranking.rank_position,
        uploads_count=profile_crud.uploads_count(db, user.id),
        assignments_completed=profile_crud.assignments_completed(db, user.id),
    )


@router.get("/profile", response_model=ProfileOut)
def get_profile(db: Session = Depends(get_db), current_user: User = Depends(require_approved)):
    user = user_crud.get_by_id(db, current_user.id)
    return _profile_out(db, user)  # type: ignore[arg-type]


def apply_profile_update(db: Session, current_user: User, body: ProfileUpdate) -> ProfileOut:
    """Update the logged-in user's profile (shared by /member/profile and /profile)."""
    user = user_crud.get_by_id(db, current_user.id)
    if body.email is not None:
        existing = user_crud.get_by_email(db, str(body.email))
        if existing and existing.id != user.id:
            raise HTTPException(status_code=409, detail="Email already in use")
    if body.new_password:
        if not body.current_password:
            raise HTTPException(status_code=400, detail="Current password is required")
        if not verify_password(body.current_password, user.password):
            raise HTTPException(status_code=401, detail="Current password is incorrect")
        assert_password_meets_policy(db, body.new_password)
    profile_crud.update_profile(
        db,
        user,  # type: ignore[arg-type]
        name=body.name,
        email=str(body.email) if body.email is not None else None,
        contact_number=body.contact_number,
        profile_image=body.profile_image,
        new_password=body.new_password,
    )
    user = user_crud.get_by_id(db, current_user.id)
    return _profile_out(db, user)  # type: ignore[arg-type]


@router.patch("/profile", response_model=ProfileOut)
def update_profile(
    body: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    return apply_profile_update(db, current_user, body)


@router.put("/profile", response_model=ProfileOut)
def put_profile(
    body: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    return apply_profile_update(db, current_user, body)


@router.get("/requester-ratings", response_model=MemberReceivedRatingsOut)
def list_received_requester_ratings(
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    """Ratings and comments requestors left for the logged-in member."""
    capped = min(max(limit, 1), 50)
    rows = member_rating_crud.list_for_member(db, current_user.id, limit=capped)
    summary = member_rating_crud.member_rating_summary(db, current_user.id)
    return MemberReceivedRatingsOut(
        count=int(summary["count"]),
        average_rating=summary["average_rating"],
        ratings=[
            MemberReceivedRatingOut(
                id=row.id,
                request_id=row.request_id,
                event_title=row.request.title if row.request else None,
                requestor_name=row.requestor.fullname if row.requestor else None,
                task_role=row.assignment.task_role if row.assignment else None,
                rating=row.rating,
                comment=row.comment,
                created_at=row.created_at,
            )
            for row in rows
        ],
    )


@router.get("/milestones", response_model=MemberMilestonesOut)
def list_member_milestones(
    unacknowledged_only: bool = False,
    limit: int = 30,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    rows = milestone_crud.list_for_user(
        db,
        current_user.id,
        unacknowledged_only=unacknowledged_only,
        limit=limit,
    )
    return MemberMilestonesOut(
        milestones=[
            MemberMilestoneOut(
                id=row.id,
                milestone_kind=row.milestone_kind,
                milestone_key=row.milestone_key,
                title=row.title,
                message=row.message,
                earned_at=row.created_at,
                acknowledged_at=row.acknowledged_at,
            )
            for row in rows
        ]
    )


@router.patch("/milestones/{milestone_id}/acknowledge", response_model=MemberMilestoneOut)
def acknowledge_member_milestone(
    milestone_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approved),
):
    row = milestone_crud.acknowledge(db, current_user.id, milestone_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Milestone not found")
    return MemberMilestoneOut(
        id=row.id,
        milestone_kind=row.milestone_kind,
        milestone_key=row.milestone_key,
        title=row.title,
        message=row.message,
        earned_at=row.created_at,
        acknowledged_at=row.acknowledged_at,
    )


@router.get("/participation", response_model=ParticipationOut)
def participation(db: Session = Depends(get_db), current_user: User = Depends(require_approved)):
    ranking = ranking_crud.get_or_create(db, current_user.id)
    eval_count, avg = profile_crud.evaluations_stats(db, current_user.id)
    eval_rules = evaluation_rules(db)
    return ParticipationOut(
        assignments_total=profile_crud.assignments_total(db, current_user.id),
        assignments_completed=profile_crud.assignments_completed(db, current_user.id),
        uploads_count=profile_crud.uploads_count(db, current_user.id),
        evaluations_count=eval_count,
        evaluations_today=media_crud.count_member_evaluations_today(db, current_user.id),
        daily_evaluation_limit=settings_crud.max_evaluation_uploads_per_day(db),
        evaluation_max_upload_mb=int(eval_rules["max_upload_mb"]),
        evaluation_max_video_seconds=int(eval_rules["max_video_seconds"]),
        average_score=round(avg, 3),
        total_points=ranking.total_points,
        rank_position=ranking.rank_position,
    )
