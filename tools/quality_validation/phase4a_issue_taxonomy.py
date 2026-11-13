"""Issue vocabulary for feedback validation (Phase 4A). Research-only."""

from __future__ import annotations

# Finite classes for precision / recall / F1. Humans tick present issues independently.
ISSUE_CLASSES = (
    "soft_focus",
    "bad_exposure",
    "low_contrast",
    "blocking",
    "color_cast",
    "bad_saturation",
)

# Map hybrid feedback rule criteria + issue bands → taxonomy class.
# no_issue / unavailable / suppressed_duplicate do not add a predicted issue.
RULE_CRITERION_TO_ISSUE = {
    "sharpness": "soft_focus",
    "blur": "soft_focus",  # normally suppressed; if ever emitted as issue, same class
    "brightness": "bad_exposure",
    "contrast": "low_contrast",
    "blocking_artifacts": "blocking",
    "color_balance": "color_cast",
    "color_saturation": "bad_saturation",
}

ISSUE_SEVERITIES_COUNTED = frozenset({"severe", "moderate", "mild"})
