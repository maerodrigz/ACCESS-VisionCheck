"""Admin-only endpoints for dashboard, requests, and media oversight."""

import json
import mimetypes
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings

from app.api.deps import require_admin
from app.core.security import decode_access_token
from app.models.enums import RoleName
from app.crud import analytics as analytics_crud
from app.crud import system_branding as branding_crud
from app.crud import archive as archive_crud
from app.crud import documentation_request as req_crud
from app.crud import evaluation as eval_crud
from app.crud import event_calendar as event_crud
from app.crud import feedback as feedback_crud
from app.crud import media as media_crud
from app.crud import roles as roles_crud
from app.crud import user as user_crud
from app.database import get_db
from app.models.user import User
from app.schemas.common import MessageResponse
from app.utils.timestamps import first_timestamp_iso

router = APIRouter(prefix="/admin", tags=["Admin"])
_optional_bearer = HTTPBearer(auto_error=False)


def _require_admin_token(
    db: Session,
    credentials: HTTPAuthorizationCredentials | None,
    access_token: str | None,
) -> User:
    token = credentials.credentials if credentials else (access_token or "").strip()
    if not token:
        raise HTTPException(status_code=401, detail="No token")
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = user_crud.get_by_id(db, int(payload["userId"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found")
    if user.role.role_name != RoleName.ADMIN:
        raise HTTPException(status_code=403, detail="Admin only")
    return user


def _load_error(label: str, exc: Exception) -> HTTPException:
    return HTTPException(
        status_code=500,
        detail={
            "success": False,
            "message": f"Unable to load {label}",
            "details": str(exc),
        },
    )


def _display_status(status: str) -> str:
    return status.strip().lower().capitalize()


def _request_to_json(row) -> dict:
    requestor = row.requestor
    return {
        "request_id": row.id,
        "requester_id": row.requestor_id,
        "requester_name": requestor.fullname if requestor else "Unknown",
        "type": "Documentation",
        "event_name": row.title,
        "title": row.title,
        "event_date": row.event_date.isoformat() if row.event_date else None,
        "venue": row.venue,
        "details": row.description,
        "status": _display_status(row.status),
        "rejection_reason": row.rejection_reason,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def _media_json(m) -> dict:
    ev = m.evaluations[-1] if m.evaluations else None
    ai = m.ai_detection_results[-1] if m.ai_detection_results else None
    uploader = m.uploader
    is_standalone = m.request_id is None
    event_title = m.request.title if m.request else None
    return {
        "id": m.id,
        "file_name": m.file_name,
        "file_type": m.file_type,
        "file_url": m.file_url,
        "request_id": m.request_id,
        "media_category": getattr(m, "media_category", "member_evaluation" if is_standalone else "event_documentation"),
        "approval_status": getattr(m, "approval_status", "not_applicable"),
        "approval_rejection_reason": getattr(m, "approval_rejection_reason", None),
        "facebook_publish_status": getattr(m, "facebook_publish_status", "not_published"),
        "facebook_post_id": getattr(m, "facebook_post_id", None),
        "facebook_published_at": m.facebook_published_at.isoformat()
        if getattr(m, "facebook_published_at", None)
        else None,
        "is_best_shot": bool(getattr(m, "is_best_shot", False)),
        "album_name_override": getattr(m, "album_name_override", None),
        "is_standalone": is_standalone,
        "source_label": "Practice evaluation" if is_standalone else (event_title or "Event coverage"),
        "event_title": event_title,
        "event_date": m.request.event_date.isoformat() if m.request and m.request.event_date else None,
        "event_description": m.request.description if m.request else None,
        "uploaded_by": m.uploaded_by,
        "uploader_name": uploader.fullname if uploader else "Unknown",
        "uploaded_at": m.uploaded_at.isoformat() if m.uploaded_at else None,
        "overall_score": ev.overall_score if ev else None,
        "ai_detected": ai.detection_result == "ai_generated" if ai else False,
        "ai_probability": ai.ai_probability if ai else None,
    }


@router.get("/stats")
def admin_stats(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return analytics_crud.dashboard_stats(db)


@router.get("/roles")
def list_roles(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Default roles (Admin, Member, Organization) from PostgreSQL `roles` table."""
    try:
        return roles_crud.list_roles_with_stats(db)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "Unable to load roles",
                "details": str(exc),
            },
        ) from exc


@router.get("/analytics/reports")
def list_analytics_reports(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Published dashboard snapshots stored in PostgreSQL."""
    return analytics_crud.list_analytics_reports(db)


@router.get("/service-requests")
def list_service_requests(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    rows = req_crud.list_all(db)
    return [_request_to_json(r) for r in rows]


class AssignMemberBody(BaseModel):
    member_id: int
    task_role: str = Field(default="photographer", max_length=50)
    admin_notes: str | None = Field(default=None, max_length=2000)


@router.post("/service-requests/{request_id}/assign")
def assign_member_to_request(
    request_id: int,
    body: AssignMemberBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Assign a member to an approved documentation request and notify them."""
    from app.crud import assignment as assignment_crud
    from app.crud import user as user_crud
    from app.models.enums import RoleName, UserStatus
    from app.services import notification_events as notify_events

    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    if row.status.strip().lower() != "approved":
        raise HTTPException(status_code=400, detail="Request must be approved before assigning a member")

    member = user_crud.get_by_id(db, body.member_id)
    if not member or not member.is_active:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.role.role_name != RoleName.MEMBER:
        raise HTTPException(status_code=400, detail="Selected user is not a member")
    if member.status != UserStatus.APPROVED:
        raise HTTPException(status_code=400, detail="Member account is not approved")

    assignment, event = assignment_crud.create_assignment(
        db,
        request=row,
        member_id=body.member_id,
        assigned_by=admin.id,
        task_role=body.task_role,
        admin_notes=body.admin_notes,
    )
    notify_events.notify_task_assigned(
        db,
        body.member_id,
        assignment.id,
        row.title,
        body.task_role.strip().lower(),
    )
    return {
        "message": "Member assigned successfully. Awaiting member acceptance.",
        "assignment_id": assignment.id,
        "event_id": event.id,
        "member_name": member.fullname,
        "task_role": assignment.task_role,
        "status": assignment.status,
    }


class AssignTeamBody(BaseModel):
    photographer_id: int | None = None
    videographer_id: int | None = None
    admin_notes: str | None = Field(default=None, max_length=2000)
    replaces_assignment_id: int | None = None


@router.get("/service-requests/{request_id}/recommended-members")
def recommended_members_for_request(
    request_id: int,
    task_role: str = "photographer",
    exclude_member_id: int | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    from app.models.request_assignment import RequestAssignment
    from app.services import assignment_recommendations as rec
    from sqlalchemy import select

    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    exclude: list[int] = []
    if exclude_member_id is not None:
        exclude.append(exclude_member_id)
    declined_ids = list(
        db.scalars(
            select(RequestAssignment.member_id).where(
                RequestAssignment.request_id == request_id,
                RequestAssignment.status == "declined",
            )
        ).all()
    )
    exclude.extend(declined_ids)
    return rec.recommend_members_for_request(
        db,
        row,
        task_role=task_role,
        exclude_member_ids=exclude,
    )


@router.get("/service-requests/{request_id}/assignments")
def list_request_assignments(
    request_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    from app.crud import assignment as assignment_crud

    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    rows = assignment_crud.list_for_request(db, request_id)
    return [assignment_crud.assignment_to_json(r) for r in rows]


@router.post("/service-requests/{request_id}/assign-team")
def assign_documentation_team(
    request_id: int,
    body: AssignTeamBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Assign photographer and/or videographer — admin confirms; members must accept."""
    from app.crud import assignment as assignment_crud
    from app.crud import user as user_crud
    from app.models.enums import RoleName, UserStatus
    from app.models.request_assignment import RequestAssignment
    from app.services import notification_events as notify_events
    from sqlalchemy import select

    row = req_crud.get(db, request_id)
    if not row:
        raise HTTPException(status_code=404, detail="Request not found")
    if row.status.strip().lower() != "approved":
        raise HTTPException(status_code=400, detail="Request must be approved before assigning a team")

    if body.photographer_id is None and body.videographer_id is None:
        raise HTTPException(status_code=400, detail="Select at least one member to assign.")

    if body.photographer_id is not None and body.videographer_id == body.photographer_id:
        raise HTTPException(status_code=400, detail="Photographer and videographer must be different members.")

    created: list[dict] = []

    def _assign(member_id: int, role: str) -> None:
        member = user_crud.get_by_id(db, member_id)
        if not member or not member.is_active:
            raise HTTPException(status_code=404, detail=f"Member {member_id} not found")
        if member.role.role_name != RoleName.MEMBER:
            raise HTTPException(status_code=400, detail="Selected user is not a member")
        if member.status != UserStatus.APPROVED:
            raise HTTPException(status_code=400, detail="Member account is not approved")
        try:
            assignment, event = assignment_crud.create_assignment(
                db,
                request=row,
                member_id=member_id,
                assigned_by=admin.id,
                task_role=role,
                admin_notes=body.admin_notes,
                replaces_assignment_id=body.replaces_assignment_id,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        notify_events.notify_task_assigned(
            db,
            member_id,
            assignment.id,
            row.title,
            role,
        )
        created.append(
            {
                "assignment_id": assignment.id,
                "member_id": member_id,
                "member_name": member.fullname,
                "task_role": role,
                "status": assignment.status,
            }
        )

    if body.photographer_id is not None:
        _assign(body.photographer_id, "photographer")
    if body.videographer_id is not None:
        _assign(body.videographer_id, "videographer")

    return {
        "message": "Documentation team assigned. Members will be notified to accept or decline.",
        "assignments": created,
    }


@router.get("/media")
def list_all_media(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """All uploaded media for admin repository / upload review."""
    rows = media_crud.list_media(db)
    return [_media_json(m) for m in rows]


class EvaluationRemarksUpdate(BaseModel):
    admin_remarks: str | None = Field(None, max_length=2000)


def _evaluation_json(db: Session, ev) -> dict:
    media = ev.media
    uploader = media.uploader if media else None
    ai = eval_crud.get_ai_for_media(db, ev.media_id)
    name = media.file_name if media else ""
    member = uploader.fullname if uploader else "Unknown"
    is_standalone = media is None or media.request_id is None
    event_title = None
    if media and media.request_id and media.request:
        event_title = media.request.title
    source_label = "Practice evaluation" if is_standalone else (event_title or "Event coverage")
    return {
        "id": ev.id,
        "media_id": ev.media_id,
        "media_name": name,
        "file_name": name,
        "file_url": media.file_url if media else "",
        "member_name": member,
        "uploader_name": member,
        "is_standalone": is_standalone,
        "source_type": "practice" if is_standalone else "event",
        "source_label": source_label,
        "event_title": event_title,
        "request_id": media.request_id if media else None,
        "sharpness_score": ev.sharpness_score,
        "brightness_score": ev.brightness_score,
        "contrast_score": ev.contrast_score,
        "blur_score": ev.blur_score,
        "noise_score": ev.noise_score,
        "overall_score": ev.overall_score,
        "admin_remarks": ev.feedback,
        "feedback": ev.feedback,
        "quality_level": ev.quality_level,
        "recommendation": ev.recommendation,
        "criteria_json": ev.criteria_json,
        "created_at": first_timestamp_iso(ev, "evaluated_at"),
        "evaluated_at": first_timestamp_iso(ev, "evaluated_at"),
        "updated_at": first_timestamp_iso(ev, "evaluated_at"),
        "ai_probability": ai.ai_probability if ai else None,
        "ai_result": ai.detection_result if ai else None,
        "detection_result": ai.detection_result if ai else None,
    }


@router.get("/evaluations/summary")
def evaluations_summary(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return eval_crud.summary_stats(db)


@router.get("/evaluations")
def list_all_evaluations(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    try:
        rows = eval_crud.list_all(db)
        return [_evaluation_json(db, ev) for ev in rows]
    except Exception as exc:
        raise _load_error("media evaluations", exc) from exc


@router.patch("/evaluations/{evaluation_id}")
def update_evaluation_remarks(
    evaluation_id: int,
    body: EvaluationRemarksUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    ev = eval_crud.get_by_id(db, evaluation_id)
    if not ev:
        raise HTTPException(status_code=404, detail="Evaluation not found")
    eval_crud.update_feedback(db, ev, body.admin_remarks)
    return _evaluation_json(db, ev)


@router.post("/evaluations/{evaluation_id}/archive", response_model=MessageResponse)
def archive_evaluated_media(
    evaluation_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    ev = eval_crud.get_by_id(db, evaluation_id)
    if not ev:
        raise HTTPException(status_code=404, detail="Evaluation not found")
    archive_crud.create_if_not_exists(db, ev.media_id, admin.id)
    return MessageResponse(message="Media archived successfully")


@router.post("/media/{media_id}/archive", response_model=MessageResponse)
def archive_media_file(
    media_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    media = media_crud.get(db, media_id)
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")
    archive_crud.create_if_not_exists(db, media_id, admin.id)
    return MessageResponse(message="Media archived successfully")


@router.delete("/media/{media_id}", response_model=MessageResponse)
def delete_media(
    media_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    media = media_crud.get(db, media_id)
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")
    try:
        media_crud.delete_media(db, media)
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return MessageResponse(message="Media deleted successfully")


def _admin_media_content_type(file_name: str, file_type: str | None) -> str:
    ft = (file_type or "").strip().lower()
    if ft.startswith("video") or "video" in ft:
        return "video/mp4"
    if ft.startswith("image") or ft in ("photo", "picture"):
        guessed, _ = mimetypes.guess_type(file_name or "")
        return guessed or "image/jpeg"
    guessed, _ = mimetypes.guess_type(file_name or "")
    return guessed or "application/octet-stream"


@router.get("/media/{media_id}/stream")
def stream_admin_media(
    media_id: int,
    access_token: str | None = Query(None, alias="access_token"),
    credentials: HTTPAuthorizationCredentials | None = Depends(_optional_bearer),
    db: Session = Depends(get_db),
):
    """Authenticated media stream for admin previews (img/video tags cannot send JWT headers)."""
    _require_admin_token(db, credentials, access_token)
    from app.services.media_file_bytes import local_media_path, read_media_file_bytes

    media = media_crud.get(db, media_id)
    if not media or not media.file_url:
        raise HTTPException(status_code=404, detail="Media not found")

    content_type = _admin_media_content_type(media.file_name, media.file_type)
    local = local_media_path(media.file_url)
    if local is not None:
        return FileResponse(
            local,
            media_type=content_type,
            filename=media.file_name or local.name,
            headers={"Cache-Control": "private, max-age=120"},
        )

    content = read_media_file_bytes(media.file_url, timeout=120.0)
    if not content:
        raise HTTPException(status_code=404, detail="Media file unavailable")

    return Response(
        content=content,
        media_type=content_type,
        headers={"Cache-Control": "private, max-age=120"},
    )


class AiDetectionReviewUpdate(BaseModel):
    review_status: str | None = Field(None, max_length=40)
    admin_remarks: str | None = Field(None, max_length=2000)


def _confidence_level(score: float) -> str:
    pct = score * 100
    if pct >= 80:
        return "high"
    if pct >= 50:
        return "medium"
    return "low"


def _parse_stored_exif(raw: str | None) -> dict | None:
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return None
    return parsed if isinstance(parsed, dict) else None


def _resolve_exif_metadata(ai) -> dict | None:
    stored = _parse_stored_exif(getattr(ai, "exif_metadata", None))
    if stored:
        return stored

    media = ai.media
    if not media or not media.file_url:
        return None

    from app.services.ai_authenticity_detector import extract_exif_metadata
    from app.services.media_file_bytes import read_media_file_bytes

    content = read_media_file_bytes(media.file_url)
    if not content:
        return None
    return extract_exif_metadata(content, media.file_name or "")


def _ai_detection_json(ai) -> dict:
    media = ai.media
    uploader = media.uploader if media else None
    name = media.file_name if media else ""
    url = media.file_url if media else ""
    file_type = media.file_type if media else None
    result = ai.detection_result or ""
    is_ai = "ai" in result.lower() or "generated" in result.lower()
    confidence = ai.ai_probability if is_ai else (1.0 - ai.ai_probability)
    review_status = (getattr(ai, "review_status", None) or "").strip()
    if not review_status:
        if ai.reviewed_by_admin:
            review_status = "verified_human" if not is_ai else "verified_ai_generated"
        else:
            review_status = "pending_review"
    return {
        "id": ai.id,
        "media_id": ai.media_id,
        "media_name": name,
        "file_name": name,
        "file_type": file_type,
        "media_url": url,
        "file_url": url,
        "thumbnail_url": url,
        "member_name": uploader.fullname if uploader else "Unknown",
        "uploader_name": uploader.fullname if uploader else "Unknown",
        "ai_result": result,
        "detection_result": result,
        "ai_probability": ai.ai_probability,
        "confidence_score": round(confidence, 3),
        "confidence_level": _confidence_level(confidence),
        "review_status": review_status,
        "reviewed_by_admin": ai.reviewed_by_admin,
        "admin_remarks": getattr(ai, "admin_remarks", None),
        "detection_remarks": getattr(ai, "detection_remarks", None),
        "exif_metadata": _resolve_exif_metadata(ai),
        "member_id": uploader.id if uploader else None,
        "reviewed_by": getattr(ai, "reviewed_by", None),
        "reviewed_at": ai.reviewed_at.isoformat() if getattr(ai, "reviewed_at", None) else None,
        "created_at": first_timestamp_iso(ai, "created_at"),
        "updated_at": first_timestamp_iso(ai, "updated_at", "reviewed_at", "created_at"),
        "scanned_at": first_timestamp_iso(ai, "created_at"),
    }


@router.get("/ai-detection/summary")
def ai_detection_summary(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return eval_crud.ai_detection_summary(db)


@router.get("/ai-detection")
def list_ai_detection(
    inbox: str | None = Query(
        None,
        description="needs_action (default review queue), resolved, or all",
    ),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    try:
        bucket = (inbox or "all").strip().lower()
        if bucket not in ("all", "needs_action", "resolved"):
            bucket = "all"
        rows = eval_crud.list_ai_for_integrity_inbox(db, inbox=bucket)
        return [_ai_detection_json(ai) for ai in rows]
    except Exception as exc:
        raise _load_error("AI detection results", exc) from exc


@router.patch("/ai-detection/{ai_id}")
def update_ai_detection_review(
    ai_id: int,
    body: AiDetectionReviewUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    row = eval_crud.get_ai_by_id(db, ai_id)
    if not row:
        raise HTTPException(status_code=404, detail="AI detection record not found")
    updated = eval_crud.update_ai_review(
        db,
        row,
        review_status=body.review_status,
        admin_remarks=body.admin_remarks,
        reviewed_by=admin.id,
    )
    db.refresh(updated)
    return _ai_detection_json(updated)


@router.get("/ai-detection/{ai_id}/history")
def ai_detection_review_history(
    ai_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    from app.services.ai_review_workflow import history_to_json, list_review_history

    row = eval_crud.get_ai_by_id(db, ai_id)
    if not row:
        raise HTTPException(status_code=404, detail="AI detection record not found")
    history = list_review_history(db, ai_id)
    out = []
    for h in history:
        reviewer_name = h.reviewer.fullname if h.reviewer else None
        out.append(history_to_json(h, reviewer_name))
    return out


@router.post("/ai-detection/{ai_id}/archive", response_model=MessageResponse)
def archive_ai_detection_media(
    ai_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    row = eval_crud.get_ai_by_id(db, ai_id)
    if not row:
        raise HTTPException(status_code=404, detail="AI detection record not found")
    archive_crud.create_if_not_exists(db, row.media_id, admin.id)
    return MessageResponse(message="Media archived successfully")


@router.get("/tasks")
def list_all_tasks(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    from sqlalchemy import select
    from sqlalchemy.orm import joinedload

    from app.models.request_assignment import RequestAssignment

    rows = list(
        db.scalars(
            select(RequestAssignment)
            .options(
                joinedload(RequestAssignment.request),
                joinedload(RequestAssignment.member),
            )
            .order_by(RequestAssignment.id.desc())
        )
    )
    return [
        {
            "id": r.id,
            "request_id": r.request_id,
            "request_title": r.request.title if r.request else "",
            "member_id": r.member_id,
            "member_name": r.member.fullname if r.member else "Unknown",
            "task_role": r.task_role,
            "status": r.status,
            "event_date": r.request.event_date.isoformat() if r.request and r.request.event_date else None,
        }
        for r in rows
    ]


@router.get("/events")
def list_all_events(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    try:
        rows = event_crud.list_events(db)
        return [event_crud.event_to_json(e) for e in rows]
    except Exception as exc:
        raise _load_error("calendar events", exc) from exc


class EventCreateBody(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=5000)
    event_date: str
    end_date: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    location: str | None = Field(None, max_length=200)
    status: str = Field("upcoming", max_length=40)
    assigned_member_id: int | None = None
    documentation_request_id: int | None = None
    admin_remarks: str | None = Field(None, max_length=2000)


class EventUpdateBody(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = Field(None, max_length=5000)
    event_date: str | None = None
    end_date: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    location: str | None = Field(None, max_length=200)
    status: str | None = Field(None, max_length=40)
    assigned_member_id: int | None = None
    documentation_request_id: int | None = None
    admin_remarks: str | None = Field(None, max_length=2000)


@router.post("/events")
def create_event(
    body: EventCreateBody,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    start = event_crud.parse_date(body.event_date)
    if not start:
        raise HTTPException(status_code=400, detail="Invalid event_date")
    start_t = event_crud.parse_time(body.start_time)
    end_t = event_crud.parse_time(body.end_time)
    if start_t and end_t and start_t >= end_t:
        raise HTTPException(status_code=400, detail="start_time must be before end_time")
    row = event_crud.create_event(
        db,
        {
            "title": body.title.strip(),
            "description": body.description,
            "start_date": start,
            "end_date": event_crud.parse_date(body.end_date) if body.end_date else None,
            "start_time": start_t,
            "end_time": end_t,
            "venue": body.location,
            "status": body.status,
            "assigned_member_id": body.assigned_member_id,
            "request_id": body.documentation_request_id,
            "admin_remarks": body.admin_remarks,
        },
    )
    if body.assigned_member_id:
        from app.services import notification_events as notify_events

        notify_events.notify_event_member_assigned(
            db,
            event_id=row.id,
            event_title=row.title,
            member_id=body.assigned_member_id,
            event_date=body.event_date,
        )
    return event_crud.event_to_json(row)


@router.patch("/events/{event_id}")
def update_event(
    event_id: int,
    body: EventUpdateBody,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    row = event_crud.get_event(db, event_id)
    if not row:
        raise HTTPException(status_code=404, detail="Event not found")
    previous_member_id = row.assigned_member_id
    data: dict = {}
    if body.title is not None:
        data["title"] = body.title.strip()
    if body.description is not None:
        data["description"] = body.description
    if body.event_date is not None:
        parsed = event_crud.parse_date(body.event_date)
        if not parsed:
            raise HTTPException(status_code=400, detail="Invalid event_date")
        data["start_date"] = parsed
    if body.end_date is not None:
        data["end_date"] = event_crud.parse_date(body.end_date)
    if body.start_time is not None:
        data["start_time"] = event_crud.parse_time(body.start_time)
    if body.end_time is not None:
        data["end_time"] = event_crud.parse_time(body.end_time)
    if body.location is not None:
        data["venue"] = body.location
    if body.status is not None:
        data["status"] = body.status
    if body.assigned_member_id is not None:
        data["assigned_member_id"] = body.assigned_member_id
    if body.documentation_request_id is not None:
        data["request_id"] = body.documentation_request_id
    if body.admin_remarks is not None:
        data["admin_remarks"] = body.admin_remarks
    start_t = data.get("start_time", row.start_time)
    end_t = data.get("end_time", row.end_time)
    if start_t and end_t and start_t >= end_t:
        raise HTTPException(status_code=400, detail="start_time must be before end_time")
    updated = event_crud.update_event(db, row, data)
    new_member_id = updated.assigned_member_id
    if new_member_id and new_member_id != previous_member_id:
        from app.services import notification_events as notify_events

        notify_events.notify_event_member_assigned(
            db,
            event_id=updated.id,
            event_title=updated.title,
            member_id=new_member_id,
            event_date=updated.start_date.isoformat() if updated.start_date else None,
        )
    return event_crud.event_to_json(updated)


@router.delete("/events/{event_id}", response_model=MessageResponse)
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    row = event_crud.get_event(db, event_id)
    if not row:
        raise HTTPException(status_code=404, detail="Event not found")
    event_crud.delete_event(db, row)
    return MessageResponse(message="Event deleted successfully")


@router.get("/feedback")
def list_all_feedback(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    rows = feedback_crud.list_feedbacks(db)
    return [
        {
            "id": f.id,
            "request_id": f.request_id,
            "event_title": f.request.title if f.request else None,
            "event_name": f.request.title if f.request else None,
            "user_id": f.user_id,
            "member_name": f.user.fullname if f.user else "Unknown",
            "user_name": f.user.fullname if f.user else "Unknown",
            "rating": f.rating,
            "comment": f.comment,
            "admin_response": f.admin_response,
            "review_status": f.review_status,
            "created_at": f.created_at.isoformat() if f.created_at else None,
        }
        for f in rows
    ]


class FeedbackAdminUpdateBody(BaseModel):
    admin_response: str | None = Field(None, max_length=5000)
    review_status: str | None = Field(None, pattern="^(pending|reviewed|archived)$")


@router.patch("/feedback/{feedback_id}")
def update_feedback_admin_review(
    feedback_id: int,
    body: FeedbackAdminUpdateBody,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    row = feedback_crud.get(db, feedback_id)
    if not row:
        raise HTTPException(status_code=404, detail="Feedback not found")
    if body.admin_response is None and body.review_status is None:
        raise HTTPException(status_code=400, detail="No fields to update")
    updated = feedback_crud.update_admin_review(
        db,
        row,
        admin_response=body.admin_response,
        review_status=body.review_status,
    )
    return {
        "id": updated.id,
        "request_id": updated.request_id,
        "admin_response": updated.admin_response,
        "review_status": updated.review_status,
    }


@router.get("/member-ratings")
def admin_list_member_ratings(
    member_id: int | None = None,
    request_id: int | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    from sqlalchemy.orm import joinedload

    from app.crud import assignment_member_feedback as member_rating_crud
    from app.models.assignment_member_feedback import AssignmentMemberFeedback

    if member_id is not None:
        rows = member_rating_crud.list_for_member(db, member_id, limit=50)
    else:
        from sqlalchemy import select

        q = select(AssignmentMemberFeedback).options(
            joinedload(AssignmentMemberFeedback.member),
            joinedload(AssignmentMemberFeedback.requestor),
            joinedload(AssignmentMemberFeedback.request),
            joinedload(AssignmentMemberFeedback.assignment),
        )
        if request_id is not None:
            q = q.where(AssignmentMemberFeedback.request_id == request_id)
        q = q.order_by(AssignmentMemberFeedback.created_at.desc()).limit(200)
        rows = list(db.scalars(q))

    return [
        {
            "id": r.id,
            "request_id": r.request_id,
            "assignment_id": r.assignment_id,
            "member_id": r.member_id,
            "member_name": r.member.fullname if r.member else None,
            "task_role": r.assignment.task_role if r.assignment else None,
            "requestor_id": r.requestor_id,
            "requestor_name": r.requestor.fullname if r.requestor else None,
            "event_title": r.request.title if r.request else None,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


@router.get("/member-ratings/summary")
def admin_member_rating_summaries(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    from app.crud import assignment_member_feedback as member_rating_crud
    from app.models.user import User

    members = db.scalars(
        select(User).join(User.role).where(User.role.has(role_name=RoleName.MEMBER))
    )
    member_ids = [m.id for m in members]
    summaries = member_rating_crud.summaries_for_members(db, member_ids)
    return summaries


LOGO_ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp"}


def _branding_upload_dir() -> Path:
    path = Path(settings.upload_dir) / "branding"
    path.mkdir(parents=True, exist_ok=True)
    return path


@router.get("/branding")
def admin_get_branding(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    from app.models.system_branding import SystemBranding

    payload = branding_crud.branding_payload(db)
    updated_by = None
    try:
        row = db.get(SystemBranding, branding_crud.BRANDING_ROW_ID)
        if row and row.updater:
            updated_by = row.updater.fullname
    except Exception:
        db.rollback()
    return {**payload, "updated_by": updated_by}


@router.post("/branding/logo")
async def admin_upload_logo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    ext = Path(file.filename or "").suffix.lower()
    if ext not in LOGO_ALLOWED_EXT:
        raise HTTPException(
            status_code=400,
            detail="Logo must be JPG, JPEG, PNG, or WEBP.",
        )

    content = await file.read()
    max_bytes = 5 * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(status_code=400, detail="Logo must be 5 MB or smaller.")

    dest_dir = _branding_upload_dir()
    for old in dest_dir.glob("access_logo.*"):
        try:
            old.unlink()
        except OSError:
            pass

    filename = f"access_logo{ext if ext != '.jpeg' else '.jpg'}"
    dest = dest_dir / filename
    dest.write_bytes(content)

    logo_path = f"/uploads/branding/{filename}"
    branding_crud.set_logo(db, logo_path, admin.id)
    payload = branding_crud.branding_payload(db)
    return {"message": "Logo updated successfully.", **payload, "updated_by": admin.fullname}


class BrandingNamesBody(BaseModel):
    app_name: str | None = Field(None, max_length=120)
    tagline: str | None = Field(None, max_length=255)
    short_tagline: str | None = Field(None, max_length=255)
    organization: str | None = Field(None, max_length=120)


@router.patch("/branding/names")
def admin_update_branding_names(
    body: BrandingNamesBody,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    branding_crud.update_names(
        db,
        user_id=admin.id,
        app_name=body.app_name,
        tagline=body.tagline,
        short_tagline=body.short_tagline,
        organization=body.organization,
    )
    payload = branding_crud.branding_payload(db)
    return {
        "message": "System names updated.",
        **payload,
        "updated_by": admin.fullname,
    }


@router.delete("/branding/names")
def admin_reset_branding_names(db: Session = Depends(get_db), admin: User = Depends(require_admin)):
    branding_crud.reset_names(db, admin.id)
    payload = branding_crud.branding_payload(db)
    return {
        "message": "System names reset to defaults.",
        **payload,
        "updated_by": admin.fullname,
    }


@router.delete("/branding/logo")
def admin_reset_logo(db: Session = Depends(get_db), admin: User = Depends(require_admin)):
    dest_dir = _branding_upload_dir()
    for old in dest_dir.glob("access_logo.*"):
        try:
            old.unlink()
        except OSError:
            pass
    branding_crud.clear_logo(db, admin.id)
    payload = branding_crud.branding_payload(db)
    return {"message": "Logo reset to default bundled asset.", **payload, "updated_by": admin.fullname}
