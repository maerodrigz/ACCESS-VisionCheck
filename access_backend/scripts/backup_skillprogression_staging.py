"""Backup access_skillprogression_staging before grandfather --apply."""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from dotenv import dotenv_values

BACKEND = Path(__file__).resolve().parents[1]
ENV_FILE = BACKEND / ".env.skillprogression_staging"
BACKUP_ROOT = BACKEND.parent / "access_mobile_staging_backups"
PG_DUMP = Path(r"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe")
PG_RESTORE = Path(r"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe")


def main() -> int:
    if not ENV_FILE.is_file():
        print("Missing .env.skillprogression_staging")
        return 1
    v = dotenv_values(ENV_FILE)
    db = v.get("DB_NAME", "")
    if db != "access_skillprogression_staging":
        print(f"Refusing backup for DB_NAME={db!r}")
        return 1

    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = BACKUP_ROOT / f"access_skillprogression_staging_{stamp}.dump"

    env = {**os.environ, "PGPASSWORD": v.get("DB_PASSWORD", "")}
    cmd = [
        str(PG_DUMP),
        "-h",
        v.get("DB_HOST", "localhost"),
        "-p",
        str(v.get("DB_PORT", "5432")),
        "-U",
        v.get("DB_USERNAME", ""),
        "-Fc",
        "-f",
        str(out),
        db,
    ]
    subprocess.run(cmd, env=env, check=True)
    if not out.is_file() or out.stat().st_size < 1024:
        print("Backup file missing or too small")
        return 1

    list_cmd = [str(PG_RESTORE), "--list", str(out)]
    subprocess.run(list_cmd, check=True, capture_output=True)
    print(f"backup_path={out}")
    print(f"backup_bytes={out.stat().st_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
