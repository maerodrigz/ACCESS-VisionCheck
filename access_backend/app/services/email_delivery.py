"""Optional SMTP email delivery (registration and other transactional mail)."""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import settings
from app.services.email_branding import LOGO_CID, logo_path, product_name

logger = logging.getLogger(__name__)


def is_email_configured() -> bool:
    if not settings.email_enabled:
        return False
    if not settings.smtp_host.strip():
        return False
    if not settings.email_from.strip():
        return False
    return True


def _no_reply_address() -> str:
    explicit = (settings.email_no_reply or "").strip()
    if explicit:
        return explicit
    from_addr = settings.email_from.strip()
    if "@" in from_addr:
        domain = from_addr.split("@", 1)[1].lower()
        return f"noreply@{domain}"
    return ""


def _from_header(*, automated: bool = False) -> str:
    from_addr = settings.email_from.strip()
    from_name = product_name()
    if automated:
        from_name = f"{from_name} (do not reply)" if from_name else "Do not reply"
    return f"{from_name} <{from_addr}>" if from_name else from_addr


def _apply_automated_headers(msg: EmailMessage | MIMEMultipart) -> None:
    msg["Auto-Submitted"] = "auto-generated"
    msg["X-Auto-Response-Suppress"] = "All"
    msg["Precedence"] = "auto_reply"
    no_reply = _no_reply_address()
    if no_reply:
        msg["Reply-To"] = no_reply


def _build_message(
    to: str,
    subject: str,
    plain_body: str,
    html_body: str | None,
    *,
    automated: bool = False,
) -> EmailMessage | MIMEMultipart:
    from_hdr = _from_header(automated=automated)
    reply_to = "" if automated else (settings.email_reply_to or "").strip()

    logo = logo_path()
    embed_logo = html_body and logo is not None

    if not embed_logo:
        msg = EmailMessage()
        msg["From"] = from_hdr
        msg["To"] = to
        msg["Subject"] = subject.strip()[:200]
        if automated:
            _apply_automated_headers(msg)
        elif reply_to:
            msg["Reply-To"] = reply_to
        msg.set_content(plain_body.strip())
        if html_body:
            msg.add_alternative(html_body.strip(), subtype="html")
        return msg

    root = MIMEMultipart("mixed")
    root["From"] = from_hdr
    root["To"] = to
    root["Subject"] = subject.strip()[:200]
    if automated:
        _apply_automated_headers(root)
    elif reply_to:
        root["Reply-To"] = reply_to

    related = MIMEMultipart("related")
    alt = MIMEMultipart("alternative")
    alt.attach(MIMEText(plain_body.strip(), "plain", "utf-8"))
    alt.attach(MIMEText(html_body.strip(), "html", "utf-8"))
    related.attach(alt)

    img_bytes = logo.read_bytes()
    mime_img = MIMEImage(img_bytes, _subtype="png")
    mime_img.add_header("Content-ID", f"<{LOGO_CID}>")
    mime_img.add_header("Content-Disposition", "inline", filename="access_logo.png")
    related.attach(mime_img)
    root.attach(related)
    return root


def send_email(
    to_address: str,
    subject: str,
    plain_body: str,
    *,
    html_body: str | None = None,
    automated: bool = False,
) -> bool:
    """Send one message. Returns True on success, False if skipped or failed."""
    to = (to_address or "").strip().lower()
    if not to:
        logger.debug("email skipped: empty recipient")
        return False
    if not is_email_configured():
        logger.debug("email skipped: SMTP not configured (set EMAIL_ENABLED and SMTP_* in .env)")
        return False

    msg = _build_message(to, subject, plain_body, html_body, automated=automated)

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
