"""Authenticated media stream responses with real HTTP Range support.

Video players (ExoPlayer / AVPlayer) require 206 + Content-Range for seeking.
A plain ``Response(content=bytes)`` that only sets Accept-Ranges lies to the
client and causes play/pause/seek failures. Prefer FileResponse (disk) or a
temp-file FileResponse for buffered remote blobs.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from starlette.background import BackgroundTask
from starlette.responses import FileResponse


def _unlink_quiet(path: str) -> None:
    try:
        Path(path).unlink(missing_ok=True)
    except OSError:
        pass


def file_response_from_bytes(
    content: bytes,
    *,
    media_type: str,
    filename: str | None = None,
    cache_control: str = "private, max-age=120",
    suffix: str = ".bin",
) -> FileResponse:
    """Serve in-memory bytes via a temp file so Starlette can honor Range requests."""
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    try:
        tmp.write(content)
        tmp.flush()
    finally:
        tmp.close()
    return FileResponse(
        tmp.name,
        media_type=media_type,
        filename=filename,
        headers={"Cache-Control": cache_control},
        background=BackgroundTask(_unlink_quiet, tmp.name),
    )


def stream_suffix_for_content_type(content_type: str, file_name: str | None = None) -> str:
    name = (file_name or "").strip()
    if "." in name:
        return "." + name.rsplit(".", 1)[-1].lower()
    ct = (content_type or "").lower()
    if ct.startswith("video/"):
        return ".mp4"
    if ct.startswith("image/"):
        return ".jpg"
    return ".bin"
