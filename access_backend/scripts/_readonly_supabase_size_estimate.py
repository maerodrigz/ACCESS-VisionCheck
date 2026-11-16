"""Read-only: sum Supabase object sizes referenced in media_files + profile_image."""

from __future__ import annotations

import sys
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
    is_supabase_storage_ref,
    object_path_from_supabase_url,
)


def collect_paths(conn) -> set[tuple[str, str]]:
    paths: set[tuple[str, str]] = set()
    urls = list(
        conn.execute(
            text(
                """
                SELECT file_url FROM media_files
                WHERE file_url LIKE 'supabase-ref:%'
                   OR file_url LIKE 'https://%.supabase.co%'
                UNION ALL
                SELECT profile_image FROM users
                WHERE profile_image IS NOT NULL AND profile_image != ''
                  AND (profile_image LIKE 'supabase-ref:%'
                       OR profile_image LIKE 'https://%.supabase.co%')
                """
            )
        ).scalars()
    )
    for url in urls:
        if not url:
            continue
        parsed = object_path_from_supabase_url(url)
        if parsed:
            paths.add(parsed)
    return paths


def main() -> None:
    if not is_supabase_storage_configured():
        print("supabase_not_configured")
        return
    engine = create_engine(settings.database_url)
    with engine.connect() as conn:
        paths = collect_paths(conn)
    bucket_default = (settings.supabase_storage_bucket or "").strip()
    admin_paths: list[tuple[str, str]] = []
    non_admin_paths: list[tuple[str, str]] = []
    unknown_paths: list[tuple[str, str]] = []

    with engine.connect() as conn:
        admin_ids = set(
            conn.execute(
                text(
                    """
                    SELECT u.id FROM users u
                    JOIN roles r ON r.id = u.role_id
                    WHERE r.role_name = 'Admin'
                    """
                )
            ).scalars()
        )
        for bucket, obj in paths:
            # access-visioncheck/media/{userId}/...
            parts = obj.split("/")
            uid = None
            if len(parts) >= 3 and parts[0] == "access-visioncheck" and parts[1] == "media":
                try:
                    uid = int(parts[2])
                except ValueError:
                    uid = None
            if uid in admin_ids:
                admin_paths.append((bucket, obj))
            elif uid is not None:
                non_admin_paths.append((bucket, obj))
            else:
                unknown_paths.append((bucket, obj))

    def measure(items: list[tuple[str, str]]) -> tuple[int, int, int]:
        bytes_total = 0
        ok = 0
        fail = 0
        with httpx.Client(timeout=30.0) as client:
            for bucket, obj in items:
                b = bucket or bucket_default
                info_url = f"{_base_url()}/storage/v1/object/info/{b}/{obj}"
                r = client.get(info_url, headers=_headers())
                if r.status_code >= 400:
                    fail += 1
                    continue
                ok += 1
                try:
                    data = r.json()
                    size = data.get("metadata", {}).get("size") or data.get("size") or 0
                    bytes_total += int(size)
                except (TypeError, ValueError):
                    pass
        return ok, fail, bytes_total

    na_ok, na_fail, na_bytes = measure(non_admin_paths)
    ad_ok, ad_fail, ad_bytes = measure(admin_paths)
    un_ok, un_fail, un_bytes = measure(unknown_paths)

    print(
        {
            "unique_objects_total": len(paths),
            "non_admin_objects": len(non_admin_paths),
            "admin_objects": len(admin_paths),
            "unknown_path_objects": len(unknown_paths),
            "non_admin_size_mb": round(na_bytes / (1024 * 1024), 2),
            "admin_size_mb": round(ad_bytes / (1024 * 1024), 2),
            "unknown_size_mb": round(un_bytes / (1024 * 1024), 2),
            "non_admin_metadata_ok_fail": (na_ok, na_fail),
            "admin_metadata_ok_fail": (ad_ok, ad_fail),
        }
    )


if __name__ == "__main__":
    main()
