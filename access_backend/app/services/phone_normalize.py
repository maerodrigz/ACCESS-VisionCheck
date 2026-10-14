"""Normalize Philippine mobile numbers to E.164 (+63…)."""

import re

_PH_DIGITS = re.compile(r"\D+")


def normalize_ph_mobile(raw: str) -> str:
    """Return +639XXXXXXXXX or raise ValueError."""
    text = (raw or "").strip()
    if not text:
        raise ValueError("Phone number is required.")
    digits = _PH_DIGITS.sub("", text)
    if digits.startswith("63"):
        digits = digits[2:]
    elif digits.startswith("0"):
        digits = digits[1:]
    if not digits.startswith("9") or len(digits) != 10:
        raise ValueError("Enter a valid Philippine mobile number (09XX XXX XXXX).")
    return f"+63{digits}"
