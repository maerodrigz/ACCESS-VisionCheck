"""Member presence helpers — heartbeat-based online status (UTC)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

# Online only when last heartbeat is within this window.
ONLINE_WINDOW = timedelta(minutes=2)
# No recorded authenticated activity for this long → inactive.
INACTIVE_AFTER = timedelta(days=30)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def activity_anchor(
    *,
    last_seen_at: datetime | None,
    last_login_at: datetime | None,
) -> datetime | None:
    """Most recent authenticated activity used for inactivity (not for online)."""
    seen = ensure_aware(last_seen_at)
    login = ensure_aware(last_login_at)
    if seen and login:
        return max(seen, login)
    return seen or login


def is_online(last_seen_at: datetime | None, *, now: datetime | None = None) -> bool:
    """True only when a recent heartbeat exists — never inferred from JWT/session rows."""
    seen = ensure_aware(last_seen_at)
    if seen is None:
        return False
    clock = ensure_aware(now) or utc_now()
    return seen >= clock - ONLINE_WINDOW


def is_inactive(
    *,
    last_seen_at: datetime | None,
    last_login_at: datetime | None,
    is_active: bool,
    now: datetime | None = None,
) -> bool:
    if not is_active:
        return False
    clock = ensure_aware(now) or utc_now()
    if is_online(last_seen_at, now=clock):
        return False
    anchor = activity_anchor(last_seen_at=last_seen_at, last_login_at=last_login_at)
    if anchor is None:
        return True
    return anchor < clock - INACTIVE_AFTER


def account_status_label(is_active: bool) -> str:
    return "Active" if is_active else "Disabled"


def presence_label(last_seen_at: datetime | None, *, now: datetime | None = None) -> str:
    return "Online" if is_online(last_seen_at, now=now) else "Offline"


def presence_fields(
    *,
    is_active: bool,
    last_seen_at: datetime | None,
    last_login_at: datetime | None,
    now: datetime | None = None,
) -> dict[str, Any]:
    clock = ensure_aware(now) or utc_now()
    online = is_online(last_seen_at, now=clock)
    inactive = is_inactive(
        last_seen_at=last_seen_at,
        last_login_at=last_login_at,
        is_active=is_active,
        now=clock,
    )
    return {
        "account_status": account_status_label(is_active),
        "presence": "Online" if online else "Offline",
        "is_online": online,
        "is_inactive": inactive,
        "last_seen_at": ensure_aware(last_seen_at),
        "last_login_at": ensure_aware(last_login_at),
        # Backward-compatible: last_active means last authenticated presence stamp.
        "last_active": ensure_aware(last_seen_at),
    }
