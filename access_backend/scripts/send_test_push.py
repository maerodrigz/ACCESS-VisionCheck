"""Send a one-off FCM test to a member or requestor who has registered a push token.

Usage (from access_backend):
  python scripts/send_test_push.py --email member@access.edu
  python scripts/send_test_push.py --user-id 2 --title "Test" --message "Hello from ACCESS"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")

from sqlalchemy import select

from app.database import SessionLocal
from app.models.user import User
from app.crud import push_device_token as token_crud
from app.services.firebase_admin_app import ensure_firebase_admin_app, is_fcm_configured
from app.services.fcm_push import send_to_user


def main() -> int:
    parser = argparse.ArgumentParser(description="Send test FCM push to one user")
    parser.add_argument("--email", help="User email (member or requestor)")
    parser.add_argument("--user-id", type=int, help="User id")
    parser.add_argument("--title", default="ACCESS test push", help="Notification title")
    parser.add_argument("--message", default="If you see this, push notifications are working.", help="Body")
    args = parser.parse_args()

    if not args.email and not args.user_id:
        parser.error("Provide --email or --user-id")

    if not is_fcm_configured():
        print("FCM is not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON in .env.")
        return 1
    if ensure_firebase_admin_app() is None:
        print("Firebase Admin SDK failed to initialize. Check FIREBASE_SERVICE_ACCOUNT_JSON path.")
        return 1

    db = SessionLocal()
    try:
        if args.user_id:
            user = db.get(User, args.user_id)
        else:
            user = db.scalar(select(User).where(User.email == args.email.strip().lower()))
        if user is None:
            print("User not found.")
            return 1

        tokens = token_crud.list_tokens_for_user(db, user.id)
        if not tokens:
            print(
                f"No push tokens for user id={user.id} ({user.email}). "
                "Log in on the mobile app as member/requestor, allow notifications, then retry."
            )
            return 1

        print(f"Sending to user id={user.id} ({user.email}), {len(tokens)} device token(s)...")
        send_to_user(
            db,
            user.id,
            args.title,
            args.message,
            category="system_alert",
        )
        print("FCM send invoked. Check the phone (app in background for system tray).")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
