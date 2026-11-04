"""Delete media blobs (Supabase, Firebase, local) with retries — no service role exposure."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from app.config import settings

logger = logging.getLogger(__name__)

REMOVED_STORAGE_PLACEHOLDER = "/uploads/__storage_removed__"


class StorageDeleteOutcome(str, Enum):
    DELETED = "deleted"
    NOT_APPLICABLE = "not_applicable"
    FAILED = "failed"


@dataclass(frozen=True)
class StorageDeleteResult:
    outcome: StorageDeleteOutcome
    error: str | None = None
    bucket: str | None = None
    object_path: str | None = None


def delete_storage_for_file_url(
    file_url: str | None,
    *,
    max_attempts: int = 3,
    retry_delay_sec: float = 0.35,
) -> StorageDeleteResult:
    """Best-effort blob removal; idempotent when object is already gone."""
    url = (file_url or "").strip()
    if not url or url == REMOVED_STORAGE_PLACEHOLDER:
        return StorageDeleteResult(outcome=StorageDeleteOutcome.NOT_APPLICABLE)

    from app.services.firebase_storage import delete_firebase_url
    from app.services.supabase_storage import (
        delete_supabase_url_with_retries,
        object_path_from_supabase_url,
    )

    parsed = object_path_from_supabase_url(url)
    if parsed is not None:
        bucket, object_path = parsed
        ok, err = delete_supabase_url_with_retries(
            url,
            max_attempts=max_attempts,
            retry_delay_sec=retry_delay_sec,
        )
        if ok:
            return StorageDeleteResult(
                outcome=StorageDeleteOutcome.DELETED,
                bucket=bucket,
                object_path=object_path,
            )
        return StorageDeleteResult(
            outcome=StorageDeleteOutcome.FAILED,
            error=err or "Supabase delete failed",
            bucket=bucket,
            object_path=object_path,
        )

    if delete_firebase_url(url):
        return StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)

    if url.startswith("http://") or url.startswith("https://"):
        return StorageDeleteResult(
            outcome=StorageDeleteOutcome.NOT_APPLICABLE,
            error="External URL; no server-side blob delete",
        )

    rel = url.lstrip("/")
    if rel.startswith("uploads/"):
        rel = rel[len("uploads/") :]
    local = Path(settings.upload_dir) / rel
    if local.is_file():
        for attempt in range(max_attempts):
            try:
                local.unlink(missing_ok=True)
                if not local.is_file():
                    return StorageDeleteResult(outcome=StorageDeleteOutcome.DELETED)
            except OSError as exc:
                logger.warning("local storage delete attempt %s failed: %s", attempt + 1, exc)
                if attempt + 1 < max_attempts:
                    time.sleep(retry_delay_sec)
        return StorageDeleteResult(outcome=StorageDeleteOutcome.FAILED, error="Local file delete failed")

    return StorageDeleteResult(outcome=StorageDeleteOutcome.NOT_APPLICABLE)
