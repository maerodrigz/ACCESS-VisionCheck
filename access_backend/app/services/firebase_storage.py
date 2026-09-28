"""Upload and delete media in Firebase Storage (optional — falls back to local /uploads)."""

from __future__ import annotations

import mimetypes
import uuid
from pathlib import Path
from urllib.parse import unquote, urlparse

from app.config import settings

_FIREBASE_APP = None


def is_firebase_storage_configured() -> bool:
    bucket = (settings.firebase_storage_bucket or "").strip()
    if not bucket:
        return False
    sa = (settings.firebase_service_account_json or "").strip()
    if sa and Path(sa).is_file():
        return True
    # Allow Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS).
    return bool((settings.firebase_storage_enabled or "").strip().lower() in ("1", "true", "yes"))


def _content_type(file_name: str) -> str:
    guessed, _ = mimetypes.guess_type(file_name)
    return guessed or "application/octet-stream"


def _ensure_firebase_app():
    global _FIREBASE_APP
    if _FIREBASE_APP is not None:
        return _FIREBASE_APP

    import firebase_admin
    from firebase_admin import credentials

    bucket = (settings.firebase_storage_bucket or "").strip()
    if not bucket:
        return None

    try:
        _FIREBASE_APP = firebase_admin.get_app()
        return _FIREBASE_APP
    except ValueError:
        pass

    sa_path = (settings.firebase_service_account_json or "").strip()
    if sa_path and Path(sa_path).is_file():
        cred = credentials.Certificate(sa_path)
    else:
        cred = credentials.ApplicationDefault()

    _FIREBASE_APP = firebase_admin.initialize_app(cred, {"storageBucket": bucket})
    return _FIREBASE_APP


def _download_url(bucket_name: str, object_name: str, token: str) -> str:
    from urllib.parse import quote

    encoded = quote(object_name, safe="")
    return (
        f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{encoded}"
        f"?alt=media&token={token}"
    )


def upload_media_bytes(
    content: bytes,
    *,
    file_name: str,
    folder: str = "media",
    user_id: int | None = None,
) -> str | None:
    """
    Upload bytes under access-visioncheck/{folder}/... and return a Firebase download URL.
    Returns None when Firebase is not configured or upload fails.
    """
    if not content or not is_firebase_storage_configured():
        return None

    try:
        from firebase_admin import storage
    except ImportError:
        return None

    if _ensure_firebase_app() is None:
        return None

    ext = Path(file_name or "").suffix.lower()
    uid = str(user_id) if user_id is not None else "anonymous"
    object_name = f"access-visioncheck/{folder}/{uid}/{uuid.uuid4().hex}{ext}"

    try:
        bucket = storage.bucket()
        blob = bucket.blob(object_name)
        token = str(uuid.uuid4())
        blob.metadata = {"firebaseStorageDownloadTokens": token}
        blob.upload_from_string(content, content_type=_content_type(file_name))
        return _download_url(bucket.name, object_name, token)
    except Exception:
        return None


def object_path_from_firebase_url(url: str) -> str | None:
    """Extract Storage object path from a Firebase download URL."""
    parsed = urlparse(url.strip())
    if "firebasestorage.googleapis.com" not in parsed.netloc:
        return None
    marker = "/o/"
    idx = parsed.path.find(marker)
    if idx < 0:
        return None
    encoded = parsed.path[idx + len(marker) :]
    if not encoded:
        return None
    return unquote(encoded)


def delete_firebase_url(url: str | None) -> bool:
    """Delete object when [url] is a Firebase Storage download URL."""
    if not url or not is_firebase_storage_configured():
        return False
    object_path = object_path_from_firebase_url(url)
    if not object_path:
        return False

    try:
        from firebase_admin import storage
    except ImportError:
        return False

    if _ensure_firebase_app() is None:
        return False

    try:
        bucket = storage.bucket()
        blob = bucket.blob(object_path)
        blob.delete()
        return True
    except Exception:
        return False
