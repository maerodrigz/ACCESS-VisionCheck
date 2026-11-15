"""Authenticated presence heartbeat — does not touch evaluation/XP/Facebook."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import require_member_or_organization
from app.database import get_db
from app.models.user import User
from app.services.member_presence import presence_fields, utc_now

router = APIRouter(prefix="/presence", tags=["Presence"])


@router.post("/heartbeat")
def presence_heartbeat(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_organization),
):
    """
    Lightweight foreground heartbeat. Updates only the caller's last_seen_at (UTC).
    Clients should call ~every 60s while authenticated and foregrounded.
    """
    now = utc_now()
    current_user.last_seen_at = now
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    fields = presence_fields(
        is_active=bool(current_user.is_active),
        last_seen_at=current_user.last_seen_at,
        last_login_at=current_user.last_login_at,
        now=now,
    )
    return {
        "ok": True,
        "server_time": now.isoformat(),
        "last_seen_at": fields["last_seen_at"].isoformat() if fields["last_seen_at"] else None,
        "presence": fields["presence"],
    }
