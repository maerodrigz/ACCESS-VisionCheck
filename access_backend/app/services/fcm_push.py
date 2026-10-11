"""Firebase Cloud Messaging for member and requestor devices (optional)."""

from __future__ import annotations

import logging
import threading
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.crud import push_device_token as token_crud
from app.models.enums import RoleName
from app.models.user import User
from app.services.firebase_admin_app import ensure_firebase_admin_app, is_fcm_configured

logger = logging.getLogger(__name__)


def _mobile_push_user(db: Session, user_id: int) -> bool:
    user = db.scalar(
        select(User).options(joinedload(User.role)).where(User.id == user_id)
    )
    if user is None or user.role is None:
        return False
    return user.role.role_name in (RoleName.MEMBER, RoleName.ORGANIZATION)


def _send_tokens(tokens: list[str], title: str, body: str, data: dict[str, str]) -> None:
    if not tokens:
        return
    if not is_fcm_configured():
        return
    if ensure_firebase_admin_app() is None:
        logger.warning("FCM skipped: Firebase Admin app not initialized")
        return
    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase_admin messaging unavailable")
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title[:200], body=body[:1024]),
        data=data,
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="access_alerts",
                sound="default",
            ),
        ),
    )
    try:
        response = messaging.send_each_for_multicast(message)
    except Exception as exc:
        logger.warning("FCM multicast failed: %s", exc)
        return

    if response.failure_count:
        for idx, send_resp in enumerate(response.responses):
            if send_resp.success:
                continue
            err = send_resp.exception
            token_hint = tokens[idx][:12] + "…" if idx < len(tokens) else "?"
            logger.warning("FCM token %s failed: %s", token_hint, err)


def send_to_user(
    db: Session,
    user_id: int,
    title: str,
    message: str,
    *,
    category: str = "system_alert",
    notification_id: int | None = None,
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> None:
    if not _mobile_push_user(db, user_id):
        return
    tokens = token_crud.list_tokens_for_user(db, user_id)
    if not tokens:
        return
    data: dict[str, str] = {"category": category}
    if notification_id is not None:
        data["notification_id"] = str(notification_id)
    if action_type:
        data["action_type"] = action_type
    if action_ref_id is not None:
        data["action_ref_id"] = str(action_ref_id)
    _send_tokens(tokens, title, message, data)


def send_to_user_async(
    user_id: int,
    title: str,
    message: str,
    *,
    category: str = "system_alert",
    notification_id: int | None = None,
    action_type: str | None = None,
    action_ref_id: int | None = None,
) -> None:
    """Fire-and-forget push so API handlers stay fast."""

    def _run() -> None:
        from app.database import SessionLocal

        session = SessionLocal()
        try:
            send_to_user(
                session,
                user_id,
                title,
                message,
                category=category,
                notification_id=notification_id,
                action_type=action_type,
                action_ref_id=action_ref_id,
            )
        except Exception as exc:
            logger.warning("FCM async send failed: %s", exc)
        finally:
            session.close()

    threading.Thread(target=_run, daemon=True).start()
