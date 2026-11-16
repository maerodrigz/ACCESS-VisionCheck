"""Staging-only: verify DB, synthetic member auth, profile/participation. No secrets in stdout."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))
STAGING_ENV = BACKEND / ".env.skillprogression_staging"
os.environ["ACCESS_ENV_FILE"] = str(STAGING_ENV)

from app.env_bootstrap import bootstrap_environment

bootstrap_environment(STAGING_ENV)

from sqlalchemy import text

from app.config import settings
from app.core.security import verify_password
from app.crud import user as user_crud
from app.database import SessionLocal

LAN_BASE = "http://192.168.8.99:3011/api"
CANDIDATES = [
    "member@access.edu",
    "carlos.m@student.ustp.edu.ph",
]


def _post(path: str, body: dict) -> tuple[int, dict | str]:
    req = urllib.request.Request(
        f"{LAN_BASE}{path}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, raw


def _get(path: str, token: str) -> tuple[int, dict]:
    req = urllib.request.Request(
        f"{LAN_BASE}{path}",
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.status, json.loads(resp.read().decode())


def main() -> int:
    db = SessionLocal()
    try:
        row = db.execute(
            text("select current_database(), current_user"),
        ).one()
        print("db", row[0], "db_user", row[1])
        print("api_port", settings.api_port, "api_host", settings.api_host)
        print("skill_progression_active_policy", settings.skill_progression_active_policy)

        approved = db.execute(
            text(
                "select u.email, u.status, u.is_active, r.role_name "
                "from users u join roles r on r.id = u.role_id "
                "where lower(r.role_name) = 'member' and lower(u.status) = 'approved' "
                "order by u.id"
            ),
        ).fetchall()
        print("approved_member_count", len(approved))
        for em, st, active, role in approved[:6]:
            print("member", em, "status", st, "is_active", active)

        test_email = None
        smoke_password = os.environ.get("STAGING_SMOKE_PASSWORD", "member123")
        for email in CANDIDATES:
            user = user_crud.get_by_email(db, email)
            if not user:
                print("missing", email)
                continue
            ok = verify_password(smoke_password, user.password)
            auth = user_crud.authenticate(db, email, smoke_password)
            print(
                "credential_check",
                email,
                "verify_password",
                ok,
                "authenticate",
                auth is not None,
                "is_active",
                user.is_active,
            )
            if auth is not None and user.is_active:
                test_email = email
                break

        if not test_email:
            print("FAIL: no candidate accepted smoke password; staging reset required")
            return 1
    finally:
        db.close()

    status, login_body = _post(
        "/auth/login",
        {"email": test_email, "password": smoke_password},
    )
    token = None
    if isinstance(login_body, dict):
        token = login_body.get("token") or login_body.get("access_token")
    print("http_login", test_email, "status", status, "token_present", bool(token))
    if not token:
        print("login_body_keys", list(login_body.keys()) if isinstance(login_body, dict) else type(login_body))
        return 1

    ps, profile = _get("/member/profile", token)
    print("profile_status", ps, "email", profile.get("email"))
    tier = profile.get("skill_level") or profile.get("competency_level")
    print("profile_effective_tier_field", tier)

    ps2, part = _get("/member/participation", token)
    print(
        "participation_status",
        ps2,
        "policy_version",
        part.get("skill_progression_policy_version"),
        "policy_configured",
        part.get("skill_progression_policy_configured"),
    )
    print("selected_test_account", test_email)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
