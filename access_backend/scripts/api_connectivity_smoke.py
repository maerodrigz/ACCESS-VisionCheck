#!/usr/bin/env python3
"""
Lightweight API connectivity smoke (no media upload).

Usage:
  cd access_backend
  python manage.py runserver --port 3001
  python scripts/api_connectivity_smoke.py

Optional env:
  SMOKE_API_BASE=http://127.0.0.1:3001/api
  SMOKE_ADMIN_EMAIL=admin@access.edu
  SMOKE_ADMIN_PASSWORD=admin123
  SMOKE_MEMBER_EMAIL=member@access.edu
  SMOKE_MEMBER_PASSWORD=member123
"""

from __future__ import annotations

import os
import sys

import httpx

API_BASE = os.environ.get("SMOKE_API_BASE", "http://127.0.0.1:3001/api").rstrip("/")
ADMIN_EMAIL = os.environ.get("SMOKE_ADMIN_EMAIL", "admin@access.edu")
ADMIN_PASSWORD = os.environ.get("SMOKE_ADMIN_PASSWORD", "admin123")
MEMBER_EMAIL = os.environ.get("SMOKE_MEMBER_EMAIL", "member@access.edu")
MEMBER_PASSWORD = os.environ.get("SMOKE_MEMBER_PASSWORD", "member123")
ORG_EMAIL = os.environ.get("SMOKE_ORG_EMAIL", "org@access.edu")
ORG_PASSWORD = os.environ.get("SMOKE_ORG_PASSWORD", "org123")


def ok(label: str) -> None:
    print(f"  OK  {label}")


def fail(label: str, detail: str) -> None:
    print(f"  FAIL {label}: {detail}", file=sys.stderr)


def main() -> int:
    print(f"API base: {API_BASE}")
    errors = 0

    with httpx.Client(timeout=30.0) as client:
        r = client.get(f"{API_BASE}/health")
        if r.status_code == 200:
            ok("GET /health")
        else:
            fail("GET /health", f"status {r.status_code}")
            errors += 1
            print("\nStart the backend: python manage.py runserver")
            return 1

        for role, email, password, paths in (
            (
                "admin",
                ADMIN_EMAIL,
                ADMIN_PASSWORD,
                (
                    "/admin/stats",
                    "/users",
                    "/admin/registrations/members?status=pending",
                    "/admin/registrations/organizations?status=pending",
                    "/admin/notifications",
                ),
            ),
            (
                "member",
                MEMBER_EMAIL,
                MEMBER_PASSWORD,
                (
                    "/member/profile",
                    "/evaluations?mine=true",
                    "/notifications",
                    "/rankings",
                ),
            ),
            (
                "requestor",
                ORG_EMAIL,
                ORG_PASSWORD,
                (
                    "/profile",
                    "/service-requests",
                    "/notifications",
                    "/events",
                ),
            ),
        ):
            lr = client.post(f"{API_BASE}/auth/login", json={"email": email, "password": password})
            if lr.status_code != 200:
                fail(f"login ({role})", f"status {lr.status_code} {lr.text[:200]}")
                errors += 1
                continue
            token = lr.json().get("token")
            if not token:
                fail(f"login ({role})", "missing token")
                errors += 1
                continue
            ok(f"POST /auth/login ({role})")
            headers = {"Authorization": f"Bearer {token}"}

            for path in paths:
                gr = client.get(f"{API_BASE}{path}", headers=headers)
                if gr.status_code == 200:
                    ok(f"GET {path} ({role})")
                else:
                    fail(f"GET {path} ({role})", f"status {gr.status_code}")
                    errors += 1

            lr_out = client.post(f"{API_BASE}/auth/logout", headers=headers)
            if lr_out.status_code == 200:
                ok(f"POST /auth/logout ({role})")
            else:
                fail(f"POST /auth/logout ({role})", f"status {lr_out.status_code}")
                errors += 1

        # Public registration OTP route (expect 422/400 without body, not 404)
        otp = client.post(f"{API_BASE}/auth/registration-otp/send", json={})
        if otp.status_code == 404:
            fail("POST /auth/registration-otp/send", "404 not registered")
            errors += 1
        else:
            ok("POST /auth/registration-otp/send (registered)")

    print()
    if errors:
        print(f"Finished with {errors} failure(s).")
        return 1
    print("All connectivity checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
