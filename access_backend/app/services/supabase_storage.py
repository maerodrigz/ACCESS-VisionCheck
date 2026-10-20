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

_SIGNED_URL_TTL_SEC = 60 * 60 * 24 * 365  # 1 year for client-facing signed URLs (private buckets)
# One probe per bucket per process. True = public URL works. False = sign instead.
_bucket_is_public: dict[str, bool] = {}
# Compact DB value — signed Supabase URLs exceed media_files.file_url VARCHAR(500).
SUPABASE_STORAGE_REF_PREFIX = "supabase-ref:"


def supabase_storage_ref(bucket: str, object_path: str) -> str:
    bucket = (bucket or "").strip()
    path = (object_path or "").strip().lstrip("/")
    return f"{SUPABASE_STORAGE_REF_PREFIX}{bucket}/{path}"


def is_supabase_storage_ref(url: str | None) -> bool:
    return bool(url and url.strip().startswith(SUPABASE_STORAGE_REF_PREFIX))


def _parse_storage_ref(ref: str) -> tuple[str, str] | None:
    rest = ref.strip()[len(SUPABASE_STORAGE_REF_PREFIX) :]
    slash = rest.find("/")
    if slash <= 0:
        return None
    bucket = rest[:slash]
    object_path = rest[slash + 1 :]
    if not bucket or not object_path:
        return None
    return bucket, object_path


def _resolve_ref_with_client(ref: str, client: httpx.Client) -> str:
    """Turn a stored ref into a fetchable HTTPS URL using an existing client."""
    parsed = _parse_storage_ref(ref)
    if parsed is None or not is_supabase_storage_configured():
        return ref.strip()
    bucket, object_path = parsed
    try:
        return _public_or_signed_url(client, bucket, object_path)
    except Exception:
        logger.exception("Supabase ref resolve failed for %s", object_path)
        return ref.strip()


def _resolve_supabase_storage_ref(ref: str) -> str:
    """Turn a stored ref into a fetchable HTTPS URL (public or freshly signed)."""
    if not is_supabase_storage_ref(ref):
        return ref.strip()
    try:
        with httpx.Client(timeout=30.0) as client:
            return _resolve_ref_with_client(ref, client)
    except Exception:
        logger.exception("Supabase ref resolve failed")
        return ref.strip()


def _fix_legacy_object_path(url: str) -> str:
    if "supabase.co/object/" in url and "/storage/v1/object/" not in url:
        return url.replace(
            ".supabase.co/object/",
            ".supabase.co/storage/v1/object/",
            1,
        )
    return url


def _normalize_with_client(url: str | None, client: httpx.Client) -> str:
    if not url or not str(url).strip():
        return url or ""
    normalized = str(url).strip()
    if is_supabase_storage_ref(normalized):
        return _resolve_ref_with_client(normalized, client)
    return _fix_legacy_object_path(normalized)


def display_profile_image(url: str | None) -> str | None:
    """Return a URL an app can load. Stored values stay as compact supabase-ref."""
    if url is None:
        return None
    text = str(url).strip()
    if not text:
        return None
    resolved = normalize_supabase_storage_url(text)
    return resolved or text


def apply_display_profile_images(rows: list[dict], key: str = "profile_image") -> None:
    if not rows:
        return
    raw = [row.get(key) if isinstance(row.get(key), str) else None for row in rows]
    resolved = resolve_supabase_storage_urls(raw)
    for row, url in zip(rows, resolved):
        if url:
            row[key] = url


def resolve_supabase_storage_urls(urls: list[str | None]) -> list[str]:
    """Resolve many stored URLs on one connection. Same result as calling normalize per URL."""
    if not urls:
        return []
    needs_client = any(is_supabase_storage_ref(url) for url in urls if url and str(url).strip())
    if not needs_client or not is_supabase_storage_configured():
        return [normalize_supabase_storage_url(url) for url in urls]
    with httpx.Client(timeout=30.0) as client:
        return [_normalize_with_client(url, client) for url in urls]


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
            return supabase_storage_ref(bucket, object_path)
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
    if is_supabase_storage_ref(normalized):
        return _resolve_supabase_storage_ref(normalized)
    return _fix_legacy_object_path(normalized)


def _remember_bucket_access(bucket: str, status_code: int) -> None:
    if status_code == 200:
        _bucket_is_public[bucket] = True
    elif status_code in (400, 401, 403):
        _bucket_is_public[bucket] = False


def _sign_object_url(client: httpx.Client, bucket: str, object_path: str, public: str) -> str:
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
        return _fix_legacy_object_path(signed)
    return public


def _public_or_signed_url(client: httpx.Client, bucket: str, object_path: str) -> str:
    public = (
        f"{_base_url()}/storage/v1/object/public/{bucket}/{quote(object_path, safe='/')}"
    )
    known = _bucket_is_public.get(bucket)
    if known is True:
        return public
    if known is not False:
        try:
            probe = client.head(public, headers=_headers())
        except Exception:
            logger.warning("Supabase public URL probe failed for %s", object_path)
        else:
            _remember_bucket_access(bucket, probe.status_code)
            if probe.status_code == 200:
                return public
    return _sign_object_url(client, bucket, object_path, public)


def object_path_from_supabase_url(url: str) -> tuple[str, str] | None:
    """Return (bucket, object_path) when [url] points at Supabase Storage."""
    raw = (url or "").strip()
    if is_supabase_storage_ref(raw):
        rest = raw[len(SUPABASE_STORAGE_REF_PREFIX) :]
        slash = rest.find("/")
        if slash > 0:
            bucket = rest[:slash]
            obj = rest[slash + 1 :].split("?", 1)[0]
            if bucket and obj:
                return bucket, obj
        return None
    parsed = urlparse(raw)
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
