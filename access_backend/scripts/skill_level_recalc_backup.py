"""Create a verified PostgreSQL backup before skill tier batch recalculation.

Does not modify application data except writing a dump file under backups/skill_recalc/.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from dotenv import load_dotenv

load_dotenv(_BACKEND / ".env")

from sqlalchemy import create_engine, text

from app.config import settings


def _find_pg_dump() -> Path | None:
    env = os.environ.get("PG_DUMP_PATH", "").strip()
    if env and Path(env).is_file():
        return Path(env)
    for base in (
        Path(r"C:\Program Files\PostgreSQL"),
        Path(r"C:\Program Files (x86)\PostgreSQL"),
    ):
        if base.is_dir():
            for exe in base.rglob("pg_dump.exe"):
                return exe
    found = shutil.which("pg_dump")
    return Path(found) if found else None


def main() -> int:
    pg_dump = _find_pg_dump()
    if not pg_dump or not pg_dump.is_file():
        print("ERROR: pg_dump not found. Set PG_DUMP_PATH or install PostgreSQL client tools.")
        return 1

    db_name = settings.db_name
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out_dir = _BACKEND / "backups" / "skill_recalc" / f"pre_recalc_{ts}"
    out_dir.mkdir(parents=True, exist_ok=True)
    dump_path = out_dir / f"{db_name}_pre_skill_recalc_{ts}.dump"

    engine = create_engine(settings.database_url, pool_pre_ping=True)
    with engine.connect() as conn:
        live = conn.execute(text("SELECT current_database()")).scalar()
        if live != db_name:
            print(f"ERROR: connected to {live!r}, expected {db_name!r}")
            return 1

    env = os.environ.copy()
    if settings.db_password:
        env["PGPASSWORD"] = settings.db_password

    cmd = [
        str(pg_dump),
        "-h",
        settings.db_host,
        "-p",
        str(settings.db_port),
        "-U",
        settings.db_username,
        "-Fc",
        "-f",
        str(dump_path),
        db_name,
    ]
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        print("ERROR: pg_dump failed")
        print(proc.stderr[-2000:] if proc.stderr else "")
        return 1

    pg_restore = pg_dump.with_name("pg_restore.exe")
    restore_list_ok = None
    if pg_restore.is_file():
        list_proc = subprocess.run(
            [str(pg_restore), "--list", str(dump_path)],
            capture_output=True,
            text=True,
        )
        restore_list_ok = list_proc.returncode == 0

    manifest = {
        "created_at_utc": ts,
        "database": db_name,
        "dump_path": str(dump_path),
        "size_bytes": dump_path.stat().st_size,
        "pg_dump": str(pg_dump),
        "restore_list_ok": restore_list_ok,
        "restore_hint": (
            f'pg_restore -h {settings.db_host} -p {settings.db_port} -U {settings.db_username} '
            f'-d <target_db> --clean --if-exists "{dump_path}"'
        ),
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"backup_ok=true")
    print(f"dump={dump_path}")
    print(f"manifest={manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
