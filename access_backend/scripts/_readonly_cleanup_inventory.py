"""Read-only inventory for Supabase cleanup dry run. No deletes."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from sqlalchemy import create_engine, text

BACKEND = Path(__file__).resolve().parent.parent
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from app.config import settings  # noqa: E402
from app.services.supabase_storage import (  # noqa: E402
    is_supabase_storage_configured,
    is_supabase_storage_ref,
)


def main() -> None:
    url = settings.database_url
    if not url:
        print(json.dumps({"error": "DATABASE_URL not configured"}))
        return

    engine = create_engine(url)
    out: dict = {}

    with engine.connect() as c:
        admins = c.execute(
            text(
                """
                SELECT u.id, u.email, u.fullname FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE r.role_name = :admin
                """
            ),
            {"admin": "Admin"},
        ).fetchall()
        out["admin_accounts"] = [
            {"id": r[0], "email": r[1], "name": r[2]} for r in admins
        ]
        non_admin = c.execute(
            text(
                """
                SELECT u.id, u.email, u.fullname, r.role_name, u.status, u.is_active,
                       (u.removed_at IS NOT NULL) AS soft_removed
                FROM users u JOIN roles r ON r.id = u.role_id
                WHERE r.role_name != :admin
                ORDER BY u.id
                """
            ),
            {"admin": "Admin"},
        ).fetchall()
        out["non_admin_account_count"] = len(non_admin)
        out["non_admin_by_role"] = {}
        for row in non_admin:
            role = row[3]
            out["non_admin_by_role"][role] = out["non_admin_by_role"].get(role, 0) + 1
        out["non_admin_sample"] = [
            {
                "id": r[0],
                "email": r[1],
                "role": r[3],
                "status": r[4],
                "active": r[5],
                "soft_removed": r[6],
            }
            for r in non_admin[:15]
        ]

        admin_ids = [a["id"] for a in out["admin_accounts"]] or [-1]
        na_ids = [r[0] for r in non_admin]

        m = c.execute(
            text(
                """
                SELECT
                  COUNT(*) AS total,
                  COUNT(*) FILTER (WHERE uploaded_by = ANY(:admin_ids)) AS admin_uploaded,
                  COUNT(*) FILTER (WHERE uploaded_by IS NULL) AS orphan_uploaded,
                  COUNT(*) FILTER (
                    WHERE uploaded_by IS NOT NULL AND NOT (uploaded_by = ANY(:admin_ids))
                  ) AS non_admin_uploaded,
                  COUNT(*) FILTER (WHERE file_url LIKE :ref) AS supabase_ref_rows,
                  COUNT(*) FILTER (
                    WHERE file_url LIKE :ref
                      AND uploaded_by IS NOT NULL
                      AND NOT (uploaded_by = ANY(:admin_ids))
                  ) AS non_admin_supabase_ref,
                  COUNT(*) FILTER (WHERE file_url LIKE :uploads) AS local_upload_rows,
                  COUNT(*) FILTER (
                    WHERE file_url LIKE :uploads
                      AND uploaded_by IS NOT NULL
                      AND NOT (uploaded_by = ANY(:admin_ids))
                  ) AS non_admin_local,
                  COUNT(*) FILTER (WHERE file_url LIKE 'http%') AS http_url_rows,
                  COUNT(*) FILTER (WHERE file_url = :removed) AS storage_removed_placeholder,
                  COUNT(*) FILTER (WHERE storage_removed_at IS NOT NULL) AS storage_removed_flag
                FROM media_files
                """
            ),
            {
                "admin_ids": admin_ids,
                "ref": "supabase-ref:%",
                "uploads": "/uploads/%",
                "removed": "/uploads/__storage_removed__",
            },
        ).one()
        out["media_files"] = dict(m._mapping)

        if na_ids:
            counts_sql = [
                (
                    "non_admin_media_evaluations",
                    "SELECT COUNT(*) FROM media_evaluations me "
                    "JOIN media_files mf ON mf.id = me.media_id "
                    "WHERE mf.uploaded_by = ANY(:ids)",
                ),
                (
                    "non_admin_ai_detection",
                    "SELECT COUNT(*) FROM ai_detection_results ad "
                    "JOIN media_files mf ON mf.id = ad.media_id "
                    "WHERE mf.uploaded_by = ANY(:ids)",
                ),
                (
                    "non_admin_ai_review_history",
                    "SELECT COUNT(*) FROM ai_review_history ar "
                    "JOIN media_files mf ON mf.id = ar.media_id "
                    "WHERE mf.uploaded_by = ANY(:ids)",
                ),
                ("notifications", "SELECT COUNT(*) FROM notifications WHERE user_id = ANY(:ids)"),
                ("login_history", "SELECT COUNT(*) FROM login_history WHERE user_id = ANY(:ids)"),
                ("user_sessions", "SELECT COUNT(*) FROM user_sessions WHERE user_id = ANY(:ids)"),
                (
                    "push_device_tokens",
                    "SELECT COUNT(*) FROM push_device_tokens WHERE user_id = ANY(:ids)",
                ),
                ("member_rankings", "SELECT COUNT(*) FROM member_rankings WHERE user_id = ANY(:ids)"),
                (
                    "documentation_requests",
                    "SELECT COUNT(*) FROM documentation_requests WHERE requestor_id = ANY(:ids)",
                ),
                (
                    "request_assignments_as_member",
                    "SELECT COUNT(*) FROM request_assignments WHERE member_id = ANY(:ids)",
                ),
                ("feedbacks", "SELECT COUNT(*) FROM feedbacks WHERE user_id = ANY(:ids)"),
                (
                    "member_milestones",
                    "SELECT COUNT(*) FROM member_milestones WHERE user_id = ANY(:ids)",
                ),
                (
                    "registration_email_otps",
                    "SELECT COUNT(*) FROM registration_email_otps WHERE email IN "
                    "(SELECT email FROM users WHERE id = ANY(:ids))",
                ),
                (
                    "password_reset_email_otps",
                    "SELECT COUNT(*) FROM password_reset_email_otps WHERE email IN "
                    "(SELECT email FROM users WHERE id = ANY(:ids))",
                ),
                (
                    "assignment_member_feedbacks",
                    "SELECT COUNT(*) FROM assignment_member_feedbacks "
                    "WHERE member_id = ANY(:ids) OR requestor_id = ANY(:ids)",
                ),
                ("audit_logs", "SELECT COUNT(*) FROM audit_logs WHERE user_id = ANY(:ids)"),
            ]
            for key, sql in counts_sql:
                try:
                    out[key] = c.execute(text(sql), {"ids": na_ids}).scalar()
                except Exception as exc:
                    c.rollback()
                    out[key] = f"table_unavailable: {exc.__class__.__name__}"

        out["system_branding_rows"] = c.execute(
            text("SELECT COUNT(*) FROM system_branding")
        ).scalar()
        out["system_settings_rows"] = c.execute(
            text("SELECT COUNT(*) FROM system_settings")
        ).scalar()
        out["analytics_reports"] = c.execute(
            text("SELECT COUNT(*) FROM analytics_reports")
        ).scalar()

        # Ambiguous ownership
        out["orphan_media_ids_sample"] = [
            r[0]
            for r in c.execute(
                text(
                    "SELECT id FROM media_files WHERE uploaded_by IS NULL ORDER BY id LIMIT 10"
                )
            ).fetchall()
        ]

        # Local disk reclaim estimate (non-admin /uploads/ only)
        upload_root = Path(settings.upload_dir)
        local_bytes = 0
        local_count = 0
        missing = 0
        rows = c.execute(
            text(
                """
                SELECT id, file_url FROM media_files
                WHERE uploaded_by IS NOT NULL AND NOT (uploaded_by = ANY(:admin_ids))
                  AND file_url LIKE '/uploads/%' AND file_url != :removed
                """
            ),
            {"admin_ids": admin_ids, "removed": "/uploads/__storage_removed__"},
        ).fetchall()
        for _mid, file_url in rows:
            rel = file_url.strip().lstrip("/")
            if rel.startswith("uploads/"):
                rel = rel[len("uploads/") :]
            p = upload_root / rel
            if p.is_file():
                local_bytes += p.stat().st_size
                local_count += 1
            else:
                missing += 1
        out["non_admin_local_files_on_disk"] = local_count
        out["non_admin_local_files_missing_on_disk"] = missing
        out["non_admin_local_reclaimable_mb"] = round(local_bytes / (1024 * 1024), 2)

        # Profile images (non-admin) pointing at storage
        prof_rows = c.execute(
            text(
                """
                SELECT profile_image FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE r.role_name != :admin AND profile_image IS NOT NULL
                  AND profile_image != ''
                """
            ),
            {"admin": "Admin"},
        ).fetchall()
        out["non_admin_profile_images"] = len(prof_rows)
        out["non_admin_profile_supabase_refs"] = sum(
            1 for (u,) in prof_rows if is_supabase_storage_ref(u)
        )

    out["supabase_storage_enabled"] = is_supabase_storage_configured()
    out["supabase_max_upload_mb"] = settings.supabase_max_upload_mb
    out["upload_dir"] = str(Path(settings.upload_dir).resolve())

    # Supabase list (read-only) for prefix access-visioncheck/media/
    sb_objects = 0
    sb_bytes = 0
    sb_non_admin_prefix_estimate = 0
    if is_supabase_storage_configured() and na_ids:
        import httpx

        from app.services.supabase_storage import _base_url, _headers

        bucket = (settings.supabase_storage_bucket or "").strip()
        prefix = "access-visioncheck/media/"
        list_url = f"{_base_url()}/storage/v1/object/list/{bucket}"
        try:
            with httpx.Client(timeout=60.0) as client:
                offset = 0
                limit = 1000
                while True:
                    resp = client.post(
                        list_url,
                        headers={**_headers(), "Content-Type": "application/json"},
                        json={"prefix": prefix, "limit": limit, "offset": offset},
                    )
                    if resp.status_code >= 400:
                        out["supabase_list_error"] = {
                            "status": resp.status_code,
                            "body": resp.text[:300],
                        }
                        break
                    batch = resp.json()
                    if not batch:
                        break
                    for obj in batch:
                        if not isinstance(obj, dict):
                            continue
                        name = (obj.get("name") or "").strip()
                        if not name:
                            continue
                        sb_objects += 1
                        meta = obj.get("metadata") or {}
                        size = meta.get("size") or obj.get("size") or 0
                        try:
                            sb_bytes += int(size)
                        except (TypeError, ValueError):
                            pass
                        # path: access-visioncheck/media/{userId}/...
                        parts = name.split("/")
                        if len(parts) >= 3:
                            try:
                                uid = int(parts[2])
                                if uid in na_ids:
                                    sb_non_admin_prefix_estimate += 1
                            except ValueError:
                                pass
                    if len(batch) < limit:
                        break
                    offset += limit
        except Exception as exc:
            out["supabase_list_error"] = str(exc)
    out["supabase_objects_under_media_prefix"] = sb_objects
    out["supabase_bytes_listed_metadata_mb"] = round(sb_bytes / (1024 * 1024), 2)
    out["supabase_objects_likely_non_admin_by_path"] = sb_non_admin_prefix_estimate
    out["supabase_db_ref_non_admin_rows"] = out.get("media_files", {}).get(
        "non_admin_supabase_ref", 0
    )

    print(json.dumps(out, indent=2, default=str))


if __name__ == "__main__":
    main()
