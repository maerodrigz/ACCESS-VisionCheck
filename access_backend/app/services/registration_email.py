"""Registration lifecycle emails (pending, approved, rejected)."""

from __future__ import annotations

import threading

from app.models.enums import RoleName
from app.services.email_delivery import is_email_configured, send_email

_PRODUCT = "ACCESS VisionCheck"


def _role_label(role_name: str | None) -> str:
    if role_name == RoleName.ORGANIZATION:
        return "requestor (organization)"
    return "member"


def send_registration_received(*, to_email: str, fullname: str, role_name: str | None) -> bool:
    name = (fullname or "there").strip()
    role = _role_label(role_name)
    subject = f"{_PRODUCT}: registration received"
    plain = (
        f"Hello {name},\n\n"
        f"We received your {role} registration for {_PRODUCT}.\n"
        "An administrator will review your application. "
        "You will receive another email when your account is approved or declined.\n\n"
        "You cannot sign in until an administrator approves your account.\n\n"
        f"— {_PRODUCT}\n"
        "USTP Oroquieta Campus"
    )
    html = f"""
    <p>Hello {name},</p>
    <p>We received your <strong>{role}</strong> registration for {_PRODUCT}.</p>
    <p>An administrator will review your application. You will receive another email when your account is approved or declined.</p>
    <p>You cannot sign in until an administrator approves your account.</p>
    <p>— {_PRODUCT}<br>USTP Oroquieta Campus</p>
    """
    return send_email(to_email, subject, plain, html_body=html)


def send_registration_approved(*, to_email: str, fullname: str) -> bool:
    name = (fullname or "there").strip()
    subject = f"{_PRODUCT}: registration approved"
    plain = (
        f"Hello {name},\n\n"
        f"Your {_PRODUCT} account was approved.\n"
        "Open the mobile app and sign in with the email and password you registered.\n\n"
        f"— {_PRODUCT}\n"
        "USTP Oroquieta Campus"
    )
    html = f"""
    <p>Hello {name},</p>
    <p>Your <strong>{_PRODUCT}</strong> account was <strong>approved</strong>.</p>
    <p>Open the mobile app and sign in with the email and password you registered.</p>
    <p>— {_PRODUCT}<br>USTP Oroquieta Campus</p>
    """
    return send_email(to_email, subject, plain, html_body=html)


def send_registration_rejected(*, to_email: str, fullname: str, reason: str) -> bool:
    name = (fullname or "there").strip()
    reason_text = (reason or "").strip() or "No reason was provided. Contact your administrator."
    subject = f"{_PRODUCT}: registration declined"
    plain = (
        f"Hello {name},\n\n"
        f"Your {_PRODUCT} registration was not approved.\n\n"
        f"Administrator note: {reason_text}\n\n"
        "If you sign in, the app will show this message as well.\n\n"
        f"— {_PRODUCT}\n"
        "USTP Oroquieta Campus"
    )
    html = f"""
    <p>Hello {name},</p>
    <p>Your <strong>{_PRODUCT}</strong> registration was <strong>not approved</strong>.</p>
    <p><strong>Administrator note:</strong> {reason_text}</p>
    <p>If you sign in, the app will show this message as well.</p>
    <p>— {_PRODUCT}<br>USTP Oroquieta Campus</p>
    """
    return send_email(to_email, subject, plain, html_body=html)


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
