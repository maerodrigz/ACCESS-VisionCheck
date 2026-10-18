"""Password reset email for member and requestor self-service recovery."""

from __future__ import annotations

import threading

from app.services.email_branding import branded_html, esc, product_name
from app.services.email_delivery import is_email_configured, send_email

_NO_REPLY_PLAIN = (
    "\n\nDo not reply to this email. This mailbox is not monitored. "
    "Contact your ACCESS administrator through official campus channels if you need help."
)
_NO_REPLY_HTML = (
    '<p style="margin-top:16px;font-size:12px;color:#64748b;line-height:1.45;">'
    "<strong>Do not reply to this email.</strong> This mailbox is not monitored."
    "</p>"
)


def send_temporary_password_email(*, to_email: str, fullname: str, temporary_password: str) -> bool:
    name = esc(fullname or "there")
    product = esc(product_name())
    subject = f"{product_name()}: temporary sign-in password"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"A temporary password was generated for your {product_name()} account.\n\n"
        f"Temporary password: {temporary_password}\n\n"
        "Sign in with this password, then open Account Settings and change your password immediately.\n\n"
        f"{product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>A temporary password was generated for your <strong>{product}</strong> account.</p>
    <p style="background:#f8fafc;border-left:4px solid #0052D4;padding:12px 14px;border-radius:8px;font-family:monospace;">
      {esc(temporary_password)}
    </p>
    <p>Sign in with this password, then open <strong>Account Settings</strong> and change your password immediately.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def notify_temporary_password_async(*, to_email: str, fullname: str, temporary_password: str) -> None:
    if not is_email_configured():
        return

    def _run() -> None:
        try:
            send_temporary_password_email(
                to_email=to_email,
                fullname=fullname,
                temporary_password=temporary_password,
            )
        except Exception:
            pass

    threading.Thread(target=_run, daemon=True).start()
