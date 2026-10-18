"""Load uploaded media bytes from local disk or remote URL."""

from __future__ import annotations

from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

from app.config import settings

_VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".avi", ".mkv", ".m4v", ".wmv"}


def is_video_file_name(file_name: str) -> bool:
    return Path(file_name or "").suffix.lower() in _VIDEO_EXTENSIONS


def local_media_path(file_url: str) -> Path | None:
    """Resolve a stored file_url to a path under UPLOAD_DIR when the file is on disk."""
    url = (file_url or "").strip()
    if not url:
        return None

    if url.startswith("http://") or url.startswith("https://"):
        from urllib.parse import urlparse

        try:
            parsed = urlparse(url)
        except ValueError:
            return None
        if parsed.path.startswith("/uploads/"):
            url = parsed.path
        else:
            return None

    rel = url.lstrip("/")
    if rel.startswith("uploads/"):
        rel = rel[len("uploads/") :]
    local = Path(settings.upload_dir) / rel
    return local if local.is_file() else None


def read_media_file_bytes(file_url: str, *, timeout: float = 12.0) -> bytes | None:
    """Read media bytes from `/uploads/...` paths or http(s) URLs."""
    from app.services.supabase_storage import normalize_supabase_storage_url

    url = normalize_supabase_storage_url((file_url or "").strip())
    if not url:
        return None

    if url.startswith("http://") or url.startswith("https://"):
        try:
            req = Request(url, headers={"User-Agent": "ACCESS-VisionCheck/1.0"})
            with urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except (URLError, OSError, ValueError):
            return None

    local = local_media_path(url)
    if local is not None:
        try:
            return local.read_bytes()
        except OSError:
            return None
    return None
