"""
Integration safety gate: pg_dump backup + list verify + test restore to disposable DB.

Does NOT modify the source database except creating/dropping a separate restore-test DB.
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

BACKEND_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND_ROOT / ".env")

PG_DUMP = Path(r"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe")
PG_RESTORE = Path(r"C:\Program Files\PostgreSQL\18\bin\pg_restore.exe")
PSQL = Path(r"C:\Program Files\PostgreSQL\18\bin\psql.exe")

SOURCE_DB = (os.environ.get("DB_NAME") or "postgres").strip()
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_USER = os.environ.get("DB_USERNAME", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

if os.environ.get("DATABASE_URL", "").strip():
    url = os.environ["DATABASE_URL"].strip()
    if "access_waverep_test" in url or "access_uat" in url:
        print("ERROR: DATABASE_URL must not point at QA/UAT for original backup")
        sys.exit(2)

if os.environ.get("ACCESS_PYTEST_DB", "").strip():
    print("ERROR: unset ACCESS_PYTEST_DB before original-system backup")
    sys.exit(2)

if SOURCE_DB in ("access_waverep_test", "access_uat"):
    print(f"ERROR: refuse backup gate with DB_NAME={SOURCE_DB!r}")
    sys.exit(2)


def _env() -> dict[str, str]:
    env = os.environ.copy()
    if DB_PASSWORD:
        env["PGPASSWORD"] = DB_PASSWORD
    return env


def _run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, env=_env(), capture_output=True, text=True, check=check)


def main() -> int:
    if not PG_DUMP.is_file() or not PG_RESTORE.is_file() or not PSQL.is_file():
        print("ERROR: PostgreSQL 18 client tools not found")
        return 1

    base_url = (
        f"postgresql+psycopg://{DB_USER}:***@{DB_HOST}:{DB_PORT}/{SOURCE_DB}"
    )
    print(f"source_db={SOURCE_DB}")
    print(f"connection={base_url}")

    engine = create_engine(
        f"postgresql+psycopg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{SOURCE_DB}",
        pool_pre_ping=True,
    )
    with engine.connect() as conn:
        live = conn.execute(text("SELECT current_database()")).scalar()
        if live != SOURCE_DB:
            print(f"ERROR: connected to {live!r}, expected {SOURCE_DB!r}")
            return 1

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_dir = BACKEND_ROOT / "backups" / "integration"
    backup_dir.mkdir(parents=True, exist_ok=True)
    dump_path = backup_dir / f"{SOURCE_DB}_pre_submission_chains_{ts}.dump"

    print(f"backup_file={dump_path}")
    dump_cmd = [
        str(PG_DUMP),
        "-h",
        DB_HOST,
        "-p",
        str(DB_PORT),
        "-U",
        DB_USER,
        "-Fc",
        "-f",
        str(dump_path),
        SOURCE_DB,
    ]
    proc = _run(dump_cmd)
    if proc.returncode != 0:
        print("ERROR: pg_dump failed")
        print(proc.stderr[-2000:] if proc.stderr else "")
        return 1
    size = dump_path.stat().st_size
    print(f"backup_size_bytes={size}")
    if size < 1024:
        print("ERROR: backup suspiciously small")
        return 1

    list_proc = _run([str(PG_RESTORE), "--list", str(dump_path)])
    if list_proc.returncode != 0:
        print("ERROR: pg_restore --list failed")
        print(list_proc.stderr[-2000:] if list_proc.stderr else "")
        return 1
    toc_lines = [ln for ln in (list_proc.stdout or "").splitlines() if ln.strip()]
    print(f"backup_toc_entries={len(toc_lines)}")

    restore_db = f"{SOURCE_DB}_restore_verify_{ts}"
    print(f"restore_test_db={restore_db}")

    create_sql = f'CREATE DATABASE "{restore_db}"'
    cp = _run([str(PSQL), "-h", DB_HOST, "-p", str(DB_PORT), "-U", DB_USER, "-d", "postgres", "-c", create_sql])
    if cp.returncode != 0:
        print("ERROR: CREATE DATABASE for restore test failed")
        print(cp.stderr[-2000:] if cp.stderr else "")
        return 1

    try:
        restore_cmd = [
            str(PG_RESTORE),
            "-h",
            DB_HOST,
            "-p",
            str(DB_PORT),
            "-U",
            DB_USER,
            "-d",
            restore_db,
            "--no-owner",
            "--no-acl",
            str(dump_path),
        ]
        rp = _run(restore_cmd, check=False)
        if rp.returncode != 0:
            # pg_restore often returns 1 for benign warnings; require core tables.
            err = (rp.stderr or "")[-3000:]
            if "FATAL" in err or "ERROR:" in err.split("WARNING:")[0]:
                print("ERROR: pg_restore to test DB failed")
                print(err)
                return 1
            print("restore_warnings=non_fatal_pg_restore_exit_code", rp.returncode)

        test_engine = create_engine(
            f"postgresql+psycopg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{restore_db}",
            pool_pre_ping=True,
        )
        with test_engine.connect() as conn:
            restored = conn.execute(text("SELECT current_database()")).scalar()
            users = conn.execute(text("SELECT COUNT(*) FROM users")).scalar()
            media = conn.execute(text("SELECT COUNT(*) FROM media_files")).scalar()
            me = conn.execute(
                text(
                    "SELECT COUNT(*) FROM media_files WHERE media_category = 'member_evaluation'"
                )
            ).scalar()
            evals = conn.execute(text("SELECT COUNT(*) FROM media_evaluations")).scalar()
            print(f"restore_verify_db={restored}")
            print(f"restore_users={users}")
            print(f"restore_media_files={media}")
            print(f"restore_member_evaluation_media={me}")
            print(f"restore_media_evaluations={evals}")
        test_engine.dispose()
    finally:
        drop_sql = f'DROP DATABASE IF EXISTS "{restore_db}" WITH (FORCE)'
        dp = _run([str(PSQL), "-h", DB_HOST, "-p", str(DB_PORT), "-U", DB_USER, "-d", "postgres", "-c", drop_sql], check=False)
        if dp.returncode != 0:
            print(f"WARN: could not drop restore test DB {restore_db}; drop manually")
        else:
            print(f"restore_test_db_dropped={restore_db}")

    print("backup_gate=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
