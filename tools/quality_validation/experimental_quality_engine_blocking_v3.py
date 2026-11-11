#!/usr/bin/env python3
"""Research-only engine: v2 criteria with Blocking Artifacts replaced by v3.

Preserves experimental_classical_v2 and experimental_classical_v3 (Noise) sources.
Only Blocking is revised. Production untouched.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.experimental_blocking_v3 import (
    BLOCKING_V3_ID,
    estimate_blocking_bgr,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    ENGINE_ID as V2_ENGINE_ID,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    analyze_bgr as analyze_bgr_v2,
)
from tools.quality_validation.scoring_candidates import equal_bin_1_5, production_soft_score

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

ENGINE_ID = "experimental_classical_blocking_v3"


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    base = analyze_bgr_v2(bgr)
    blocking = estimate_blocking_bgr(bgr)
    q_block = float(blocking["quality_cleanliness_0_1"])
    badge = equal_bin_1_5(q_block)

    criterion_scores = dict(base["criterion_scores"])
    criterion_scores["Blocking Artifacts"] = badge
    overall = round(sum(criterion_scores.values()) / len(criterion_scores), 2)

    quality = dict(base["quality_0_1"])
    quality["blocking_artifacts"] = q_block

    raw = dict(base["raw"])
    raw["smooth_weighted_seam_delta_v2"] = raw.pop("smooth_weighted_seam_delta", None)
    raw["blocking_amount_v3"] = blocking["blocking_amount"]
    raw["blocking_vertical_excess_v3"] = blocking["vertical_excess"]
    raw["blocking_horizontal_excess_v3"] = blocking["horizontal_excess"]
    raw["blocking_vertical_ratio_excess_v3"] = blocking["vertical_ratio_excess"]
    raw["blocking_horizontal_ratio_excess_v3"] = blocking["horizontal_ratio_excess"]

    meta = dict(base["criterion_meta"])
    meta["Blocking Artifacts"] = {
        "proxy": True,
        "raw_name": "blocking_amount_v3",
        "direction": "higher_raw_is_more_blocking",
        "notes": (
            "v3 JPEG lattice excess: block-boundary |Δ| minus within-block |Δ| "
            "on low-gradient pixels (native 8-grid). Cleanliness badge inverts amount."
        ),
        "estimator_id": BLOCKING_V3_ID,
    }

    soft = dict(base.get("soft_score_on_experimental_q") or {})
    soft["Blocking Artifacts"] = production_soft_score(q_block)

    scales = dict(base.get("a_priori_scales") or {})
    scales.update(blocking["a_priori_scales"])
    scales["parent_engine"] = V2_ENGINE_ID
    scales["blocking_estimator"] = BLOCKING_V3_ID

    return {
        **base,
        "engine_id": ENGINE_ID,
        "criterion_scores": criterion_scores,
        "overall_score": overall,
        "quality_0_1": quality,
        "raw": raw,
        "criterion_meta": meta,
        "soft_score_on_experimental_q": soft,
        "a_priori_scales": scales,
        "parent_engine": V2_ENGINE_ID,
        "revised_criteria": ["Blocking Artifacts"],
        "blocking_v3": blocking,
    }


def analyze_image_bytes(content: bytes) -> dict[str, Any] | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        return None
    try:
        from app.services.image_orientation import decode_oriented_bgr

        oriented = decode_oriented_bgr(content)
        if oriented is not None:
            bgr = oriented
    except Exception:
        pass
    return analyze_bgr(bgr)
