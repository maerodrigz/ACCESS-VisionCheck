"""
Create all PostgreSQL tables for ACCESS VisionCheck.

Usage:
  1. Copy .env.example to .env and set DB_PASSWORD
  2. pip install -r requirements.txt
  3. python create_tables.py

Optional — drop and recreate (development only):
  set RECREATE_DB=true
  python create_tables.py
"""

import os

from dotenv import load_dotenv
from sqlalchemy import text

load_dotenv()

from app.config import settings
from app.core.security import hash_password
from app.database import Base, SessionLocal, engine
from app.models import (  # noqa: F401 — register every model with Base.metadata
    AiDetectionResult,
    AnalyticsReport,
    Announcement,
    Archive,
    AuditLog,
    DocumentationRequest,
    EventCalendar,
    FacebookPost,
    FacebookSetting,
    AssignmentMemberFeedback,
    Feedback,
    LoginHistory,
    MediaComment,
    MediaEvaluation,
    MediaFile,
    MemberRanking,
    Notification,
    MemberNotificationPreference,
    RequestAssignment,
    Role,
    SkillLevel,
    User,
    UserSession,
    SystemBranding,
    SystemSettings,
    PushDeviceToken,
)


def seed_roles(db) -> dict[str, int]:
    """Default roles for Admin Web and Mobile apps."""
    defaults = ["Admin", "Member", "Organization"]
    ids: dict[str, int] = {}
    for name in defaults:
        row = db.query(Role).filter(Role.role_name == name).first()
        if not row:
            row = Role(role_name=name)
            db.add(row)
            db.flush()
        ids[name] = row.id
    db.commit()
    return ids


def seed_skill_levels(db) -> dict[str, int]:
    """Skill tiers mapped to evaluation overall_score (0.0–1.0)."""
    levels = [
        ("Novice", 0.0, 0.29),
        ("Beginner", 0.30, 0.49),
        ("Intermediate", 0.50, 0.69),
        ("Advanced", 0.70, 0.84),
        ("Expert", 0.85, 0.94),
        ("Master", 0.95, 1.0),
    ]
    ids: dict[str, int] = {}
    for name, lo, hi in levels:
        row = db.query(SkillLevel).filter(SkillLevel.level_name == name).first()
        if not row:
            row = SkillLevel(level_name=name, min_score=lo, max_score=hi)
            db.add(row)
            db.flush()
        ids[name] = row.id
    db.commit()
    return ids


def _seed_user(
    db,
    *,
    email: str,
    fullname: str,
    password: str,
    role_id: int,
    skill_level_id: int | None,
    status: str,
) -> bool:
    """Insert user if email not taken. Returns True if created."""
    if db.query(User).filter(User.email == email).first():
        return False
    db.add(
        User(
            fullname=fullname,
            email=email,
            password=hash_password(password),
            role_id=role_id,
            skill_level_id=skill_level_id,
            status=status,
        )
    )
    db.commit()
    return True


def seed_default_users(db, role_ids: dict[str, int], skill_ids: dict[str, int]) -> None:
    """Default accounts for testing Admin Web + Mobile apps."""
    accounts = [
        ("admin@access.edu", "Admin User", "admin123", "Admin", skill_ids["Master"], "approved"),
        ("member@access.edu", "Juan Dela Cruz", "member123", "Member", skill_ids["Beginner"], "approved"),
        ("org@access.edu", "USTP Engineering Society", "org123", "Organization", None, "approved"),
    ]
    for email, name, pw, role_key, skill_id, status in accounts:
        if _seed_user(
            db,
            email=email,
            fullname=name,
            password=pw,
            role_id=role_ids[role_key],
            skill_level_id=skill_id,
            status=status,
        ):
            print(f"  -> {role_key}: {email} / {pw}")

    seed_extra_members(db, role_ids, skill_ids)


# email, fullname, password, skill_key, status
EXTRA_MEMBER_ACCOUNTS: list[tuple[str, str, str, str, str]] = [
    ("ana.reyes@student.ustp.edu.ph", "Ana Reyes", "member123", "Novice", "pending"),
    ("carlos.m@student.ustp.edu.ph", "Carlos Mendoza", "member123", "Intermediate", "approved"),
    ("maria.santos@student.ustp.edu.ph", "Maria Santos", "member123", "Beginner", "approved"),
    ("james.villanueva@student.ustp.edu.ph", "James Villanueva", "member123", "Advanced", "approved"),
    ("sophia.lim@student.ustp.edu.ph", "Sophia Lim", "member123", "Intermediate", "approved"),
    ("miguel.torres@student.ustp.edu.ph", "Miguel Torres", "member123", "Expert", "approved"),
    ("riza.garcia@student.ustp.edu.ph", "Riza Garcia", "member123", "Beginner", "pending"),
    ("daniel.flo@student.ustp.edu.ph", "Daniel Flo", "member123", "Novice", "pending"),
    ("elena.cruz@student.ustp.edu.ph", "Elena Cruz", "member123", "Advanced", "approved"),
    ("mark.delosreyes@student.ustp.edu.ph", "Mark Delos Reyes", "member123", "Intermediate", "approved"),
]


def seed_extra_members(db, role_ids: dict[str, int], skill_ids: dict[str, int]) -> None:
    """Additional USTP student members for admin Members page and rankings."""
    created = 0
    for email, name, pw, skill_key, status in EXTRA_MEMBER_ACCOUNTS:
        if _seed_user(
            db,
            email=email,
            fullname=name,
            password=pw,
            role_id=role_ids["Member"],
            skill_level_id=skill_ids.get(skill_key),
            status=status,
        ):
            created += 1
            print(f"  -> Member: {email} / {pw} ({status})")
    if created:
        print(f"  -> Added {created} member account(s)")


def upgrade_facebook_posts_schema() -> None:
    """Align legacy facebook_posts table with Graph API share log schema."""
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE facebook_posts ADD COLUMN IF NOT EXISTS message TEXT"))
        conn.execute(
            text(
                "ALTER TABLE facebook_posts ADD COLUMN IF NOT EXISTS status "
                "VARCHAR(30) NOT NULL DEFAULT 'pending'"
            )
        )
        conn.execute(text("ALTER TABLE facebook_posts ADD COLUMN IF NOT EXISTS error_message TEXT"))
        conn.execute(
            text(
                "DO $$ BEGIN "
                "IF EXISTS (SELECT 1 FROM information_schema.columns "
                "WHERE table_name='facebook_posts' AND column_name='posted_at') "
                "AND NOT EXISTS (SELECT 1 FROM information_schema.columns "
                "WHERE table_name='facebook_posts' AND column_name='created_at') THEN "
                "ALTER TABLE facebook_posts RENAME COLUMN posted_at TO created_at; "
                "END IF; END $$"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE facebook_posts ADD COLUMN IF NOT EXISTS created_at "
                "TIMESTAMPTZ DEFAULT NOW()"
            )
        )
        conn.execute(
            text("ALTER TABLE facebook_posts ALTER COLUMN facebook_post_id DROP NOT NULL")
        )


def upgrade_member_rankings_schema() -> None:
    """Admin remarks and competency overrides on member_rankings."""
    with engine.begin() as conn:
        conn.execute(
            text("ALTER TABLE member_rankings ADD COLUMN IF NOT EXISTS admin_remarks TEXT")
        )
        conn.execute(
            text(
                "ALTER TABLE member_rankings ADD COLUMN IF NOT EXISTS "
                "competency_level_override VARCHAR(40)"
            )
        )


def upgrade_ai_detection_schema() -> None:
    """Align legacy ai_detection_results with admin review workflow."""
    with engine.begin() as conn:
        conn.execute(
            text(
                "ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS "
                "review_status VARCHAR(40) NOT NULL DEFAULT 'pending_review'"
            )
        )
        conn.execute(
            text("ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS admin_remarks TEXT")
        )
        conn.execute(
            text("ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS detection_remarks TEXT")
        )
        conn.execute(
            text("ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS exif_metadata TEXT")
        )
        conn.execute(
            text(
                "ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS "
                "reviewed_by INTEGER REFERENCES users(id) ON DELETE SET NULL"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE ai_detection_results ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ"
            )
        )


def upgrade_event_calendar_schema() -> None:
    """Extend event_calendar for admin calendar UI."""
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE event_calendar ALTER COLUMN request_id DROP NOT NULL"))
        for stmt in (
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS description TEXT",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS start_time TIME",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS end_time TIME",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS status VARCHAR(40) NOT NULL DEFAULT 'upcoming'",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS assigned_member_id INTEGER REFERENCES users(id) ON DELETE SET NULL",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS admin_remarks TEXT",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW()",
            "ALTER TABLE event_calendar ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()",
        ):
            conn.execute(text(stmt))


def upgrade_timestamp_columns() -> None:
    """Ensure updated_at exists on TimestampMixin tables."""
    tables = (
        "users",
        "documentation_requests",
        "event_calendar",
        "ai_detection_results",
        "notifications",
        "feedbacks",
        "announcements",
        "media_comments",
        "user_sessions",
        "audit_logs",
    )
    with engine.begin() as conn:
        for table in tables:
            conn.execute(
                text(
                    f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS "
                    "updated_at TIMESTAMPTZ DEFAULT NOW()"
                )
            )


def upgrade_users_removal_schema() -> None:
    """Soft-delete fields for admin member removal."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS removed_by INTEGER REFERENCES users(id) ON DELETE SET NULL",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS removal_reason TEXT",
        ):
            conn.execute(text(stmt))


def upgrade_users_registration_schema() -> None:
    """Member/org registration fields and approval metadata."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id VARCHAR(40)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS contact_number VARCHAR(40)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS adviser_name VARCHAR(120)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS rejection_reason TEXT",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ",
        ):
            conn.execute(text(stmt))


def upgrade_media_evaluation_schema() -> None:
    """Extended criteria breakdown for member photo evaluation."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE media_evaluations ADD COLUMN IF NOT EXISTS criteria_json TEXT",
            "ALTER TABLE media_evaluations ADD COLUMN IF NOT EXISTS quality_level VARCHAR(40)",
            "ALTER TABLE media_evaluations ADD COLUMN IF NOT EXISTS recommendation VARCHAR(80)",
        ):
            conn.execute(text(stmt))


def upgrade_media_files_schema() -> None:
    """Allow standalone practice uploads without a documentation request."""
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE media_files ALTER COLUMN request_id DROP NOT NULL"))


def upgrade_media_files_classification_schema() -> None:
    """Event documentation vs member evaluation + approval + Facebook publish tracking."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS media_category VARCHAR(30) NOT NULL DEFAULT 'member_evaluation'",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) NOT NULL DEFAULT 'not_applicable'",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS approval_rejection_reason TEXT",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS facebook_publish_status VARCHAR(20) NOT NULL DEFAULT 'not_published'",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS facebook_post_id VARCHAR(100)",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS facebook_published_at TIMESTAMPTZ",
        ):
            conn.execute(text(stmt))
        conn.execute(
            text(
                "UPDATE media_files SET media_category = 'event_documentation' "
                "WHERE request_id IS NOT NULL AND media_category = 'member_evaluation'"
            )
        )
        conn.execute(
            text(
                "UPDATE media_files SET approval_status = 'approved' "
                "WHERE media_category = 'event_documentation' AND approval_status = 'not_applicable'"
            )
        )
        conn.execute(
            text(
                "UPDATE media_files SET approval_status = 'not_applicable' "
                "WHERE media_category = 'member_evaluation'"
            )
        )


def upgrade_event_media_skip_approval_workflow() -> None:
    """Event uploads are visible immediately — no admin approval queue."""
    with engine.begin() as conn:
        conn.execute(
            text(
                "UPDATE media_files SET approval_status = 'not_applicable', approval_rejection_reason = NULL "
                "WHERE media_category = 'event_documentation' "
                "AND approval_status IN ('pending', 'approved')"
            )
        )


def upgrade_feedback_admin_review_schema() -> None:
    """Admin response and review status for requester feedback."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE feedbacks ADD COLUMN IF NOT EXISTS admin_response TEXT",
            "ALTER TABLE feedbacks ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) NOT NULL DEFAULT 'pending'",
        ):
            conn.execute(text(stmt))


def upgrade_media_curation_schema() -> None:
    """Server-side best picks and album grouping for event media."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS is_best_shot BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE media_files ADD COLUMN IF NOT EXISTS album_name_override VARCHAR(255)",
        ):
            conn.execute(text(stmt))


def upgrade_documentation_requests_schema() -> None:
    """Extended requestor form fields (time, coverage requirements, reschedule history)."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS start_time VARCHAR(20)",
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS end_time VARCHAR(20)",
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS requirements TEXT",
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS original_event_date DATE",
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS last_rescheduled_at TIMESTAMPTZ",
            "ALTER TABLE documentation_requests ADD COLUMN IF NOT EXISTS reschedule_history TEXT",
        ):
            conn.execute(text(stmt))


def upgrade_request_assignments_schema() -> None:
    """Assignment accept/decline workflow fields."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS decline_reason TEXT",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS decline_reason_code VARCHAR(40)",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS replaces_assignment_id INTEGER REFERENCES request_assignments(id) ON DELETE SET NULL",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS service_points_awarded INTEGER",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ DEFAULT NOW()",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ",
            "ALTER TABLE request_assignments ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ",
        ):
            conn.execute(text(stmt))


def upgrade_notification_schema() -> None:
    """Rich notification metadata for notification center UI."""
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE notifications ADD COLUMN IF NOT EXISTS category VARCHAR(40) NOT NULL DEFAULT 'system_alert'",
            "ALTER TABLE notifications ADD COLUMN IF NOT EXISTS priority VARCHAR(20) NOT NULL DEFAULT 'normal'",
            "ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type VARCHAR(40)",
            "ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_ref_id INTEGER",
        ):
            conn.execute(text(stmt))


def recreate_public_schema() -> None:
    """Drop every table in public schema (removes legacy + new tables)."""
    with engine.begin() as conn:
        conn.execute(text("DROP SCHEMA public CASCADE"))
        conn.execute(text("CREATE SCHEMA public"))
        conn.execute(text("GRANT ALL ON SCHEMA public TO postgres"))
        conn.execute(text("GRANT ALL ON SCHEMA public TO public"))


def main() -> None:
    print("ACCESS VisionCheck — creating database tables...")
    masked_url = settings.database_url.replace(settings.db_password, "****")
    print(f"Database: {masked_url}")

    if os.getenv("RECREATE_DB", "").lower() in ("1", "true", "yes"):
        print("RECREATE_DB=true — resetting public schema...")
        recreate_public_schema()

    Base.metadata.create_all(bind=engine)
    upgrade_facebook_posts_schema()
    upgrade_ai_detection_schema()
    upgrade_event_calendar_schema()
    upgrade_member_rankings_schema()
    upgrade_timestamp_columns()
    upgrade_documentation_requests_schema()
    upgrade_request_assignments_schema()
    upgrade_users_registration_schema()
    upgrade_users_removal_schema()
    upgrade_notification_schema()
    upgrade_media_evaluation_schema()
    upgrade_media_files_schema()
    upgrade_media_files_classification_schema()
    upgrade_event_media_skip_approval_workflow()
    upgrade_feedback_admin_review_schema()
    upgrade_media_curation_schema()

    db = SessionLocal()
    try:
        role_ids = seed_roles(db)
        skill_ids = seed_skill_levels(db)
        seed_default_users(db, role_ids, skill_ids)
        seed_member_demo(db)
        seed_sample_approved_documentation(db)
        from app.seed.sample_data import seed_sample_dataset

        seed_sample_dataset(db)
        _print_setup_success()
    finally:
        db.close()


def _print_setup_success() -> None:
    print()
    print("SUCCESS: All ACCESS VisionCheck tables were created.")
    print("Tables:")
    for name in sorted(Base.metadata.tables.keys()):
        print(f"  • {name}")
    print()
    print("Next: python manage.py runserver")
    print("Optional: python seed_sample_data.py  (re-apply sample rows on existing DB)")


SAMPLE_APPROVED_TITLE = "Sample Approved Event"


def seed_sample_approved_documentation(db) -> None:
    """One approved documentation request so Gallery upload works out of the box."""
    from datetime import date, timedelta

    from app.models.documentation_request import DocumentationRequest
    from app.models.user import User

    admin = db.query(User).filter(User.email == "admin@access.edu").first()
    if not admin:
        return

    req = (
        db.query(DocumentationRequest)
        .filter(DocumentationRequest.title == SAMPLE_APPROVED_TITLE)
        .first()
    )
    if req:
        if req.status.lower() != "approved":
            req.status = "approved"
            req.rejection_reason = None
            db.commit()
        return

    db.add(
        DocumentationRequest(
            requestor_id=admin.id,
            title=SAMPLE_APPROVED_TITLE,
            description="Sample approved documentation for Gallery uploads and Facebook share testing.",
            event_date=date.today() + timedelta(days=14),
            venue="USTP Oroquieta Campus",
            status="approved",
        )
    )
    db.commit()
    print(f"  -> Sample approved documentation: {SAMPLE_APPROVED_TITLE}")


def seed_member_demo(db) -> None:
    """Sample rankings, assignments, events, and notifications for members."""
    from datetime import date, timedelta

    from app.models.documentation_request import DocumentationRequest
    from app.models.event_calendar import EventCalendar
    from app.models.member_ranking import MemberRanking
    from app.models.notification import Notification
    from app.models.request_assignment import RequestAssignment
    from app.models.role import Role
    from app.models.user import User

    admin = db.query(User).filter(User.email == "admin@access.edu").first()
    if not admin:
        return

    member_role = db.query(Role).filter(Role.role_name == "Member").first()
    if not member_role:
        return

    members = (
        db.query(User)
        .filter(User.role_id == member_role.id, User.status == "approved")
        .order_by(User.id.asc())
        .all()
    )
    if not members:
        return

    # Leaderboard points — higher skill tiers get more demo points.
    points_by_email = {
        "member@access.edu": 120,
        "miguel.torres@student.ustp.edu.ph": 210,
        "james.villanueva@student.ustp.edu.ph": 185,
        "elena.cruz@student.ustp.edu.ph": 160,
        "carlos.m@student.ustp.edu.ph": 140,
        "sophia.lim@student.ustp.edu.ph": 115,
        "mark.delosreyes@student.ustp.edu.ph": 95,
        "maria.santos@student.ustp.edu.ph": 75,
    }
    for idx, member in enumerate(members, start=1):
        if db.query(MemberRanking).filter(MemberRanking.user_id == member.id).first():
            continue
        points = points_by_email.get(member.email, max(40, 100 - idx * 8))
        db.add(MemberRanking(user_id=member.id, total_points=points, rank_position=idx))
    db.commit()

    ranked = (
        db.query(MemberRanking)
        .order_by(MemberRanking.total_points.desc())
        .all()
    )
    for idx, row in enumerate(ranked, start=1):
        row.rank_position = idx
    db.commit()

    req = db.query(DocumentationRequest).filter(DocumentationRequest.title == "USTP Founders Day").first()
    if not req:
        req = DocumentationRequest(
            requestor_id=admin.id,
            title="USTP Founders Day",
            description="Campus-wide documentation coverage",
            event_date=date.today() + timedelta(days=7),
            venue="Main Gymnasium",
            status="approved",
        )
        db.add(req)
        db.flush()
        db.add(
            EventCalendar(
                request_id=req.id,
                title=req.title,
                start_date=req.event_date,
                venue=req.venue,
            )
        )
        db.commit()

    assign_emails = [
        "member@access.edu",
        "carlos.m@student.ustp.edu.ph",
        "maria.santos@student.ustp.edu.ph",
        "sophia.lim@student.ustp.edu.ph",
    ]
    roles = ["photographer", "videographer", "editor", "photographer"]
    for email, task_role in zip(assign_emails, roles, strict=False):
        member = db.query(User).filter(User.email == email).first()
        if not member:
            continue
        exists = (
            db.query(RequestAssignment)
            .filter(
                RequestAssignment.request_id == req.id,
                RequestAssignment.member_id == member.id,
            )
            .first()
        )
        if exists:
            continue
        db.add(
            RequestAssignment(
                request_id=req.id,
                member_id=member.id,
                assigned_by=admin.id,
                task_role=task_role,
                status="assigned",
            )
        )
        db.add(
            Notification(
                user_id=member.id,
                title="New task assigned",
                message=f"You were assigned as {task_role} for USTP Founders Day.",
                is_read=False,
            )
        )
    db.commit()


if __name__ == "__main__":
    main()
