"""SHA-256 hashing for member evaluation duplicate detection."""

from __future__ import annotations

import hashlib

# Shown to members on HTTP 409 when bytes match a prior evaluation upload.
EVALUATION_DUPLICATE_UPLOAD_MESSAGE = (
    "This photo or video has already been submitted for evaluation. "
    "Please upload a different file."
)

MEMBER_EVAL_FILE_HASH_INDEX = "uq_media_files_member_eval_file_hash"


def sha256_hex(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()
