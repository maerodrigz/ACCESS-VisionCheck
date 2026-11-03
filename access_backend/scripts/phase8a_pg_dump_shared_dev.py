"""Phase 8A: pg_dump postgres on localhost (no restore, no credentials in stdout)."""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
OUTPUT_DIR = BACKEND.parent / "access_mobile_staging_backups"

sys.path.insert(0, str(BACKEND))
if "ACCESS_ENV_FILE" in os.environ:
    del os.environ["ACCESS_ENV_FILE"]

from app.env_bootstrap import bootstrap_environment

bootstrap_environment(BACKEND / ".env")

from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal


def main() -> int:
    db = SessionLocal()
    try:
        row = db.execute(
            text("SELECT current_database(), current_user, inet_server_port()"),
        ).one()
        if str(row[0]) != "postgres" or int(row[2] or 0) != 5432:
            print("FAIL: identity check before dump")
            return 1
    finally:
        db.close()

    if settings.db_name != "postgres":
        print("FAIL: settings.db_name != postgres")
        return 1

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out = OUTPUT_DIR / f"phase8a_postgres_shared_dev_{ts}.dump"

    env = os.environ.copy()
    if settings.db_password:
        env["PGPASSWORD"] = settings.db_password

    pg_dump = os.environ.get("PG_DUMP_PATH", "pg_dump")
    if pg_dump == "pg_dump":
        for candidate in (
            Path(r"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"),
            Path(r"C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"),
            Path(r"C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"),
        ):
            if candidate.is_file():
                pg_dump = str(candidate)
                break
    pg_restore = str(Path(pg_dump).with_name("pg_restore.exe"))

    cmd = [
        pg_dump,
        "-h",
        settings.db_host or "localhost",
        "-p",
        str(settings.db_port),
        "-U",
        settings.db_username,
        "-Fc",
        "-f",
        str(out),
        "postgres",
    ]
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        print("FAIL: pg_dump exit", proc.returncode)
        if proc.stderr:
            # Strip connection strings that might echo host only
            err = proc.stderr.replace(settings.db_password, "***") if settings.db_password else proc.stderr
            print(err[:500])
        return 1

    if not out.is_file() or out.stat().st_size < 1024:
        print("FAIL: backup missing or too small")
        return 1

    list_proc = subprocess.run(
        [pg_restore, "--list", str(out)],
        capture_output=True,
        text=True,
    )
    if list_proc.returncode != 0:
        print("FAIL: pg_restore --list")
        return 1

    lines = len(list_proc.stdout.splitlines())
    print("backup_path", out)
    print("backup_bytes", out.stat().st_size)
    print("pg_restore_list_lines", lines)
    print("verify_ok", True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
