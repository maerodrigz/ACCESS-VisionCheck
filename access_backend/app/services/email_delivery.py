"""Optional SMTP email delivery (registration and other transactional mail)."""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)


def is_email_configured() -> bool:
    if not settings.email_enabled:
        return False
    if not settings.smtp_host.strip():
        return False
    if not settings.email_from.strip():
        return False
    return True


def send_email(
    to_address: str,
    subject: str,
    plain_body: str,
    *,
    html_body: str | None = None,
) -> bool:
    """Send one message. Returns True on success, False if skipped or failed."""
    to = (to_address or "").strip().lower()
    if not to:
        logger.debug("email skipped: empty recipient")
        return False
    if not is_email_configured():
        logger.debug("email skipped: SMTP not configured (set EMAIL_ENABLED and SMTP_* in .env)")
        return False

    msg = EmailMessage()
    from_addr = settings.email_from.strip()
    from_name = (settings.email_from_name or "ACCESS VisionCheck").strip()
    msg["From"] = f"{from_name} <{from_addr}>" if from_name else from_addr
    msg["To"] = to
    msg["Subject"] = subject.strip()[:200]
    msg.set_content(plain_body.strip())
    if html_body:
        msg.add_alternative(html_body.strip(), subtype="html")

    try:
        with smtplib.SMTP(settings.smtp_host.strip(), settings.smtp_port, timeout=30) as smtp:
            if settings.smtp_use_tls:
                smtp.starttls()
            user = settings.smtp_username.strip()
            password = settings.smtp_password
            if user:
                smtp.login(user, password)
            smtp.send_message(msg)
        logger.info("email sent to %s subject=%s", to, subject[:80])
        return True
    except Exception as exc:
        logger.warning("email send failed to %s: %s", to, exc)
        return False
