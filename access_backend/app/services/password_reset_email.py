"""Password reset OTP email (and dev log when SMTP is off)."""

from __future__ import annotations

import logging
import threading

from app.services.email_branding import branded_html, esc, product_name
from app.services.email_delivery import is_email_configured, send_email

logger = logging.getLogger(__name__)

_NO_REPLY_PLAIN = (
    "\n\nDo not reply to this email. This mailbox is not monitored. "
    "Contact your ACCESS administrator through official campus channels if you need help."
)
_NO_REPLY_HTML = (
    '<p style="margin-top:16px;font-size:12px;color:#64748b;line-height:1.45;">'
    "<strong>Do not reply to this email.</strong> This mailbox is not monitored."
    "</p>"
)


def send_password_reset_otp_email(*, to_email: str, fullname: str, code: str) -> bool:
    name = esc(fullname or "there")
    product = esc(product_name())
    subject = f"{product_name()}: password reset code"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"Your {product_name()} password reset code is: {code}\n\n"
        "This code expires in a few minutes. Do not share it with anyone.\n\n"
        f"{product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>Use this code to reset your <strong>{product}</strong> password:</p>
    <p style="background:#f8fafc;border-left:4px solid #0052D4;padding:12px 14px;border-radius:8px;font-family:monospace;font-size:18px;letter-spacing:2px;">
      {esc(code)}
    </p>
    <p>This code expires in a few minutes. Do not share it with anyone.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def deliver_password_reset_otp(*, to_email: str, code: str, fullname: str = "") -> bool:
    """Send OTP via SMTP when configured; otherwise log to server console (dev). Returns True if emailed."""
    if is_email_configured():
        send_password_reset_otp_email(to_email=to_email, fullname=fullname, code=code)
        return True
    line = f"Password reset OTP (dev log) to {to_email}: {code}"
    logger.warning(line)
    print(f"\n>>> {line} <<<\n", flush=True)
    return False


def deliver_password_reset_otp_async(*, to_email: str, code: str, fullname: str = "") -> None:
    """Queue OTP email so API routes return before SMTP finishes (avoids mobile HTTP timeout)."""
    if not is_email_configured():
        deliver_password_reset_otp(to_email=to_email, code=code, fullname=fullname)
        return

    def _run() -> None:
        try:
            send_password_reset_otp_email(to_email=to_email, fullname=fullname, code=code)
        except Exception:
            logger.exception("password reset OTP email failed for %s", to_email)

    threading.Thread(target=_run, daemon=True).start()
