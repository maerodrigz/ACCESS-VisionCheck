#!/usr/bin/env python3
"""Preflight checks before system test week. No secrets printed."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import httpx

_env_file = os.environ.get("ACCESS_ENV_FILE", ".env.waverep_test")
_env_path = ROOT / _env_file
if _env_path.is_file():
    try:
        from dotenv import load_dotenv

        load_dotenv(_env_path, override=True)
    except ImportError:
        pass

from app.config import settings
from app.services.email_delivery import is_email_configured
from app.services.supabase_storage import is_supabase_storage_configured


def main() -> int:
    print("ACCESS VisionCheck — system test preflight\n")
    issues = 0

    api_base = os.environ.get("SMOKE_API_BASE", f"http://127.0.0.1:{settings.api_port}/api")
    print(f"API base: {api_base}")
    print(f"Email configured: {is_email_configured()}")
    print(
        f"Email OTP limits (min/resend/attempts): "
        f"{settings.email_otp_expire_minutes}/{settings.email_otp_resend_seconds}/{settings.email_otp_max_attempts}"
    )
    print(f"Evaluation max video (sec): {settings.evaluation_max_video_seconds}")
    print(f"Supabase storage: {'on' if is_supabase_storage_configured() else 'off (local uploads/)'}")
    print()

    try:
        r = httpx.get(f"{api_base}/health", timeout=10.0)
        if r.status_code == 200:
            print("OK  Backend health")
        else:
            print(f"FAIL Backend health status {r.status_code}", file=sys.stderr)
            issues += 1
    except Exception as exc:
        print(f"FAIL Backend not reachable: {exc}", file=sys.stderr)
        issues += 1
        print("\nStart: cd access_backend && python manage.py runserver")
        return 1

    if not is_email_configured():
        print(
            "NOTE Email off: registration/reset OTP uses dev_code in API + backend console (no real email)."
        )

    print("\nNext: python scripts/api_connectivity_smoke.py")
    print("Checklist: docs/SYSTEM_TEST_CHECKLIST.md")
    return issues


if __name__ == "__main__":
    raise SystemExit(main())
