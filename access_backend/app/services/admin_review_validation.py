"""Shared admin review request validation."""

from __future__ import annotations

from fastapi import HTTPException


def validate_admin_review_update(
    *,
    review_status: str | None,
    admin_remarks: str | None,
) -> None:
    if review_status not in ("reupload_requested", "confirmed_ai_generated"):
        return
    text = (admin_remarks or "").strip()
    if len(text) < 8:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "admin_remarks_required",
                "message": "Admin reason required (at least 8 characters) for this decision.",
            },
        )
