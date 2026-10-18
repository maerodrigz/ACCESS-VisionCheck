"""
Wipe operational data (media, requests, notifications, etc.) while keeping accounts.

Preserves:
  - All Admin-role users
  - Users whose email is not in the built-in demo seed list
  - Extra emails listed in KEEP_USER_EMAILS (comma-separated env)

Removes demo seed accounts (member@access.edu, org@access.edu, USTP demo students from create_tables).
"""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.config import settings
from app.crud import member_ranking as ranking_crud
from app.models.ai_detection_result import AiDetectionResult
from app.models.ai_review_history import AiReviewHistory
from app.models.analytics_report import AnalyticsReport
from app.models.announcement import Announcement
from app.models.archive import Archive
from app.models.assignment_member_feedback import AssignmentMemberFeedback
from app.models.audit_log import AuditLog
from app.models.documentation_request import DocumentationRequest
from app.models.enums import RoleName
from app.models.event_calendar import EventCalendar
from app.models.facebook_post import FacebookPost
from app.models.feedback import Feedback
from app.models.login_history import LoginHistory
from app.models.media_comment import MediaComment
from app.models.media_evaluation import MediaEvaluation
from app.models.media_file import MediaFile
from app.models.member_milestone import MemberMilestone
from app.models.member_ranking import MemberRanking
from app.models.notification import Notification
from app.models.push_device_token import PushDeviceToken
from app.models.request_assignment import RequestAssignment
from app.models.role import Role
from app.models.user import User
from app.models.user_session import UserSession

# Local calendar window for "yesterday or today" (Philippines).
_RESET_KEEP_TZ = ZoneInfo("Asia/Manila")


def demo_seed_emails() -> set[str]:
    """Emails created by create_tables.py for local demo (not real registrations)."""
    from create_tables import EXTRA_MEMBER_ACCOUNTS

    emails = {
        "member@access.edu",
        "org@access.edu",
    }
    emails.update(row[0].lower() for row in EXTRA_MEMBER_ACCOUNTS)
    return emails


def demo_sample_request_titles() -> set[str]:
    """Documentation requests inserted by create_tables / seed_sample_data."""
    return {
        "USTP Founders Day",
        "Acquaintance Party Coverage",
        "Engineering Week Opening",
        "Intramurals Opening Ceremony",
        "Leadership Summit 2026",
        "Sample Approved Event",
    }


def demo_sample_event_titles() -> set[str]:
    return {
        "USTP Founders Day",
        "Engineering Week Opening",
        "Leadership Summit 2026",
        "General Assembly",
        "Photo Editing Workshop",
    }


def recent_keep_local_dates() -> set[date]:
    now = datetime.now(_RESET_KEEP_TZ)
    today = now.date()
    return {today, today - timedelta(days=1)}


def _to_local_date(value: datetime | None) -> date | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(_RESET_KEEP_TZ).date()


def is_sample_documentation_request(req: DocumentationRequest) -> bool:
    if req.title.strip() in demo_sample_request_titles():
        return True
    desc = (req.description or "").strip()
    return desc.startswith("Sample documentation request:")


def should_keep_documentation_request(
    req: DocumentationRequest,
    *,
    requestor_email: str,
    demo_emails: set[str],
) -> bool:
    """Keep real requests submitted yesterday or today (Asia/Manila); drop demo seed rows."""
    if is_sample_documentation_request(req):
        return False
    if requestor_email.strip().lower() in demo_emails:
        return False
    created = _to_local_date(req.created_at)
    if created is None:
        return False
    return created in recent_keep_local_dates()


def extra_keep_emails_from_env() -> set[str]:
    raw = (os.environ.get("KEEP_USER_EMAILS") or "").strip()
    if not raw:
        return set()
    return {part.strip().lower() for part in raw.split(",") if part.strip()}


def user_registered_in_recent_window(user: User) -> bool:
    """True when the account was created yesterday or today (Asia/Manila)."""
    created = _to_local_date(user.created_at)
    if created is None:
        return False
    return created in recent_keep_local_dates()


def is_real_registration_email(email: str, demo: set[str]) -> bool:
    """Non-seed email (e.g. personal or campus mail), not create_tables demo identities."""
    return email.strip().lower() not in demo


def should_keep_user_on_reset(
    user: User,
    *,
    is_admin: bool,
    email: str,
    demo: set[str],
    keep_extra: set[str],
    remove_demo_users: bool,
) -> bool:
    """
    When trimming accounts: keep admins, KEEP_USER_EMAILS, real (non-demo) emails,
    and any account registered yesterday or today (Asia/Manila). Demo seed logins are removed otherwise.
    """
    if not remove_demo_users:
        return True
    if is_admin or email in keep_extra:
        return True
    if email in demo:
        return False
    if is_real_registration_email(email, demo):
        return True
    return user_registered_in_recent_window(user)


@dataclass
class ResetPlan:
    counts: dict[str, int] = field(default_factory=dict)
    users_to_delete: list[str] = field(default_factory=list)
    users_to_keep: list[str] = field(default_factory=list)
    requests_to_keep: list[str] = field(default_factory=list)
    requests_to_delete: list[str] = field(default_factory=list)
    upload_files_removed: int = 0


def _table_count(db: Session, model) -> int:
    return int(db.scalar(select(func.count()).select_from(model)) or 0)


def _user_email_by_id(db: Session) -> dict[int, str]:
    return {
        user.id: user.email.strip().lower()
        for user in db.scalars(select(User)).all()
    }


def compute_kept_request_ids(db: Session) -> set[int]:
    demo = demo_seed_emails()
    emails = _user_email_by_id(db)
    kept: set[int] = set()
    for req in db.scalars(select(DocumentationRequest).order_by(DocumentationRequest.id)).all():
        requestor_email = emails.get(req.requestor_id, "")
        if should_keep_documentation_request(req, requestor_email=requestor_email, demo_emails=demo):
            kept.add(req.id)
    return kept


def build_reset_plan(
    db: Session,
    *,
    remove_demo_users: bool = True,
    preserve_recent_requests: bool = True,
) -> ResetPlan:
    plan = ResetPlan()
    for label, model in [
        ("media_files", MediaFile),
        ("media_evaluations", MediaEvaluation),
        ("ai_detection_results", AiDetectionResult),
        ("documentation_requests", DocumentationRequest),
        ("notifications", Notification),
        ("users", User),
    ]:
        plan.counts[label] = _table_count(db, model)

    demo = demo_seed_emails()
    keep_extra = extra_keep_emails_from_env()
    admin_role = db.scalar(select(Role).where(Role.role_name == RoleName.ADMIN))
    emails = _user_email_by_id(db)
    kept_request_ids = compute_kept_request_ids(db) if preserve_recent_requests else set()

    for req in db.scalars(select(DocumentationRequest).order_by(DocumentationRequest.id)).all():
        line = f"#{req.id} {req.title} ({req.status})"
        if preserve_recent_requests and req.id in kept_request_ids:
            plan.requests_to_keep.append(line)
        elif preserve_recent_requests:
            plan.requests_to_delete.append(line)
        else:
            plan.requests_to_delete.append(line)

    for user in db.scalars(select(User).order_by(User.id)).all():
        email = user.email.strip().lower()
        role_name = user.role.role_name if user.role else ""
        is_admin = admin_role is not None and user.role_id == admin_role.id
        keep = should_keep_user_on_reset(
            user,
            is_admin=is_admin,
            email=email,
            demo=demo,
            keep_extra=keep_extra,
            remove_demo_users=remove_demo_users,
        )
        if keep:
            plan.users_to_keep.append(f"{email} ({role_name})")
        else:
            plan.users_to_delete.append(f"{email} ({role_name})")

    upload_root = Path(settings.upload_dir)
    if upload_root.is_dir():
        for sub in ("images", "videos"):
            folder = upload_root / sub
            if folder.is_dir():
                plan.upload_files_removed += sum(1 for p in folder.iterdir() if p.is_file())

    return plan


def _delete_all(db: Session, model) -> int:
    result = db.execute(delete(model))
    db.flush()
    return int(result.rowcount or 0)


def _delete_media_by_ids(db: Session, media_ids: set[int]) -> int:
    if not media_ids:
        return 0
    ids = list(media_ids)
    detection_ids = list(
        db.scalars(select(AiDetectionResult.id).where(AiDetectionResult.media_id.in_(ids)))
    )
    if detection_ids:
        db.execute(delete(AiReviewHistory).where(AiReviewHistory.ai_detection_id.in_(detection_ids)))
    db.execute(delete(AiDetectionResult).where(AiDetectionResult.media_id.in_(ids)))
    db.execute(delete(MediaEvaluation).where(MediaEvaluation.media_id.in_(ids)))
    db.execute(delete(MediaComment).where(MediaComment.media_id.in_(ids)))
    result = db.execute(delete(MediaFile).where(MediaFile.id.in_(ids)))
    db.flush()
    return int(result.rowcount or 0)


def _collect_removable_media_ids(
    db: Session,
    *,
    kept_request_ids: set[int],
    demo_user_ids: set[int],
) -> set[int]:
    remove: set[int] = set()
    for row in db.scalars(select(MediaFile)).all():
        if row.request_id is not None:
            if row.request_id not in kept_request_ids:
                remove.add(row.id)
            continue
        url = (row.file_url or "").lower()
        if "/samples/" in url:
            remove.add(row.id)
            continue
        if row.uploaded_by in demo_user_ids:
            remove.add(row.id)
    return remove


def _selective_clear_operational_data(db: Session, kept_request_ids: set[int]) -> dict[str, int]:
    """Remove demo/old rows; keep documentation requests in kept_request_ids."""
    deleted: dict[str, int] = {}
    demo = demo_seed_emails()
    demo_user_ids = {
        user.id
        for user in db.scalars(select(User)).all()
        if user.email.strip().lower() in demo
    }
    all_request_ids = set(db.scalars(select(DocumentationRequest.id)).all())
    delete_request_ids = all_request_ids - kept_request_ids

    media_ids = _collect_removable_media_ids(
        db, kept_request_ids=kept_request_ids, demo_user_ids=demo_user_ids
    )
    deleted["media_files"] = _delete_media_by_ids(db, media_ids)

    if delete_request_ids:
        req_list = list(delete_request_ids)
        deleted["assignment_member_feedback"] = int(
            (
                db.execute(
                    delete(AssignmentMemberFeedback).where(
                        AssignmentMemberFeedback.request_id.in_(req_list)
                    )
                ).rowcount
            )
            or 0
        )
        deleted["request_assignments"] = int(
            (
                db.execute(
                    delete(RequestAssignment).where(RequestAssignment.request_id.in_(req_list))
                ).rowcount
            )
            or 0
        )
        deleted["feedback"] = int(
            (db.execute(delete(Feedback).where(Feedback.request_id.in_(req_list))).rowcount or 0)
        )
        deleted["documentation_requests"] = int(
            (
                db.execute(
                    delete(DocumentationRequest).where(DocumentationRequest.id.in_(req_list))
                ).rowcount
            )
            or 0
        )
    else:
        deleted["assignment_member_feedback"] = 0
        deleted["request_assignments"] = 0
        deleted["feedback"] = 0
        deleted["documentation_requests"] = 0

    sample_events = demo_sample_event_titles()
    event_filters = [EventCalendar.title.in_(sample_events)]
    if delete_request_ids:
        event_filters.append(EventCalendar.request_id.in_(list(delete_request_ids)))
    deleted["event_calendar"] = int(
        (db.execute(delete(EventCalendar).where(or_(*event_filters))).rowcount or 0)
    )

    for label, model in [
        ("archives", Archive),
        ("facebook_posts", FacebookPost),
        ("notifications", Notification),
        ("member_milestones", MemberMilestone),
        ("analytics_reports", AnalyticsReport),
        ("announcements", Announcement),
        ("audit_logs", AuditLog),
        ("login_history", LoginHistory),
        ("user_sessions", UserSession),
        ("push_device_tokens", PushDeviceToken),
    ]:
        deleted[label] = _delete_all(db, model)

    db.flush()
    return deleted


def _clear_local_upload_files() -> int:
    removed = 0
    root = Path(settings.upload_dir)
    for sub in ("images", "videos"):
        folder = root / sub
        if not folder.is_dir():
            continue
        for path in folder.iterdir():
            if path.is_file():
                path.unlink(missing_ok=True)
                removed += 1
        folder.mkdir(parents=True, exist_ok=True)
    return removed


def reset_operational_data(
    db: Session,
    *,
    dry_run: bool = True,
    remove_demo_users: bool = True,
    clear_upload_dir: bool = True,
    preserve_recent_requests: bool = True,
) -> ResetPlan:
    """
    Clear transactional data. When dry_run=False, commits changes.
    """
    plan = build_reset_plan(
        db,
        remove_demo_users=remove_demo_users,
        preserve_recent_requests=preserve_recent_requests,
    )
    if dry_run:
        return plan

    if preserve_recent_requests:
        kept_request_ids = compute_kept_request_ids(db)
        deleted = _selective_clear_operational_data(db, kept_request_ids)
    else:
        deleted = {}
        for label, model in [
            ("ai_review_history", AiReviewHistory),
            ("ai_detection_results", AiDetectionResult),
            ("media_evaluations", MediaEvaluation),
            ("media_comments", MediaComment),
            ("archives", Archive),
            ("facebook_posts", FacebookPost),
            ("media_files", MediaFile),
            ("assignment_member_feedback", AssignmentMemberFeedback),
            ("request_assignments", RequestAssignment),
            ("feedback", Feedback),
            ("event_calendar", EventCalendar),
            ("documentation_requests", DocumentationRequest),
            ("notifications", Notification),
            ("member_milestones", MemberMilestone),
            ("analytics_reports", AnalyticsReport),
            ("announcements", Announcement),
            ("audit_logs", AuditLog),
            ("login_history", LoginHistory),
            ("user_sessions", UserSession),
            ("push_device_tokens", PushDeviceToken),
        ]:
            deleted[label] = _delete_all(db, model)

    plan.counts.update(deleted)

    if remove_demo_users:
        demo = demo_seed_emails()
        keep_extra = extra_keep_emails_from_env()
        admin_role = db.scalar(select(Role).where(Role.role_name == RoleName.ADMIN))
        to_remove = []
        for user in db.scalars(select(User)).all():
            email = user.email.strip().lower()
            is_admin = admin_role is not None and user.role_id == admin_role.id
            if should_keep_user_on_reset(
                user,
                is_admin=is_admin,
                email=email,
                demo=demo,
                keep_extra=keep_extra,
                remove_demo_users=True,
            ):
                continue
            to_remove.append(user)
        admin_count = db.scalar(
            select(func.count())
            .select_from(User)
            .where(User.role_id == admin_role.id)
        ) or 0
        if admin_count < 1:
            raise RuntimeError("Cannot remove users: no Admin account would remain.")
        for user in to_remove:
            db.delete(user)
        db.flush()

    for user in db.scalars(select(User)).all():
        if user.role and user.role.role_name == RoleName.MEMBER:
            row = ranking_crud.get_or_create(db, user.id)
            row.total_points = 0
            row.rank_position = None
            row.admin_remarks = None
            row.competency_level_override = None
    ranking_crud._recompute_ranks(db)

    if clear_upload_dir:
        plan.upload_files_removed = _clear_local_upload_files()

    db.commit()
    return plan


def build_non_admin_purge_plan(db: Session) -> ResetPlan:
    """List accounts that would be removed when keeping Admin (+ KEEP_USER_EMAILS) only."""
    plan = ResetPlan()
    plan.counts["users"] = _table_count(db, User)
    admin_role = db.scalar(select(Role).where(Role.role_name == RoleName.ADMIN))
    keep_extra = extra_keep_emails_from_env()
    for user in db.scalars(select(User).order_by(User.id)).all():
        email = user.email.strip().lower()
        role_name = user.role.role_name if user.role else ""
        is_admin = admin_role is not None and user.role_id == admin_role.id
        if is_admin or email in keep_extra:
            plan.users_to_keep.append(f"{email} ({role_name})")
        else:
            plan.users_to_delete.append(f"{email} ({role_name})")
    return plan


def purge_non_admin_users(db: Session, *, dry_run: bool = True) -> ResetPlan:
    """Delete every user except Admin role and KEEP_USER_EMAILS."""
    plan = build_non_admin_purge_plan(db)
    if dry_run:
        return plan

    admin_role = db.scalar(select(Role).where(Role.role_name == RoleName.ADMIN))
    if admin_role is None:
        raise RuntimeError("No Admin role in database.")
    keep_extra = extra_keep_emails_from_env()
    to_remove: list[User] = []
    for user in db.scalars(select(User)).all():
        email = user.email.strip().lower()
        is_admin = user.role_id == admin_role.id
        if is_admin or email in keep_extra:
            continue
        to_remove.append(user)

    admin_count = db.scalar(
        select(func.count()).select_from(User).where(User.role_id == admin_role.id)
    ) or 0
    if admin_count < 1:
        raise RuntimeError("Cannot purge: no Admin account would remain.")

    for user in to_remove:
        db.delete(user)
    db.flush()
    db.commit()
    plan.counts["users"] = _table_count(db, User)
    return plan
