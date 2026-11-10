#!/usr/bin/env python3
"""
TextBee SMS connectivity smoke test (ACCESS VisionCheck).

Default mode is dry-run: validates env + optionally lists devices.
Does NOT send SMS unless BOTH are true:
  - env SMS_TEST_SEND=true
  - CLI flag --send

Usage (from access_backend):
  python scripts/textbee_sms_smoke.py
  python scripts/textbee_sms_smoke.py --send   # still blocked unless SMS_TEST_SEND=true

Never prints API keys, Authorization headers, or OTP values.
Does not touch the database, auth routes, or email OTP.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Any

import httpx

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from app.services.phone_normalize import normalize_ph_mobile  # noqa: E402

FIXED_TEST_MESSAGE = "ACCESS VisionCheck TextBee connectivity test"
DEFAULT_BASE_URL = "https://api.textbee.dev/api/v1"
REQUEST_TIMEOUT_S = 30.0


def _load_env() -> None:
    env_path = _ROOT / ".env"
    if not env_path.is_file():
        return
    try:
        from dotenv import load_dotenv

        # Do not override vars already present in the process environment.
        load_dotenv(env_path, override=False)
    except ImportError:
        pass


def _mask_secret(value: str) -> str:
    text = (value or "").strip()
    if not text:
        return "(empty)"
    if len(text) <= 8:
        return "***"
    return f"{text[:4]}…{text[-4:]} (len={len(text)})"


def _mask_phone(e164: str) -> str:
    text = (e164 or "").strip()
    if len(text) < 6:
        return "***"
    return f"{text[:4]}…{text[-4:]}"


def _truthy(raw: str | None) -> bool:
    return (raw or "").strip().lower() in {"1", "true", "yes", "on"}


def _headers(api_key: str) -> dict[str, str]:
    return {
        "x-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }


def _safe_error_body(response: httpx.Response) -> str:
    """Summarize API errors without dumping secrets."""
    try:
        payload = response.json()
    except Exception:
        text = (response.text or "").strip()
        if not text:
            return "(empty body)"
        return text[:200] + ("…" if len(text) > 200 else "")

    if isinstance(payload, dict):
        for key in ("message", "error", "msg"):
            val = payload.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()[:300]
        data = payload.get("data")
        if isinstance(data, dict):
            for key in ("message", "error"):
                val = data.get(key)
                if isinstance(val, str) and val.strip():
                    return val.strip()[:300]
        return "JSON error body (details omitted)"
    return "non-JSON error body"


def _list_devices(client: httpx.Client, base_url: str, api_key: str) -> tuple[int, list[dict[str, Any]]]:
    url = f"{base_url.rstrip('/')}/gateway/devices"
    response = client.get(url, headers=_headers(api_key))
    if response.status_code != 200:
        print(f"  FAIL GET /gateway/devices → HTTP {response.status_code}: {_safe_error_body(response)}")
        return response.status_code, []

    payload = response.json()
    devices = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(devices, list):
        print("  FAIL GET /gateway/devices → unexpected response shape (expected data: array)")
        return response.status_code, []

    print(f"  OK  GET /gateway/devices → {len(devices)} device(s)")
    for device in devices:
        if not isinstance(device, dict):
            continue
        device_id = str(device.get("_id") or "")
        name = device.get("name") or device.get("model") or "(unnamed)"
        enabled = device.get("enabled")
        is_default = device.get("isDefault")
        last_hb = device.get("lastHeartbeat") or "(none)"
        battery = None
        battery_info = device.get("batteryInfo")
        if isinstance(battery_info, dict):
            battery = battery_info.get("percentage")
        net = None
        network_info = device.get("networkInfo")
        if isinstance(network_info, dict):
            net = network_info.get("networkType")
        id_tail = device_id[-6:] if device_id else "??????"
        print(
            f"       - …{id_tail} name={name!r} enabled={enabled} "
            f"default={is_default} lastHeartbeat={last_hb} "
            f"battery={battery} network={net}"
        )
    return response.status_code, [d for d in devices if isinstance(d, dict)]


def _send_test_sms(
    client: httpx.Client,
    *,
    base_url: str,
    api_key: str,
    recipient: str,
    device_id: str | None,
) -> int:
    url = f"{base_url.rstrip('/')}/gateway/send-sms"
    body: dict[str, Any] = {
        "message": FIXED_TEST_MESSAGE,
        "recipients": [recipient],
    }
    if device_id:
        body["deviceId"] = device_id

    try:
        response = client.post(url, headers=_headers(api_key), json=body)
    except httpx.TimeoutException:
        print("  FAIL POST /gateway/send-sms → request timed out")
        return 1
    except httpx.RequestError as exc:
        print(f"  FAIL POST /gateway/send-sms → network error: {type(exc).__name__}")
        return 1

    if response.status_code != 200:
        print(f"  FAIL POST /gateway/send-sms → HTTP {response.status_code}: {_safe_error_body(response)}")
        return 1

    try:
        payload = response.json()
    except Exception:
        print("  FAIL POST /gateway/send-sms → non-JSON 200 response")
        return 1

    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        print("  FAIL POST /gateway/send-sms → unexpected response shape")
        return 1

    success = data.get("success")
    batch_id = data.get("smsBatchId")
    recipient_count = data.get("recipientCount")
    status_message = data.get("message")
    print("  OK  POST /gateway/send-sms accepted by TextBee API (queued/accepted, not carrier delivery)")
    print(f"       success={success!r} recipientCount={recipient_count!r}")
    if isinstance(batch_id, str) and batch_id:
        print(f"       smsBatchId=…{batch_id[-8:]} (full id omitted from verbose logs)")
    if isinstance(status_message, str) and status_message.strip():
        print(f"       apiMessage={status_message.strip()[:200]}")
    warning = data.get("warning")
    if isinstance(warning, dict):
        code = warning.get("code")
        wmsg = warning.get("message")
        print(f"       warning code={code!r} message={str(wmsg)[:200] if wmsg else None}")
    print(
        "  NOTE Acceptance is not delivery. Confirm the SMS on the test handset "
        "and/or poll GET /gateway/devices/{id}/sms-batch/{smsBatchId}."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="TextBee SMS connectivity smoke (dry-run by default)."
    )
    parser.add_argument(
        "--send",
        action="store_true",
        help="Attempt one SMS. Also requires SMS_TEST_SEND=true in the environment.",
    )
    args = parser.parse_args(argv)

    _load_env()

    base_url = (os.environ.get("TEXTBEE_BASE_URL") or DEFAULT_BASE_URL).strip().rstrip("/")
    api_key = (os.environ.get("TEXTBEE_API_KEY") or "").strip()
    device_id = (os.environ.get("TEXTBEE_DEVICE_ID") or "").strip() or None
    recipient_raw = (os.environ.get("TEXTBEE_TEST_RECIPIENT") or "").strip()
    test_send_env = _truthy(os.environ.get("SMS_TEST_SEND"))
    provider = (os.environ.get("SMS_PROVIDER") or "").strip() or "(unset)"

    print("TextBee SMS smoke")
    print(f"  mode={'SEND' if args.send and test_send_env else 'DRY-RUN'}")
    print(f"  baseUrl={base_url}")
    print(f"  SMS_PROVIDER={provider}")
    print(f"  TEXTBEE_API_KEY={_mask_secret(api_key)}")
    print(f"  TEXTBEE_DEVICE_ID={'set' if device_id else '(optional, unset)'}")
    print(f"  SMS_TEST_SEND={'true' if test_send_env else 'false'}")
    print(f"  --send={'yes' if args.send else 'no'}")
    print(f"  fixedMessage={FIXED_TEST_MESSAGE!r}")

    recipient_e164: str | None = None
    recipient_ok = False
    errors = 0

    if recipient_raw:
        try:
            recipient_e164 = normalize_ph_mobile(recipient_raw)
            recipient_ok = True
            print(f"  TEXTBEE_TEST_RECIPIENT={_mask_phone(recipient_e164)} (valid PH E.164)")
        except ValueError as exc:
            print(f"  FAIL TEXTBEE_TEST_RECIPIENT invalid: {exc}")
            errors += 1
    else:
        print("  TEXTBEE_TEST_RECIPIENT=(empty)")

    if not api_key:
        print("  FAIL TEXTBEE_API_KEY is missing. Add it to access_backend/.env (see .env.example).")
        errors += 1
        print("\nDry-run stopped: no API key. No SMS was sent.")
        return 1

    try:
        with httpx.Client(timeout=REQUEST_TIMEOUT_S) as client:
            status, devices = _list_devices(client, base_url, api_key)
            if status != 200:
                errors += 1
            elif device_id:
                ids = {str(d.get("_id") or "") for d in devices}
                if device_id not in ids:
                    print(
                        "  WARN TEXTBEE_DEVICE_ID not found in device list "
                        "(check dashboard / reconnect app)."
                    )
                else:
                    print("  OK  TEXTBEE_DEVICE_ID matches a listed device")

            want_send = bool(args.send and test_send_env)
            if args.send and not test_send_env:
                print(
                    "  BLOCKED --send ignored: set SMS_TEST_SEND=true in .env "
                    "(or the process env) to allow a real SMS."
                )
            if test_send_env and not args.send:
                print("  NOTE SMS_TEST_SEND=true but --send was not passed; staying in dry-run.")

            if want_send:
                if not recipient_ok or not recipient_e164:
                    print("  FAIL Cannot send: set a valid TEXTBEE_TEST_RECIPIENT (+639…).")
                    errors += 1
                elif errors:
                    print("  FAIL Skipping send because earlier checks failed.")
                else:
                    print(f"  Sending fixed test message to {_mask_phone(recipient_e164)} …")
                    send_rc = _send_test_sms(
                        client,
                        base_url=base_url,
                        api_key=api_key,
                        recipient=recipient_e164,
                        device_id=device_id,
                    )
                    if send_rc != 0:
                        errors += 1
            else:
                print(
                    "  OK  Dry-run complete. No SMS sent. "
                    "To send one test message after approval: "
                    "set TEXTBEE_TEST_RECIPIENT, SMS_TEST_SEND=true, then "
                    "python scripts/textbee_sms_smoke.py --send"
                )
    except httpx.TimeoutException:
        print("  FAIL Network timeout talking to TextBee")
        errors += 1
    except httpx.RequestError as exc:
        print(f"  FAIL Network error: {type(exc).__name__}")
        errors += 1

    if errors:
        print(f"\nResult: FAILED ({errors} issue(s)). No unexpected SMS should have been sent in dry-run.")
        return 1
    print("\nResult: OK (dry-run)" if not (args.send and test_send_env) else "\nResult: OK (send attempted)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
