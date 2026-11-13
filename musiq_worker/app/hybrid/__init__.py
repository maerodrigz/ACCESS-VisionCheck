"""Vendored Phase 1–3 hybrid classical + feedback logic (synced from access_backend).

Source of truth:
  access_backend/app/services/quality_shadow/{classical,feedback_rules,feedback_generator}.py
  access_backend/app/services/color_quality_criteria.py

Re-sync with: python scripts/sync_hybrid_logic.py
Do not invent alternate thresholds here.
"""

from app.hybrid.classical import (
    CLASSICAL_MAP_VERSION,
    classical_quality_from_bgr,
    color_criteria_from_bgr,
    decode_bgr_from_bytes,
)
from app.hybrid.feedback_generator import generate_hybrid_feedback

__all__ = [
    "CLASSICAL_MAP_VERSION",
    "classical_quality_from_bgr",
    "color_criteria_from_bgr",
    "decode_bgr_from_bytes",
    "generate_hybrid_feedback",
]
