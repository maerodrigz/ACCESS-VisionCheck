#!/usr/bin/env python
"""
ACCESS VisionCheck — project management CLI (Django-style).

Usage:
  python manage.py runserver
  python manage.py runserver --port 3001
  python manage.py create_tables
  python manage.py check
"""

from __future__ import annotations

import argparse
import sys

from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")


def cmd_runserver(args: argparse.Namespace) -> None:
    import uvicorn

    from app.config import settings

    host = args.host or settings.api_host
    port = args.port or settings.api_port
    reload = not args.no_reload

    from app.config import facebook_credentials

    public = settings.public_api_url
    _, fb_token = facebook_credentials()
    fb_ready = bool(fb_token)
    from app.services.dedicated_ai_detector import active_ai_detector_backend
    from app.services.probe_dino_detector import checkpoint_path, probe_detector_available

    backend = active_ai_detector_backend()
    print(f"Starting ACCESS VisionCheck API (bind {host}:{port})")
    print(f"  Public: {public}")
    print(f"  Facebook Graph API: {'ready' if fb_ready else 'token missing in .env'}")
    print(f"  AI detector backend: {backend}")
    print(f"  Media evaluation workers: {max(1, int(settings.max_media_evaluation_workers))}")
    if backend == "probe":
        print(f"  PROBE max long edge: {int(settings.probe_max_long_edge)}")
        print(
            f"  PROBE risk thresholds: {float(settings.probe_low_risk_threshold)} / "
            f"{float(settings.probe_high_risk_threshold)}"
        )
        ckpt = checkpoint_path()
        ckpt_state = "ready" if probe_detector_available() else "MISSING"
        print(f"  PROBE checkpoint: {ckpt_state} ({ckpt.name})")
    print(f"  Docs:   {public}/docs")
    print(f"  Health: {public}/api/health")
    print(f"  Local:  http://127.0.0.1:{port}/api/health")
    print("Press CTRL+C to stop.\n")

    uvicorn.run("main:app", host=host, port=port, reload=reload)


def cmd_create_tables(_: argparse.Namespace) -> None:
    from create_tables import main as create_tables_main

    create_tables_main()


def cmd_createuser(args: argparse.Namespace) -> None:
    from app.crud import user as user_crud
    from app.database import SessionLocal
    from app.models import Role, SkillLevel

    db = SessionLocal()
    try:
        if not db.query(Role).first():
            print("ERROR: Run `python manage.py create_tables` first (roles missing).")
            sys.exit(1)
        if user_crud.get_by_email(db, args.email):
            print(f"ERROR: Email already registered: {args.email}")
            sys.exit(1)
        status = "approved" if args.approved else None
        user = user_crud.create_user(
            db,
            args.name,
            args.email,
            args.password,
            args.role,
            status=status,
        )
        print("User created successfully.")
        print(f"  ID:     {user.id}")
        print(f"  Name:   {user.fullname}")
        print(f"  Email:  {user.email}")
        print(f"  Role:   {user.role.role_name}")
        print(f"  Status: {user.status}")
    finally:
        db.close()


def cmd_check(_: argparse.Namespace) -> None:
    from sqlalchemy import text

    from app.config import settings
    from app.database import engine

    print(f"Database URL: {settings.database_url.replace(settings.db_password, '****')}")
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("OK: PostgreSQL connection successful.")
    except Exception as exc:
        print(f"ERROR: Cannot connect to database.\n  {exc}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="ACCESS VisionCheck backend management",
        prog="manage.py",
    )
    sub = parser.add_subparsers(dest="command", help="Available commands")

    # python manage.py runserver
    run = sub.add_parser("runserver", help="Start the FastAPI development server")
    run.add_argument("--host", default=None, help="Bind host (default: API_HOST from .env)")
    run.add_argument("--port", type=int, default=None, help="Bind port (default: API_PORT from .env)")
    run.add_argument(
        "--no-reload",
        action="store_true",
        help="Disable auto-reload on file changes",
    )
    run.set_defaults(func=cmd_runserver)

    # python manage.py create_tables
    ct = sub.add_parser("create_tables", help="Create all database tables + seed admin")
    ct.set_defaults(func=cmd_create_tables)

    # python manage.py createuser --email ... --password ...
    cu = sub.add_parser("createuser", help="Add a user account to the database")
    cu.add_argument("--name", required=True, help="Full name")
    cu.add_argument("--email", required=True, help="Login email")
    cu.add_argument("--password", required=True, help="Login password")
    cu.add_argument(
        "--role",
        default="Member",
        choices=["Admin", "Member", "Organization"],
        help="Account role (default: Member)",
    )
    cu.add_argument(
        "--approved",
        action="store_true",
        help="Set status to approved (can log in immediately)",
    )
    cu.set_defaults(func=cmd_createuser)

    # python manage.py check
    chk = sub.add_parser("check", help="Test PostgreSQL connection")
    chk.set_defaults(func=cmd_check)

    def cmd_reset_data(args: argparse.Namespace) -> None:
        from scripts.reset_operational_data import main as reset_main

        sys.argv = ["reset_operational_data.py"]
        if args.dry_run:
            sys.argv.append("--dry-run")
        if args.confirm:
            sys.argv.append("--confirm")
        if args.keep_demo_users:
            sys.argv.append("--keep-demo-users")
        if args.skip_upload_dir:
            sys.argv.append("--skip-upload-dir")
        reset_main()

    reset = sub.add_parser(
        "reset_data",
        help="Remove media, requests, notifications; keep Admin + real registered emails",
    )
    reset.add_argument("--dry-run", action="store_true", help="Preview only (default)")
    reset.add_argument("--confirm", action="store_true", help="Apply reset (needs RESET_ACCESS_DATA=YES)")
    reset.add_argument("--keep-demo-users", action="store_true", help="Keep demo seed accounts")
    reset.add_argument("--skip-upload-dir", action="store_true", help="Do not delete uploads/ files")
    reset.set_defaults(func=cmd_reset_data)

    args = parser.parse_args()

    if not args.command:
        # Default to runserver when no command given (like many Django workflows)
        args = parser.parse_args(["runserver"])

    args.func(args)


if __name__ == "__main__":
    main()
