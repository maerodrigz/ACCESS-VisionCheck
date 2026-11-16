"""In-process SMS rate limits (per IP and per phone). Single-worker friendly."""

from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

_lock = threading.Lock()
_events: dict[str, deque[float]] = defaultdict(deque)


def _prune(bucket: deque[float], *, window_s: float, now: float) -> None:
    while bucket and (now - bucket[0]) > window_s:
        bucket.popleft()


def check_and_record(*, key: str, limit: int, window_s: float) -> None:
    """
    Record an event for key. Raise ValueError if over limit for the window.
    Call only when about to send (after other eligibility checks).
    """
    if limit <= 0:
        return
    now = time.monotonic()
    with _lock:
        bucket = _events[key]
        _prune(bucket, window_s=window_s, now=now)
        if len(bucket) >= limit:
            raise ValueError("Too many SMS requests. Please try again later.")
        bucket.append(now)


def reset_for_tests() -> None:
    with _lock:
        _events.clear()
