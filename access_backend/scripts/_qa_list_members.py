"""List QA members on access_waverep_test only (no passwords)."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv(Path(__file__).resolve().parents[1] / ".env.waverep_test")
url = (os.environ.get("DATABASE_URL") or "").strip()
if "access_waverep_test" not in url:
    raise SystemExit("Refusing: DATABASE_URL must be access_waverep_test")

engine = create_engine(url, pool_pre_ping=True)
with engine.connect() as conn:
    db = conn.execute(text("SELECT current_database()")).scalar()
    print(f"database={db}")
    members = conn.execute(
        text(
            """
            SELECT u.id, u.email, u.status, u.fullname
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE r.role_name = 'Member'
            ORDER BY u.id DESC
            LIMIT 50
            """
        )
    ).fetchall()
    print(f"members_listed={len(members)}")
    for row in members:
        print(f"  id={row[0]} status={row[2]} email={row[1]} name={row[3]!r}")

    phase4 = conn.execute(
        text(
            """
            SELECT email, status, id FROM users
            WHERE email LIKE 'phase4.%@waverep.example.com'
            ORDER BY id DESC LIMIT 20
            """
        )
    ).fetchall()
    print(f"phase4_temp_accounts={len(phase4)}")
    for row in phase4:
        print(f"  id={row[2]} status={row[1]} email={row[0]}")

    waverep = conn.execute(
        text(
            """
            SELECT u.id, u.email, u.status FROM users u
            WHERE u.email IN (
              'waverep.member@example.com',
              'member@access.edu'
            )
            """
        )
    ).fetchall()
    print("seed_members:")
    for row in waverep:
        print(f"  id={row[0]} status={row[2]} email={row[1]}")

    reupload = conn.execute(
        text(
            """
            SELECT COUNT(*) FROM ai_detection_results
            WHERE review_status = 'reupload_requested'
            """
        )
    ).scalar()
    print(f"reupload_requested_ai_rows={reupload}")

    awaiting = conn.execute(
        text(
            """
            SELECT sc.id, sc.awaiting_replacement_media_id, m.file_name, u.email
            FROM submission_chains sc
            JOIN media_files m ON m.id = sc.awaiting_replacement_media_id
            JOIN users u ON u.id = m.uploaded_by
            WHERE sc.awaiting_replacement_media_id IS NOT NULL
            ORDER BY sc.id DESC LIMIT 10
            """
        )
    ).fetchall()
    print(f"chains_awaiting_replacement={len(awaiting)}")
    for row in awaiting:
        print(
            f"  chain={row[0]} media={row[1]} file={row[2]!r} owner={row[3]}"
        )

engine.dispose()
