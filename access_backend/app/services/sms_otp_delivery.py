"""Send registration OTP SMS (Semaphore or dev log)."""

import logging
import httpx

from app.config import settings

logger = logging.getLogger(__name__)


def send_registration_otp(*, phone_e164: str, code: str) -> None:
    provider = (settings.sms_provider or "log").strip().lower()
    body = (
        f"ACCESS VisionCheck: Your verification code is {code}. "
        "It expires in a few minutes. Do not share this code."
    )

    if provider == "none":
        raise RuntimeError("SMS provider is disabled (SMS_PROVIDER=none).")

    if provider == "log":
        line = f"SMS OTP (dev log) to {phone_e164}: {code}"
        logger.warning(line)
        # Uvicorn often hides app loggers; always mirror to the runserver console.
        print(f"\n>>> {line} <<<\n", flush=True)
        return

    if provider == "semaphore":
        api_key = settings.semaphore_api_key.strip()
        if not api_key:
            raise RuntimeError("SEMAPHORE_API_KEY is not configured.")
        number = phone_e164.lstrip("+")
        sender = (settings.sms_sender_name or "ACCESS")[:11]
        with httpx.Client(timeout=20.0) as client:
            resp = client.post(
                "https://api.semaphore.co/api/v4/messages",
                data={
                    "apikey": api_key,
                    "number": number,
                    "message": body,
                    "sendername": sender,
                },
            )
        if resp.status_code >= 400:
            raise RuntimeError(f"Semaphore SMS failed ({resp.status_code}): {resp.text[:200]}")
        return

    raise RuntimeError(f"Unknown SMS_PROVIDER: {provider}")
