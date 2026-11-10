"""Outbound SMS via TextBee (or log provider for tests). Never logs OTP codes."""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

FIXED_TIMEOUT_S = 20.0


def _mask_phone(e164: str) -> str:
    text = (e164 or "").strip()
    if len(text) < 6:
        return "***"
    return f"{text[:4]}…{text[-4:]}"


def is_sms_configured() -> bool:
    provider = (settings.sms_provider or "log").strip().lower()
    if provider == "textbee":
        return bool((settings.textbee_api_key or "").strip())
    return provider == "log"


def send_sms(*, to_e164: str, message: str) -> bool:
    """
    Send SMS. Returns True if accepted by the provider (or log provider).
    Acceptance is not carrier delivery. Never logs message body.
    """
    provider = (settings.sms_provider or "log").strip().lower()
    if provider == "log":
        logger.info("SMS log-provider: queued to %s (body omitted)", _mask_phone(to_e164))
        return True
    if provider != "textbee":
        logger.error("SMS provider %r is not supported", provider)
        return False
    return _send_textbee(to_e164=to_e164, message=message)


def _send_textbee(*, to_e164: str, message: str) -> bool:
    api_key = (settings.textbee_api_key or "").strip()
    if not api_key:
        logger.error("TEXTBEE_API_KEY missing; SMS not sent to %s", _mask_phone(to_e164))
        return False

    base = (settings.textbee_base_url or "https://api.textbee.dev/api/v1").rstrip("/")
    url = f"{base}/gateway/send-sms"
    body: dict[str, Any] = {
        "message": message,
        "recipients": [to_e164],
    }
    device_id = (settings.textbee_device_id or "").strip()
    if device_id:
        body["deviceId"] = device_id

    headers = {
        "x-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    try:
        with httpx.Client(timeout=FIXED_TIMEOUT_S) as client:
            response = client.post(url, headers=headers, json=body)
    except httpx.TimeoutException:
        logger.error("TextBee timeout sending to %s", _mask_phone(to_e164))
        return False
    except httpx.RequestError as exc:
        logger.error("TextBee network error for %s: %s", _mask_phone(to_e164), type(exc).__name__)
        return False

    if response.status_code != 200:
        detail = ""
        try:
            payload = response.json()
            if isinstance(payload, dict):
                detail = str(payload.get("message") or payload.get("error") or "")[:200]
        except Exception:
            detail = (response.text or "")[:120]
        logger.error(
            "TextBee rejected send to %s HTTP %s %s",
            _mask_phone(to_e164),
            response.status_code,
            detail,
        )
        return False

    try:
        payload = response.json()
        data = payload.get("data") if isinstance(payload, dict) else None
        success = isinstance(data, dict) and bool(data.get("success", True))
        batch = data.get("smsBatchId") if isinstance(data, dict) else None
        batch_tail = f"…{str(batch)[-8:]}" if batch else "(none)"
        logger.info(
            "TextBee accepted SMS to %s batch=%s (not carrier delivery)",
            _mask_phone(to_e164),
            batch_tail,
        )
        return success
    except Exception:
        logger.info("TextBee HTTP 200 for %s (response parse skipped)", _mask_phone(to_e164))
        return True
