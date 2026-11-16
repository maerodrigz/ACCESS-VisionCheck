#!/usr/bin/env python3
"""Research-only engine: v2 criteria with Ringing Artifacts replaced by v3.

Preserves experimental_classical_v2 and Noise/Blocking v3 sources.
Only Ringing is revised. Production untouched.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.experimental_quality_engine_v2 import (
    ENGINE_ID as V2_ENGINE_ID,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    analyze_bgr as analyze_bgr_v2,
)
from tools.quality_validation.experimental_ringing_v3 import (
    RINGING_V3_ID,
    estimate_ringing_bgr,
)
from tools.quality_validation.scoring_candidates import equal_bin_1_5, production_soft_score

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

ENGINE_ID = "experimental_classical_ringing_v3"


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    base = analyze_bgr_v2(bgr)
    ringing = estimate_ringing_bgr(bgr)
    q_ring = float(ringing["quality_cleanliness_0_1"])
    badge = equal_bin_1_5(q_ring)

    criterion_scores = dict(base["criterion_scores"])
    criterion_scores["Ringing Artifacts"] = badge
    overall = round(sum(criterion_scores.values()) / len(criterion_scores), 2)

    quality = dict(base["quality_0_1"])
    quality["ringing_artifacts"] = q_ring

    raw = dict(base["raw"])
    raw["near_edge_oscillation_v2"] = raw.pop("near_edge_oscillation", None)
    raw["ringing_amount_v3"] = ringing["ringing_amount"]
    raw["ringing_median_overshoot_v3"] = ringing["median_overshoot"]
    raw["ringing_median_oscillation_v3"] = ringing["median_oscillation"]
    raw["ringing_n_scored_v3"] = ringing["n_scored"]

    meta = dict(base["criterion_meta"])
    meta["Ringing Artifacts"] = {
        "proxy": True,
        "raw_name": "ringing_amount_v3",
        "direction": "higher_raw_is_more_ringing",
        "notes": (
            "v3 near-edge plateau overshoot + residual oscillation on smooth "
            "sides of strong steps. Cleanliness badge inverts amount."
        ),
        "estimator_id": RINGING_V3_ID,
    }

    soft = dict(base.get("soft_score_on_experimental_q") or {})
    soft["Ringing Artifacts"] = production_soft_score(q_ring)

    scales = dict(base.get("a_priori_scales") or {})
    scales.update(ringing["a_priori_scales"])
    scales["parent_engine"] = V2_ENGINE_ID
    scales["ringing_estimator"] = RINGING_V3_ID

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
        "revised_criteria": ["Ringing Artifacts"],
        "ringing_v3": ringing,
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
