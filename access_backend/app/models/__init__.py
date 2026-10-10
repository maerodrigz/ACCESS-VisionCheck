"""
Import all models so SQLAlchemy registers tables on Base.metadata.

Used by create_tables.py and the FastAPI application.
"""

from app.models.role import Role
from app.models.skill_level import SkillLevel
from app.models.user import User
from app.models.documentation_request import DocumentationRequest
from app.models.request_assignment import RequestAssignment
from app.models.event_calendar import EventCalendar
from app.models.media_file import MediaFile
from app.models.media_evaluation import MediaEvaluation
from app.models.ai_detection_result import AiDetectionResult
from app.models.ai_review_history import AiReviewHistory
from app.models.feedback import Feedback
from app.models.assignment_member_feedback import AssignmentMemberFeedback
from app.models.member_milestone import MemberMilestone
from app.models.member_ranking import MemberRanking
from app.models.notification import Notification
from app.models.member_notification_preference import MemberNotificationPreference
from app.models.analytics_report import AnalyticsReport
from app.models.archive import Archive
from app.models.facebook_post import FacebookPost
from app.models.facebook_setting import FacebookSetting
from app.models.audit_log import AuditLog
from app.models.login_history import LoginHistory
from app.models.user_session import UserSession
from app.models.media_comment import MediaComment
from app.models.announcement import Announcement
from app.models.system_branding import SystemBranding
from app.models.system_settings import SystemSettings
from app.models.push_device_token import PushDeviceToken

__all__ = [
    "Role",
    "SkillLevel",
    "User",
    "DocumentationRequest",
    "RequestAssignment",
    "EventCalendar",
    "MediaFile",
    "MediaEvaluation",
    "AiDetectionResult",
    "AiReviewHistory",
    "Feedback",
    "AssignmentMemberFeedback",
    "MemberMilestone",
    "MemberRanking",
    "Notification",
    "MemberNotificationPreference",
    "AnalyticsReport",
    "Archive",
    "FacebookPost",
    "FacebookSetting",
    "AuditLog",
    "LoginHistory",
    "UserSession",
    "MediaComment",
    "Announcement",
    "SystemBranding",
    "SystemSettings",
    "PushDeviceToken",
]
