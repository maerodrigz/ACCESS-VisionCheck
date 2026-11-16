#!/usr/bin/env python3
"""Research-only experimental engine v3: Noise-only revision of v2.

Preserves experimental_classical_v2 unchanged. All criteria except Noise are
delegated to v2. Noise uses experimental_noise_v3 (flat-block MAD luma+chroma).

Not fitted on SPAQ-200 or the ACCESS human pilot. Production untouched.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.experimental_noise_v3 import (
    NOISE_V3_ID,
    estimate_noise_bgr,
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

ENGINE_ID = "experimental_classical_v3"


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    base = analyze_bgr_v2(bgr)
    noise = estimate_noise_bgr(bgr)
    q_noise = float(noise["quality_cleanliness_0_1"])
    badge = equal_bin_1_5(q_noise)

    criterion_scores = dict(base["criterion_scores"])
    criterion_scores["Noise"] = badge
    overall = round(sum(criterion_scores.values()) / len(criterion_scores), 2)

    quality = dict(base["quality_0_1"])
    quality["noise"] = q_noise

    raw = dict(base["raw"])
    # Keep v2 homog residual for diagnostics; add v3 fields.
    raw["homogeneous_residual_std_v2"] = raw.pop("homogeneous_residual_std", None)
    raw["noise_amount_v3"] = noise["noise_amount"]
    raw["noise_amount_raw_v3"] = noise["noise_amount_raw"]
    raw["noise_luma_sigma_v3"] = noise["luma_sigma"]
    raw["noise_chroma_sigma_v3"] = noise["chroma_sigma"]
    raw["noise_homog_residual_v3"] = noise["homog_residual"]
    raw["noise_n_flat_blocks_v3"] = noise["n_flat_blocks"]
    raw["noise_visibility_weight_v3"] = noise["visibility_weight"]

    meta = dict(base["criterion_meta"])
    meta["Noise"] = {
        "proxy": True,
        "raw_name": "noise_amount_v3",
        "direction": "higher_raw_is_more_noise",
        "notes": (
            "v3 flat-block MAD Laplacian (luma) + chroma residual MAD; "
            "cleanliness badge inverts amount. Parent engine remains v2 for other criteria."
        ),
        "estimator_id": NOISE_V3_ID,
    }

    soft = dict(base.get("soft_score_on_experimental_q") or {})
    soft["Noise"] = production_soft_score(q_noise)

    scales = dict(base.get("a_priori_scales") or {})
    scales.update(noise["a_priori_scales"])
    scales["parent_engine"] = V2_ENGINE_ID
    scales["noise_estimator"] = NOISE_V3_ID

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
        "revised_criteria": ["Noise"],
        "noise_v3": noise,
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
