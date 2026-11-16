"""
Create UAT test accounts in the isolated access_uat database (idempotent).

Passwords are written to .env.uat.accounts.local (gitignored). Never commit that file.

Usage:
  cd access_backend
  set ACCESS_ENV_FILE=.env.uat.local
  python manage.py create_tables
  python scripts/seed_uat_accounts.py
"""

from __future__ import annotations

import os
import secrets
import string
from pathlib import Path

from dotenv import load_dotenv

BACKEND = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND / os.environ.get("ACCESS_ENV_FILE", ".env.uat.local"))

import sys

sys.path.insert(0, str(BACKEND))

from app.database import SessionLocal
from create_tables import seed_roles, seed_skill_levels, _seed_user

ACCOUNTS_FILE = BACKEND / ".env.uat.accounts.local"

UAT_ACCOUNTS = [
    ("UAT_ADMIN_EMAIL", "UAT_ADMIN_PASSWORD", "uat-admin@access-uat.example.com", "UAT Admin", "Admin", "Master"),
    ("UAT_MEMBER1_EMAIL", "UAT_MEMBER1_PASSWORD", "uat-member1@access-uat.example.com", "UAT Member One", "Member", "Beginner"),
    ("UAT_MEMBER2_EMAIL", "UAT_MEMBER2_PASSWORD", "uat-member2@access-uat.example.com", "UAT Member Two", "Member", "Intermediate"),
    (
        "UAT_REQUESTOR_EMAIL",
        "UAT_REQUESTOR_PASSWORD",
        "uat-requestor@access-uat.example.com",
        "UAT Partner Organization",
        "Organization",
        None,
    ),
]


def _random_password(length: int = 16) -> str:
    alphabet = string.ascii_letters + string.digits + "-_"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main() -> None:
    db_name = os.environ.get("DATABASE_URL", "")
    if "access_uat" not in db_name:
        print("ERROR: DATABASE_URL must point to access_uat for UAT seeding.")
        print(f"  Current: {db_name[:80]}...")
        sys.exit(1)

    db = SessionLocal()
    try:
        role_ids = seed_roles(db)
        skill_ids = seed_skill_levels(db)
        lines: list[str] = [
            "# UAT credentials (gitignored). Distribute via secure channel to testers only.",
            f"# Database: access_uat",
            "",
        ]
        created = 0
        for env_email, env_pass, email, fullname, role_key, skill_key in UAT_ACCOUNTS:
            skill_id = skill_ids[skill_key] if skill_key else None
            password = _random_password()
            if _seed_user(
                db,
                email=email,
                fullname=fullname,
                password=password,
                role_id=role_ids[role_key],
                skill_level_id=skill_id,
                status="approved",
            ):
                created += 1
            lines.append(f"{env_email}={email}")
            lines.append(f"{env_pass}={password}")
            lines.append("")

        ACCOUNTS_FILE.write_text("\n".join(lines), encoding="utf-8")
        print(f"UAT accounts ready ({created} newly created). Credentials: {ACCOUNTS_FILE.name}")
        print("Emails (safe to share):", ", ".join(a[2] for a in UAT_ACCOUNTS))
    finally:
        db.close()


if __name__ == "__main__":
    main()
