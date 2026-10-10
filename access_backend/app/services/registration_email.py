"""Registration lifecycle emails (pending, approved, rejected)."""

from __future__ import annotations

import threading

from app.models.enums import RoleName
from app.services.email_branding import branded_html, esc, product_name
from app.services.email_delivery import is_email_configured, send_email


_NO_REPLY_PLAIN = (
    "\n\nThis is an automated message. You do not need to reply. "
    "For help, contact your ACCESS administrator through official campus channels."
)
_NO_REPLY_HTML = (
    '<p style="margin-top:16px;font-size:12px;color:#64748b;line-height:1.45;">'
    "This is an automated message. You do not need to reply. "
    "For help, contact your ACCESS administrator through official campus channels."
    "</p>"
)


def _role_label(role_name: str | None) -> str:
    if role_name == RoleName.ORGANIZATION:
        return "requestor (organization)"
    return "member"


def send_registration_received(*, to_email: str, fullname: str, role_name: str | None) -> bool:
    name = esc(fullname or "there")
    role = esc(_role_label(role_name))
    product = esc(product_name())
    subject = f"{product_name()}: registration received"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"We received your {_role_label(role_name)} registration for {product_name()}.\n"
        "An administrator will review your application. "
        "You will receive another email when your account is approved or declined.\n\n"
        "You cannot sign in until an administrator approves your account.\n\n"
        f"— {product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>We received your <strong>{role}</strong> registration for {product}.</p>
    <p>An administrator will review your application. You will receive another email when your account is approved or declined.</p>
    <p>You cannot sign in until an administrator approves your account.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def send_registration_approved(*, to_email: str, fullname: str) -> bool:
    name = esc(fullname or "there")
    product = esc(product_name())
    subject = f"{product_name()}: registration approved"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"Your {product_name()} account was approved.\n"
        "Open the mobile app and sign in with the email and password you registered.\n\n"
        f"— {product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>Your <strong>{product}</strong> account was <strong style="color:#059669;">approved</strong>.</p>
    <p>Open the mobile app and sign in with the email and password you registered.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def send_registration_rejected(*, to_email: str, fullname: str, reason: str) -> bool:
    name = esc(fullname or "there")
    reason_text = esc((reason or "").strip() or "No reason was provided. Contact your administrator.")
    product = esc(product_name())
    subject = f"{product_name()}: registration declined"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"Your {product_name()} registration was not approved.\n\n"
        f"Administrator note: {(reason or '').strip() or 'No reason was provided.'}\n\n"
        "If you sign in, the app will show this message as well.\n\n"
        f"— {product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>Your <strong>{product}</strong> registration was <strong style="color:#dc2626;">not approved</strong>.</p>
    <p style="background:#f8fafc;border-left:4px solid #0052D4;padding:12px 14px;border-radius:8px;">
      <strong>Administrator note:</strong><br />{reason_text}
    </p>
    <p>If you sign in, the app will show this message as well.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def _fire_and_forget(fn, **kwargs) -> None:
    if not is_email_configured():
        return

    def _run() -> None:
        try:
            fn(**kwargs)
        except Exception:
            pass

    threading.Thread(target=_run, daemon=True).start()


def notify_registration_received_async(*, to_email: str, fullname: str, role_name: str | None) -> None:
    _fire_and_forget(send_registration_received, to_email=to_email, fullname=fullname, role_name=role_name)


def notify_registration_approved_async(*, to_email: str, fullname: str) -> None:
    _fire_and_forget(send_registration_approved, to_email=to_email, fullname=fullname)


def notify_registration_rejected_async(*, to_email: str, fullname: str, reason: str) -> None:
    _fire_and_forget(send_registration_rejected, to_email=to_email, fullname=fullname, reason=reason)
