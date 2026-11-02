"""Reference-to-machine comparison specs with comparability classification."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Comparability = Literal["directly_comparable", "related_proxy", "not_comparable"]


@dataclass(frozen=True)
class ReferenceComparisonSpec:
    """One reference mapped column compared to ACCESS machine criterion(s)."""

    key: str
    reference_mapped_column: str
    machine_criterion_names: tuple[str, ...]  # empty = no machine rubric
    machine_aggregate: str  # "mean" | "single" | "overall"
    comparability: Comparability
    direction_note: str
    applies_to_media_type: str  # "photo" | "video" | "any"


REFERENCE_COMPARISON_SPECS: tuple[ReferenceComparisonSpec, ...] = (
    ReferenceComparisonSpec(
        key="overall_documentation",
        reference_mapped_column="overall_documentation_mapped_1_5",
        machine_criterion_names=(),
        machine_aggregate="overall",
        comparability="directly_comparable",
        direction_note="Higher MOS and higher machine overall_score both indicate better quality.",
        applies_to_media_type="any",
    ),
    ReferenceComparisonSpec(
        key="sharpness_blur",
        reference_mapped_column="sharpness_blur_mapped_1_5",
        machine_criterion_names=("Sharpness",),
        machine_aggregate="single",
        comparability="related_proxy",
        direction_note=(
            "SPAQ sharpness attribute: higher = sharper. Machine Blur is separate; "
            "this comparison uses Sharpness only, not Blur."
        ),
        applies_to_media_type="photo",
    ),
    ReferenceComparisonSpec(
        key="exposure",
        reference_mapped_column="exposure_mapped_1_5",
        machine_criterion_names=("Brightness",),
        machine_aggregate="single",
        comparability="related_proxy",
        direction_note=(
            "SPAQ brightness attribute reflects exposure quality (low = poor). "
            "Machine Brightness peaks near mid luminance; correlation is exploratory."
        ),
        applies_to_media_type="photo",
    ),
    ReferenceComparisonSpec(
        key="noise_quality",
        reference_mapped_column="noise_quality_mapped_1_5",
        machine_criterion_names=("Noise",),
        machine_aggregate="single",
        comparability="directly_comparable",
        direction_note=(
            "Reference noisiness inverted before mapping so higher 1–5 = less noise, "
            "aligned with ACCESS Noise criterion."
        ),
        applies_to_media_type="photo",
    ),
    ReferenceComparisonSpec(
        key="contrast_quality",
        reference_mapped_column="contrast_quality_mapped_1_5",
        machine_criterion_names=("Contrast",),
        machine_aggregate="single",
        comparability="related_proxy",
        direction_note="Higher attribute contrast vs machine Contrast; not identical definitions.",
        applies_to_media_type="photo",
    ),
    ReferenceComparisonSpec(
        key="color_balance",
        reference_mapped_column="color_balance_mapped_1_5",
        machine_criterion_names=(),
        machine_aggregate="single",
        comparability="not_comparable",
        direction_note="Colorfulness is not in the ACCESS machine rubric; no machine pairs.",
        applies_to_media_type="photo",
    ),
)


def specs_for_media_type(media_type: str) -> list[ReferenceComparisonSpec]:
    mt = (media_type or "photo").lower()
    out: list[ReferenceComparisonSpec] = []
    for spec in REFERENCE_COMPARISON_SPECS:
        if spec.applies_to_media_type == "any" or spec.applies_to_media_type == mt:
            out.append(spec)
    return out
