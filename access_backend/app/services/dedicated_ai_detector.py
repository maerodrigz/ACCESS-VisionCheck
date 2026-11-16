"""Photo AI authenticity detector router (PROBE-DINOv2 only).

UnivFD (CLIP ViT-L/14) was permanently retired from ACCESS VisionCheck.
Production photos use PROBE; practice videos use WaveRep when enabled.

Public helpers keep historical names so callers (media pipeline, health, tests)
do not need a wide rename.
"""

from __future__ import annotations

import logging

logger = logging.getLogger("ACCESS.dedicated_ai_detector")


def _active_detector_backend() -> str:
    from app.config import settings

    backend = (settings.ai_detector_backend or "probe").strip().lower()
    if backend != "probe":
        # Settings validation should already reject non-probe; fail closed to probe.
        logger.warning(
            "dedicated_ai_detector: unexpected AI_DETECTOR_BACKEND=%r; using probe",
            backend,
        )
    return "probe"


def active_ai_detector_backend() -> str:
    """Public read-only backend id. Always ``probe`` after UnivFD retirement."""
    return _active_detector_backend()


def dedicated_detector_available() -> bool:
    """True when the configured backend (PROBE) can run inference."""
    from app.services.probe_dino_detector import probe_detector_available

    return probe_detector_available()


def dedicated_ai_probability(content: bytes) -> float | None:
    """Return P(AI-generated / fake) in [0, 1], or None if unavailable / invalid."""
    from app.services.probe_dino_detector import probe_ai_probability

    return probe_ai_probability(content)
