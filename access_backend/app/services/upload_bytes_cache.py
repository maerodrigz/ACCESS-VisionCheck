"""Short-lived in-memory bytes for practice eval uploads (avoids re-download from Supabase)."""

from __future__ import annotations

import threading

_lock = threading.Lock()
_by_media_id: dict[int, bytes] = {}
_total_bytes = 0

# Skip caching very large clips; remote fetch still works in the pipeline.
_MAX_SINGLE_BYTES = 65 * 1024 * 1024
_MAX_TOTAL_BYTES = 96 * 1024 * 1024


def stash_evaluation_upload(media_id: int, content: bytes) -> None:
    """Keep upload bytes until the deferred pipeline worker consumes them."""
    if media_id <= 0 or not content:
        return
    size = len(content)
    if size > _MAX_SINGLE_BYTES:
        return
    global _total_bytes
    with _lock:
        old = _by_media_id.pop(media_id, None)
        if old is not None:
            _total_bytes -= len(old)
        while _by_media_id and _total_bytes + size > _MAX_TOTAL_BYTES:
            victim_id, victim = _by_media_id.popitem()
            _total_bytes -= len(victim)
        _by_media_id[media_id] = content
        _total_bytes += size


def take_evaluation_upload(media_id: int) -> bytes | None:
    """Pop cached bytes for this media id, if any."""
    global _total_bytes
    with _lock:
        data = _by_media_id.pop(media_id, None)
        if data is not None:
            _total_bytes -= len(data)
        return data
