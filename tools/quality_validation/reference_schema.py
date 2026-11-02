"""Reference label CSV schema for external dataset ground truth (SPAQ, LIVE-VQC, etc.)."""

from __future__ import annotations

from typing import Final

# Canonical column order for reference_labels.csv exports.
REFERENCE_LABEL_COLUMNS: Final[tuple[str, ...]] = (
    "media_id",
    "dataset_split",
    "media_type",
    "source_dataset",
    "source_media_key",
    "label_provenance",
    "relative_path",
    "mos_quality_raw",
    "mos_scale",
    "attr_sharpness_raw",
    "attr_brightness_raw",
    "attr_noisiness_raw",
    "attr_contrast_raw",
    "attr_colorfulness_raw",
    "attribute_scale",
    "overall_documentation_mapped_1_5",
    "sharpness_blur_mapped_1_5",
    "exposure_mapped_1_5",
    "noise_quality_mapped_1_5",
    "contrast_quality_mapped_1_5",
    "color_balance_mapped_1_5",
    "missing_dimensions",
    "comparability_notes",
    "notes",
)

VALID_PROVENANCE: Final[frozenset[str]] = frozenset(
    {"human_subjective", "computed_indicator", "unknown"}
)

VALID_SPLITS: Final[frozenset[str]] = frozenset({"dev", "held_out"})

VALID_MEDIA_TYPES: Final[frozenset[str]] = frozenset({"photo", "video"})

# Dimensions that may be absent in a dataset; never impute with zero or neutral.
OPTIONAL_RAW_ATTRIBUTES: Final[tuple[str, ...]] = (
    "mos_quality_raw",
    "attr_sharpness_raw",
    "attr_brightness_raw",
    "attr_noisiness_raw",
    "attr_contrast_raw",
    "attr_colorfulness_raw",
)

MAPPED_1_5_COLUMNS: Final[tuple[str, ...]] = (
    "overall_documentation_mapped_1_5",
    "sharpness_blur_mapped_1_5",
    "exposure_mapped_1_5",
    "noise_quality_mapped_1_5",
    "contrast_quality_mapped_1_5",
    "color_balance_mapped_1_5",
)
