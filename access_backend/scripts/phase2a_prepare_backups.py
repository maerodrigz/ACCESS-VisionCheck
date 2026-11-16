#!/usr/bin/env python3
"""Phase 2A: backups + verification manifest (no deletions)."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import httpx
from sqlalchemy import create_engine, text

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()
from app.config import settings  # noqa: E402
from app.services.supabase_storage import (  # noqa: E402
    _base_url,
    _headers,
    is_supabase_storage_configured,
    normalize_supabase_storage_url,
    object_path_from_supabase_url,
)

ADMIN_ID = 1
EXCLUDE_MEDIA_IDS = {220}
TARGET_USER_IDS = (73, 74, 75, 76)
TIMESTAMP = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
BACKUP_ROOT = BACKEND / "backups" / f"phase2a_pre_cleanup_{TIMESTAMP}"


def _find_pg_dump() -> str | None:
    env = os.environ.get("PG_DUMP_PATH", "").strip()
    if env and Path(env).is_file():
        return env
    for base in (
        Path(r"C:\Program Files\PostgreSQL"),
        Path(r"C:\Program Files (x86)\PostgreSQL"),
    ):
        if not base.is_dir():
            continue
        for exe in base.rglob("pg_dump.exe"):
            return str(exe)
    found = shutil.which("pg_dump")
    return found


def _database_url_for_shell() -> str:
    url = (settings.database_url or "").strip()
    if url.startswith("postgresql+psycopg://"):
        return "postgresql://" + url.split("postgresql+psycopg://", 1)[1]
    if url.startswith("postgresql+psycopg2://"):
        return "postgresql://" + url.split("postgresql+psycopg2://", 1)[1]
    return url


def pg_backup_and_verify(manifest: dict) -> None:
    pg_dump = _find_pg_dump()
    db_dir = BACKUP_ROOT / "postgres"
    db_dir.mkdir(parents=True, exist_ok=True)
    dump_path = db_dir / f"access_full_{TIMESTAMP}.dump"
    manifest["postgres"] = {"dump_path": str(dump_path), "pg_dump": pg_dump}

    if not pg_dump:
        manifest["postgres"]["status"] = "skipped_no_pg_dump"
        manifest["postgres"]["note"] = (
            "Install PostgreSQL client tools or set PG_DUMP_PATH to pg_dump.exe"
        )
        return

    db_url = _database_url_for_shell()
    cmd = [pg_dump, "-Fc", "-f", str(dump_path), db_url]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        manifest["postgres"]["status"] = "failed"
        manifest["postgres"]["stderr"] = (proc.stderr or proc.stdout)[:2000]
        return

    manifest["postgres"]["size_bytes"] = dump_path.stat().st_size
    manifest["postgres"]["status"] = "created"

    pg_restore = Path(pg_dump).with_name("pg_restore.exe")
    if pg_restore.is_file():
        list_proc = subprocess.run(
            [str(pg_restore), "--list", str(dump_path)],
            capture_output=True,
            text=True,
        )
        manifest["postgres"]["restore_list_ok"] = list_proc.returncode == 0
        manifest["postgres"]["restore_list_entries"] = len(
            [ln for ln in (list_proc.stdout or "").splitlines() if ln.strip()]
        )
        if list_proc.returncode != 0:
            manifest["postgres"]["restore_list_stderr"] = list_proc.stderr[:500]
    else:
        manifest["postgres"]["restore_list_ok"] = None
        manifest["postgres"]["note_restore"] = "pg_restore.exe not found beside pg_dump"


def collect_target_storage_urls(conn) -> list[dict]:
    rows = conn.execute(
        text(
            """
            SELECT u.id AS user_id, u.email, 'profile_image' AS kind, NULL::int AS media_id,
                   u.profile_image AS file_url
            FROM users u
            WHERE u.id = ANY(:ids) AND u.profile_image IS NOT NULL AND u.profile_image != ''
            UNION ALL
            SELECT u.id, u.email, 'media_file', mf.id, mf.file_url
            FROM media_files mf
            JOIN users u ON u.id = mf.uploaded_by
            WHERE mf.uploaded_by = ANY(:ids)
              AND mf.id != ALL(:exclude_ids)
              AND mf.file_url IS NOT NULL
              AND mf.file_url != '/uploads/__storage_removed__'
            ORDER BY user_id, kind, media_id
            """
        ),
        {"ids": list(TARGET_USER_IDS), "exclude_ids": list(EXCLUDE_MEDIA_IDS)},
    ).fetchall()
    out = []
    for r in rows:
        out.append(
            {
                "user_id": r[0],
                "email": r[1],
                "kind": r[2],
                "media_id": r[3],
                "file_url": r[4],
            }
        )
    return out


def backup_supabase_objects(manifest: dict) -> None:
    sb_dir = BACKUP_ROOT / "supabase_objects"
    sb_dir.mkdir(parents=True, exist_ok=True)
    manifest["supabase"] = {"objects": [], "status": "skipped"}
    if not is_supabase_storage_configured():
        manifest["supabase"]["status"] = "not_configured"
        return

    engine = create_engine(settings.database_url)
    with engine.connect() as conn:
        refs = collect_target_storage_urls(conn)

    seen: set[tuple[str, str]] = set()
    manifest["supabase"]["status"] = "in_progress"
    ok = 0
    fail = 0
    total_bytes = 0

    with httpx.Client(timeout=120.0) as client:
        for row in refs:
            parsed = object_path_from_supabase_url(row["file_url"])
            if not parsed:
                manifest["supabase"]["objects"].append(
                    {**row, "status": "skipped_non_supabase_url"}
                )
                continue
            bucket, obj_path = parsed
            key = (bucket, obj_path)
            if key in seen:
                manifest["supabase"]["objects"].append(
                    {**row, "status": "duplicate_ref", "object_path": obj_path}
                )
                continue
            seen.add(key)

            safe_name = obj_path.replace("/", "__")
            dest = sb_dir / f"{row['user_id']}_{safe_name}"
            download_url = normalize_supabase_storage_url(row["file_url"])
            entry = {
                **row,
                "bucket": bucket,
                "object_path": obj_path,
                "download_url_prefix": download_url[:80],
                "local_path": str(dest),
            }
            try:
                resp = client.get(download_url, follow_redirects=True)
                if resp.status_code >= 400:
                    entry["status"] = "download_failed"
                    entry["http_status"] = resp.status_code
                    fail += 1
                else:
                    data = resp.content
                    dest.write_bytes(data)
                    sha = hashlib.sha256(data).hexdigest()
                    entry["status"] = "ok"
                    entry["size_bytes"] = len(data)
                    entry["sha256"] = sha
                    total_bytes += len(data)
                    ok += 1
            except Exception as exc:
                entry["status"] = "error"
                entry["error"] = str(exc)[:200]
                fail += 1
            manifest["supabase"]["objects"].append(entry)

    manifest["supabase"]["summary"] = {
        "unique_objects": len(seen),
        "download_ok": ok,
        "download_fail": fail,
        "total_bytes": total_bytes,
        "total_mb": round(total_bytes / (1024 * 1024), 2),
    }
    manifest["supabase"]["status"] = "complete" if fail == 0 else "complete_with_errors"

    checksums_csv = sb_dir / "checksums.csv"
    with checksums_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "user_id",
                "email",
                "kind",
                "media_id",
                "object_path",
                "size_bytes",
                "sha256",
                "status",
            ]
        )
        for o in manifest["supabase"]["objects"]:
            w.writerow(
                [
                    o.get("user_id"),
                    o.get("email"),
                    o.get("kind"),
                    o.get("media_id"),
                    o.get("object_path"),
                    o.get("size_bytes"),
                    o.get("sha256"),
                    o.get("status"),
                ]
            )
    manifest["supabase"]["checksums_csv"] = str(checksums_csv)


def backup_waverep_evidence(manifest: dict) -> None:
    ev_dir = BACKEND / "evaluation_results"
    dest = BACKUP_ROOT / "waverep_evidence_secure"
    dest.mkdir(parents=True, exist_ok=True)
    patterns = (
        "infinix_vid_run",
        "step8b",
        "step8c",
        "integration_3004",
        "flutter_mobile_3004",
        "admin_web_ui_3004",
        "cleanup_dry_run",
    )
    copied: list[str] = []
    if ev_dir.is_dir():
        for path in ev_dir.rglob("*"):
            if not path.is_file():
                continue
            name = path.name.lower()
            if any(p in name for p in patterns) or "waverep" in name.lower():
                rel = path.relative_to(ev_dir)
                target = dest / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
                copied.append(str(rel))
    zip_path = BACKUP_ROOT / f"waverep_evidence_{TIMESTAMP}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in dest.rglob("*"):
            if f.is_file():
                zf.write(f, arcname=f.relative_to(dest))
    manifest["waverep_evidence"] = {
        "copied_files": len(copied),
        "folder": str(dest),
        "zip": str(zip_path),
        "zip_size_bytes": zip_path.stat().st_size if zip_path.is_file() else 0,
    }


def supabase_usage_probe(manifest: dict) -> None:
    manifest["supabase_usage_probe"] = {}
    if not is_supabase_storage_configured():
        manifest["supabase_usage_probe"]["status"] = "not_configured"
        return
    bucket = (settings.supabase_storage_bucket or "").strip()
    base = _base_url()
    with httpx.Client(timeout=30.0) as client:
        # Storage API has no project quota in standard REST; probe bucket list + sample info.
        list_url = f"{base}/storage/v1/object/list/{bucket}"
        r = client.post(
            list_url,
            headers={**_headers(), "Content-Type": "application/json"},
            json={"prefix": "access-visioncheck/", "limit": 1000, "offset": 0},
        )
        manifest["supabase_usage_probe"]["list_root_status"] = r.status_code
        manifest["supabase_usage_probe"]["list_root_count"] = (
            len(r.json()) if r.status_code < 400 and isinstance(r.json(), list) else None
        )
    manifest["supabase_usage_probe"]["note"] = (
        "Project storage quota is visible in Supabase Dashboard > Settings > Usage. "
        "API list is non-recursive; use DB-backed size estimate for deletion preview."
    )


def build_allowlist(manifest: dict) -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        users = [
            dict(r._mapping)
            for r in c.execute(
                text(
                    """
                    SELECT u.id, u.email, r.role_name
                    FROM users u JOIN roles r ON r.id = u.role_id
                    WHERE u.id = ANY(:ids)
                    ORDER BY u.id
                    """
                ),
                {"ids": list(TARGET_USER_IDS)},
            )
        ]
    manifest["deletion_allowlist"] = {
        "users_to_delete_after_approval": users,
        "exclude_user_ids": [ADMIN_ID],
        "exclude_media_ids": sorted(EXCLUDE_MEDIA_IDS),
        "preserve_admin_media_ids": [238, 239, 240, 241, 242],
        "org75_note": (
            "All media linked to org requests 44-46 is uploaded_by Admin (id=1). "
            "Deleting user 75 removes requests/assignments; Admin media rows should "
            "remain (request_id may SET NULL per FK)."
        ),
    }


def enrich_allowlist_counts(manifest: dict) -> None:
    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        inv = subprocess.run(
            [sys.executable, str(BACKEND / "scripts" / "_readonly_cleanup_inventory.py")],
            cwd=str(BACKEND),
            capture_output=True,
            text=True,
        )
        if inv.returncode == 0 and inv.stdout.strip():
            try:
                manifest["live_inventory_recheck"] = json.loads(inv.stdout)
            except json.JSONDecodeError:
                manifest["live_inventory_recheck"] = {"raw": inv.stdout[:5000]}

        media_ids = [
            r[0]
            for r in c.execute(
                text(
                    """
                    SELECT id FROM media_files
                    WHERE uploaded_by = ANY(:ids)
                      AND id != ALL(:exclude)
                    ORDER BY id
                    """
                ),
                {"ids": list(TARGET_USER_IDS), "exclude": list(EXCLUDE_MEDIA_IDS)},
            )
        ]
        manifest["deletion_allowlist"]["media_file_ids_to_delete"] = media_ids
        manifest["deletion_allowlist"]["media_file_count"] = len(media_ids)

        sb = manifest.get("supabase", {}).get("summary", {})
        manifest["deletion_allowlist"]["expected_reclaim"] = {
            "supabase_backup_bytes": sb.get("total_bytes"),
            "supabase_backup_mb": sb.get("total_mb"),
            "note": (
                "Reclaim matches verified backup size when all downloads succeeded; "
                "dry-run estimate ~364 MB if unchanged since Phase 1."
            ),
        }


def main() -> None:
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    manifest: dict = {
        "phase": "2A",
        "created_at_utc": TIMESTAMP,
        "backup_root": str(BACKUP_ROOT),
        "target_user_ids": list(TARGET_USER_IDS),
        "admin_preserved_id": ADMIN_ID,
    }
    build_allowlist(manifest)
    pg_backup_and_verify(manifest)
    backup_supabase_objects(manifest)
    backup_waverep_evidence(manifest)
    supabase_usage_probe(manifest)

    est_proc = subprocess.run(
        [sys.executable, str(BACKEND / "scripts" / "_readonly_supabase_size_estimate.py")],
        cwd=str(BACKEND),
        capture_output=True,
        text=True,
    )
    manifest["storage_size_estimate_script"] = (est_proc.stdout or est_proc.stderr).strip()
    enrich_allowlist_counts(manifest)

    manifest_path = BACKUP_ROOT / "phase2a_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, default=str), encoding="utf-8")
    print(json.dumps(manifest, indent=2, default=str))


if __name__ == "__main__":
    main()
