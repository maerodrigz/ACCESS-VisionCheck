"""Upload and delete media in Supabase Storage (optional — falls back to local /uploads)."""

from __future__ import annotations

import logging
import mimetypes
import uuid
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_SIGNED_URL_TTL_SEC = 60 * 60 * 24 * 365  # 1 year for stored file_url (private buckets)


def is_supabase_storage_configured() -> bool:
    if not (settings.supabase_storage_enabled or "").strip().lower() in ("1", "true", "yes"):
        return False
    if not (settings.supabase_url or "").strip():
        return False
    if not (settings.supabase_service_role_key or "").strip():
        return False
    if not (settings.supabase_storage_bucket or "").strip():
        return False
    return True


def supabase_max_upload_bytes() -> int:
    mb = int(settings.supabase_max_upload_mb or 50)
    return max(1, mb) * 1024 * 1024


def _base_url() -> str:
    return (settings.supabase_url or "").strip().rstrip("/")


def _headers() -> dict[str, str]:
    key = (settings.supabase_service_role_key or "").strip()
    return {
        "Authorization": f"Bearer {key}",
        "apikey": key,
    }


def _content_type(file_name: str) -> str:
    guessed, _ = mimetypes.guess_type(file_name)
    return guessed or "application/octet-stream"


def _object_name(*, folder: str, user_id: int | None, file_name: str) -> str:
    ext = Path(file_name or "").suffix.lower()
    uid = str(user_id) if user_id is not None else "anonymous"
    return f"access-visioncheck/{folder}/{uid}/{uuid.uuid4().hex}{ext}"


def upload_media_bytes(
    content: bytes,
    *,
    file_name: str,
    folder: str = "media",
    user_id: int | None = None,
) -> str | None:
    """Upload bytes and return a URL clients can GET (public URL or signed URL)."""
    if not content or not is_supabase_storage_configured():
        return None
    if len(content) > supabase_max_upload_bytes():
        logger.warning(
            "Supabase upload skipped: file exceeds SUPABASE_MAX_UPLOAD_MB (%s bytes)",
            len(content),
        )
        return None

    bucket = (settings.supabase_storage_bucket or "").strip()
    object_path = _object_name(folder=folder, user_id=user_id, file_name=file_name)
    upload_url = f"{_base_url()}/storage/v1/object/{bucket}/{quote(object_path, safe='/')}"
    headers = {
        **_headers(),
        "Content-Type": _content_type(file_name),
        "x-upsert": "true",
    }

    try:
        with httpx.Client(timeout=120.0) as client:
            resp = client.post(upload_url, content=content, headers=headers)
            if resp.status_code >= 400:
                logger.error(
                    "Supabase upload failed (%s): %s",
                    resp.status_code,
                    resp.text[:500],
                )
                return None
            return _public_or_signed_url(client, bucket, object_path)
    except Exception:
        logger.exception("Supabase Storage upload failed for %s", object_path)
        return None


def _ensure_storage_v1_path(path: str) -> str:
    """Supabase sign API may return `/object/sign/...` without the `/storage/v1` prefix."""
    if path.startswith("/object/") and not path.startswith("/storage/v1/object/"):
        return f"/storage/v1{path}"
    return path


def normalize_supabase_storage_url(url: str | None) -> str:
    """Fix stored or legacy URLs so mobile/web clients can GET the object."""
    if not url or not url.strip():
        return url or ""
    normalized = url.strip()
    if "supabase.co/object/" in normalized and "/storage/v1/object/" not in normalized:
        normalized = normalized.replace(
            ".supabase.co/object/",
            ".supabase.co/storage/v1/object/",
            1,
        )
    return normalized


def _public_or_signed_url(client: httpx.Client, bucket: str, object_path: str) -> str:
    public = (
        f"{_base_url()}/storage/v1/object/public/{bucket}/{quote(object_path, safe='/')}"
    )
    probe = client.head(public, headers=_headers())
    if probe.status_code == 200:
        return public

    sign_url = (
        f"{_base_url()}/storage/v1/object/sign/{bucket}/{quote(object_path, safe='/')}"
    )
    resp = client.post(
        sign_url,
        headers={**_headers(), "Content-Type": "application/json"},
        json={"expiresIn": _SIGNED_URL_TTL_SEC},
    )
    if resp.status_code >= 400:
        logger.warning("Supabase sign URL failed; storing public path anyway: %s", resp.text[:200])
        return public
    data = resp.json()
    signed = (data.get("signedURL") or data.get("signedUrl") or "").strip()
    if signed.startswith("/"):
        return f"{_base_url()}{_ensure_storage_v1_path(signed)}"
    if signed.startswith("http"):
        return normalize_supabase_storage_url(signed)
    return public


def object_path_from_supabase_url(url: str) -> tuple[str, str] | None:
    """Return (bucket, object_path) when [url] points at Supabase Storage."""
    parsed = urlparse(url.strip())
    base = urlparse(_base_url())
    if parsed.netloc and base.netloc and parsed.netloc != base.netloc:
        if "supabase.co" not in parsed.netloc:
            return None
    path = unquote(parsed.path or "")
    if path.startswith("/object/") and "/storage/v1/object/" not in path:
        path = _ensure_storage_v1_path(path)
    bucket = (settings.supabase_storage_bucket or "").strip()
    markers = (
        f"/storage/v1/object/public/{bucket}/",
        f"/storage/v1/object/sign/{bucket}/",
        f"/storage/v1/object/authenticated/{bucket}/",
        f"/storage/v1/object/{bucket}/",
        f"/object/public/{bucket}/",
        f"/object/sign/{bucket}/",
        f"/object/authenticated/{bucket}/",
        f"/object/{bucket}/",
    )
    for marker in markers:
        idx = path.find(marker)
        if idx >= 0:
            obj = path[idx + len(marker) :].split("?", 1)[0]
            if obj:
                return bucket, obj
    return None


def delete_supabase_url(url: str | None) -> bool:
    if not url or not is_supabase_storage_configured():
        return False
    parsed = object_path_from_supabase_url(url)
    if not parsed:
        return False
    bucket, object_path = parsed
    remove_url = f"{_base_url()}/storage/v1/object/{bucket}/remove"
    try:
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(
                remove_url,
                headers={**_headers(), "Content-Type": "application/json"},
                json={"prefixes": [object_path]},
            )
            if resp.status_code < 400:
                return True
            single = f"{_base_url()}/storage/v1/object/{bucket}/{quote(object_path, safe='/')}"
            resp2 = client.delete(single, headers=_headers())
            return resp2.status_code < 400
    except Exception:
        logger.exception("Supabase delete failed for %s", object_path)
        return False
