"""Registration lifecycle emails (pending, approved, rejected) and signup OTP."""

from __future__ import annotations

import logging
import threading

from app.models.enums import RoleName
from app.services.email_branding import branded_html, esc, product_name
from app.services.email_delivery import is_email_configured, send_email

logger = logging.getLogger(__name__)

_NO_REPLY_PLAIN = (
    "\n\nDo not reply to this email. This mailbox is not monitored. "
    "Registration updates (pending review, approved, or declined) are sent automatically only. "
    "For help, contact your ACCESS administrator through official campus channels."
)
_NO_REPLY_HTML = (
    '<p style="margin-top:16px;font-size:12px;color:#64748b;line-height:1.45;">'
    "<strong>Do not reply to this email.</strong> This mailbox is not monitored. "
    "Registration updates (pending review, approved, or declined) are sent automatically only. "
    "For help, contact your ACCESS administrator through official campus channels."
    "</p>"
)


def _requestor_subtype_label(student_id: str | None) -> str:
    value = (student_id or "").strip().lower()
    if value == "organization":
        return "student organization requestor"
    if value in ("faculty", "instructor"):
        return "faculty / staff requestor"
    if "faculty" in value and "staff" in value:
        return "faculty / staff requestor"
    if value:
        return value
    return "requestor"


def _registration_type_label(role_name: str | None, student_id: str | None) -> str:
    if role_name == RoleName.ORGANIZATION:
        return _requestor_subtype_label(student_id)
    return "member"


def send_registration_received(
    *,
    to_email: str,
    fullname: str,
    role_name: str | None,
    student_id: str | None = None,
) -> bool:
    type_label = _registration_type_label(role_name, student_id)
    name = esc(fullname or "there")
    role = esc(type_label)
    product = esc(product_name())
    subject = f"{product_name()}: registration received"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"We received your {type_label} registration for {product_name()}.\n"
        "An administrator will review your application. "
        "You will receive another email when your account is approved or declined.\n\n"
        "You cannot sign in until an administrator approves your account.\n\n"
        f"{product_name()}\n"
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


def notify_registration_received_async(
    *,
    to_email: str,
    fullname: str,
    role_name: str | None,
    student_id: str | None = None,
) -> None:
    _fire_and_forget(
        send_registration_received,
        to_email=to_email,
        fullname=fullname,
        role_name=role_name,
        student_id=student_id,
    )


def notify_registration_approved_async(*, to_email: str, fullname: str) -> None:
    _fire_and_forget(send_registration_approved, to_email=to_email, fullname=fullname)


def notify_registration_rejected_async(*, to_email: str, fullname: str, reason: str) -> None:
    _fire_and_forget(send_registration_rejected, to_email=to_email, fullname=fullname, reason=reason)


def send_registration_otp_email(*, to_email: str, fullname: str, code: str) -> bool:
    name = esc(fullname or "there")
    product = esc(product_name())
    subject = f"{product_name()}: registration verification code"
    plain = (
        f"Hello {fullname or 'there'},\n\n"
        f"Your {product_name()} registration verification code is: {code}\n\n"
        "This code expires in a few minutes. Do not share it with anyone.\n\n"
        f"{product_name()}\n"
        "USTP Oroquieta Campus"
        f"{_NO_REPLY_PLAIN}"
    )
    inner = f"""
    <p>Hello {name},</p>
    <p>Use this code to verify your email for <strong>{product}</strong> registration:</p>
    <p style="background:#f8fafc;border-left:4px solid #0052D4;padding:12px 14px;border-radius:8px;font-family:monospace;font-size:18px;letter-spacing:2px;">
      {esc(code)}
    </p>
    <p>This code expires in a few minutes. Do not share it with anyone.</p>
    {_NO_REPLY_HTML}
    """
    return send_email(to_email, subject, plain, html_body=branded_html(inner), automated=True)


def _log_otp_fallback(*, to_email: str, code: str, reason: str) -> None:
    line = f"{reason} OTP for {to_email}: {code}"
    logger.warning(line)
    print(f"\n>>> {line} <<<\n", flush=True)


def deliver_registration_otp(*, to_email: str, code: str, fullname: str = "") -> bool:
    """Send registration OTP via SMTP when configured; otherwise log to server console (dev)."""
    if is_email_configured():
        ok = send_registration_otp_email(to_email=to_email, fullname=fullname, code=code)
        if not ok:
            _log_otp_fallback(
                to_email=to_email,
                code=code,
                reason="Registration email failed (check SMTP settings).",
            )
        return ok
    _log_otp_fallback(to_email=to_email, code=code, reason="Registration OTP (dev log)")
    return False


def deliver_registration_otp_async(*, to_email: str, code: str, fullname: str = "") -> None:
    """Queue OTP email so registration send returns before SMTP (avoids mobile HTTP timeout)."""
    if not is_email_configured():
        deliver_registration_otp(to_email=to_email, fullname=fullname, code=code)
        return

    def _run() -> None:
        try:
            ok = send_registration_otp_email(to_email=to_email, fullname=fullname, code=code)
            if not ok:
                _log_otp_fallback(
                    to_email=to_email,
                    code=code,
                    reason="Registration email failed (check SMTP / spam).",
                )
        except Exception:
            logger.exception("registration OTP email failed for %s", to_email)
            _log_otp_fallback(
                to_email=to_email,
                code=code,
                reason="Registration email error (see server log).",
            )

    threading.Thread(target=_run, daemon=True).start()
