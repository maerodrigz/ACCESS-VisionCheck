"""
Production-safe database initialization guards for ACCESS VisionCheck.

Used by create_tables.py, manage.py bootstrap_admin, and seed_sample_data.py.
Never prints passwords. Does not connect to the database.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Mapping, MutableMapping

# Local-development defaults only (never used when APP_ENV is production).
DEV_ADMIN_EMAIL = "admin@access.edu"
DEV_ADMIN_PASSWORD = "admin123"
DEV_ADMIN_FULLNAME = "Admin User"

BOOTSTRAP_ADMIN_EMAIL_ENV = "BOOTSTRAP_ADMIN_EMAIL"
BOOTSTRAP_ADMIN_PASSWORD_ENV = "BOOTSTRAP_ADMIN_PASSWORD"
BOOTSTRAP_ADMIN_NAME_ENV = "BOOTSTRAP_ADMIN_NAME"

# Known insecure seed credentials — refused for production bootstrap.
_FORBIDDEN_PRODUCTION_ADMIN_PASSWORDS = frozenset(
    {
        DEV_ADMIN_PASSWORD.lower(),
        "password",
        "password123",
        "admin",
        "123456",
        "changeme",
    }
)


class ProductionDbInitError(RuntimeError):
    """Raised when a production database init rule would be violated."""


@dataclass(frozen=True)
class BootstrapAdminCredentials:
    email: str
    fullname: str
    password: str
    source: str  # "development_default" | "environment" | "cli"


def _env(environ: Mapping[str, str] | None) -> Mapping[str, str]:
    return environ if environ is not None else os.environ


def env_flag_true(name: str, environ: Mapping[str, str] | None = None) -> bool:
    value = _env(environ).get(name, "")
    return value.strip().lower() in ("1", "true", "yes")


def recreate_db_requested(environ: Mapping[str, str] | None = None) -> bool:
    return env_flag_true("RECREATE_DB", environ)


def assert_recreate_db_allowed(
    *,
    is_production: bool,
    environ: Mapping[str, str] | None = None,
) -> None:
    """
    Refuse RECREATE_DB in production before any DROP SCHEMA / destructive SQL.
    Safe to call when RECREATE_DB is unset (no-op).
    """
    if not recreate_db_requested(environ):
        return
    if is_production:
        raise ProductionDbInitError(
            "RECREATE_DB=true is not allowed when APP_ENV is production. "
            "Refusing to drop or recreate the database schema."
        )


def seed_demo_data_enabled(
    *,
    is_production: bool,
    environ: Mapping[str, str] | None = None,
) -> bool:
    """Demo / sample seeding is always off in production, even if SEED_DEMO_DATA=true."""
    if is_production:
        return False
    return env_flag_true("SEED_DEMO_DATA", environ)


def assert_sample_seed_allowed(*, is_production: bool) -> None:
    if is_production:
        raise ProductionDbInitError(
            "Sample / demo data seeding is not allowed when APP_ENV is production."
        )


def assert_reset_data_allowed(*, is_production: bool) -> None:
    if is_production:
        raise ProductionDbInitError(
            "reset_data is not allowed when APP_ENV is production."
        )


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _is_forbidden_production_password(password: str) -> bool:
    return password.strip().lower() in _FORBIDDEN_PRODUCTION_ADMIN_PASSWORDS


def resolve_bootstrap_admin(
    *,
    is_production: bool,
    environ: Mapping[str, str] | None = None,
    cli_email: str | None = None,
    cli_password: str | None = None,
    cli_fullname: str | None = None,
) -> BootstrapAdminCredentials | None:
    """
    Resolve administrator credentials for first-time bootstrap.

    - Development/testing: BOOTSTRAP_* or CLI overrides; otherwise hardcoded local admin.
    - Production: only explicit BOOTSTRAP_* env and/or CLI credentials. Never hardcoded
      admin@access.edu / admin123. Returns None if credentials were not supplied
      (caller should skip seeding and tell the operator to run bootstrap_admin).
    """
    env = _env(environ)
    email = (cli_email or env.get(BOOTSTRAP_ADMIN_EMAIL_ENV) or "").strip()
    password = (cli_password or env.get(BOOTSTRAP_ADMIN_PASSWORD_ENV) or "").strip()
    fullname = (cli_fullname or env.get(BOOTSTRAP_ADMIN_NAME_ENV) or "").strip()

    has_explicit = bool(email) or bool(password) or bool(cli_email) or bool(cli_password)

    if is_production:
        if not email or not password:
            if has_explicit:
                raise ProductionDbInitError(
                    "Production admin bootstrap requires both "
                    f"{BOOTSTRAP_ADMIN_EMAIL_ENV} and {BOOTSTRAP_ADMIN_PASSWORD_ENV} "
                    "(or --email and --password). Passwords are never printed."
                )
            return None
        email_n = _normalize_email(email)
        if email_n == DEV_ADMIN_EMAIL and _is_forbidden_production_password(password):
            raise ProductionDbInitError(
                "Refusing production admin bootstrap with known development credentials "
                f"({DEV_ADMIN_EMAIL} with a default/dev password)."
            )
        if _is_forbidden_production_password(password):
            raise ProductionDbInitError(
                "Refusing production admin bootstrap with a weak or default password."
            )
        if len(password) < 12:
            raise ProductionDbInitError(
                "Production admin bootstrap password must be at least 12 characters."
            )
        return BootstrapAdminCredentials(
            email=email_n,
            fullname=fullname or "Administrator",
            password=password,
            source="cli" if (cli_email or cli_password) else "environment",
        )

    # Non-production: explicit credentials win; otherwise keep local defaults.
    if email and password:
        return BootstrapAdminCredentials(
            email=_normalize_email(email),
            fullname=fullname or "Administrator",
            password=password,
            source="cli" if (cli_email or cli_password) else "environment",
        )
    if email or password:
        raise ProductionDbInitError(
            f"Both {BOOTSTRAP_ADMIN_EMAIL_ENV} and {BOOTSTRAP_ADMIN_PASSWORD_ENV} "
            "must be set together (or pass both --email and --password)."
        )
    return BootstrapAdminCredentials(
        email=DEV_ADMIN_EMAIL,
        fullname=fullname or DEV_ADMIN_FULLNAME,
        password=DEV_ADMIN_PASSWORD,
        source="development_default",
    )


def clear_bootstrap_password_from_environ(
    environ: MutableMapping[str, str] | None = None,
) -> None:
    """Best-effort scrub after bootstrap so child processes do not inherit the secret."""
    target: MutableMapping[str, str] = environ if environ is not None else os.environ
    target.pop(BOOTSTRAP_ADMIN_PASSWORD_ENV, None)
