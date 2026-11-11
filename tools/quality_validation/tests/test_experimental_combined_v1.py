"""Lightweight regression/integration tests for combined experimental engine."""

from __future__ import annotations

import time

import cv2
import numpy as np

from tools.quality_validation.experimental_blocking_v3 import estimate_blocking_bgr
from tools.quality_validation.experimental_quality_engine_combined_v1 import (
    COMPOSITION,
    CRITERIA,
    ENGINE_ID,
    V2_CRITERIA,
    analyze_bgr,
    analyze_image_bytes,
)
from tools.quality_validation.experimental_quality_engine_v2 import analyze_bgr as analyze_v2
from tools.quality_validation.experimental_ringing_v3 import estimate_ringing_bgr
from tools.quality_validation.scoring_candidates import equal_bin_1_5


def _smooth_gradient(size: int = 192) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    return np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )


def _clean_step(size: int = 192) -> np.ndarray:
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, : size // 2] = 40
    img[:, size // 2 :] = 220
    return img


def test_seven_criteria_present_quality_oriented() -> None:
    # Uncompressed gradient (no JPEG lattice) + clean step for ringing.
    out_grad = analyze_bgr(_smooth_gradient())
    out_step = analyze_bgr(_clean_step())
    assert out_grad["engine_id"] == ENGINE_ID
    assert set(out_grad["criterion_scores"]) == set(CRITERIA)
    for name, badge in out_grad["criterion_scores"].items():
        assert 1 <= int(badge) <= 5
    assert out_grad["quality_scale_note"].startswith("All seven")
    assert out_grad["criterion_scores"]["Blocking Artifacts"] >= 4
    assert out_step["criterion_scores"]["Ringing Artifacts"] >= 4


def test_v2_criteria_match_parent_engine() -> None:
    img = _smooth_gradient()
    v2 = analyze_v2(img)
    comb = analyze_bgr(img)
    for name in V2_CRITERIA:
        assert comb["criterion_scores"][name] == v2["criterion_scores"][name]
    assert comb["revised_criteria"] == ["Blocking Artifacts", "Ringing Artifacts"]
    assert COMPOSITION["Noise_v3_status"] == "alternate_not_promoted"


def test_blocking_and_ringing_use_v3_estimators() -> None:
    img = _clean_step()
    comb = analyze_bgr(img)
    blk = estimate_blocking_bgr(img)
    rng = estimate_ringing_bgr(img)
    assert comb["criterion_scores"]["Blocking Artifacts"] == equal_bin_1_5(
        float(blk["quality_cleanliness_0_1"])
    )
    assert comb["criterion_scores"]["Ringing Artifacts"] == equal_bin_1_5(
        float(rng["quality_cleanliness_0_1"])
    )
    assert comb["composition"]["Blocking Artifacts"].endswith("blocking_v3")
    assert comb["composition"]["Ringing Artifacts"].endswith("ringing_v3")


def test_jpeg_blocking_worsens_without_changing_v2_noise_source() -> None:
    img = _smooth_gradient()
    light = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 95])[1].tobytes()
    heavy = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 10])[1].tobytes()
    a = analyze_image_bytes(light)
    b = analyze_image_bytes(heavy)
    assert a is not None and b is not None
    assert b["raw"]["blocking_amount_v3"] > a["raw"]["blocking_amount_v3"]
    assert b["criterion_scores"]["Blocking Artifacts"] <= a["criterion_scores"]["Blocking Artifacts"]
    assert a["composition"]["Noise"] == "experimental_classical_v2"


def test_no_duplicate_criterion_keys() -> None:
    out = analyze_bgr(_clean_step())
    assert len(out["criterion_scores"]) == 7
    assert len(set(out["criterion_scores"])) == 7
    expected = round(sum(out["criterion_scores"].values()) / 7, 2)
    assert out["overall_score"] == expected
    assert out["system_overall_is_mean_of_criteria"] is True


def test_bytes_path_and_runtime_budget() -> None:
    buf = cv2.imencode(".jpg", _clean_step(), [int(cv2.IMWRITE_JPEG_QUALITY), 90])[1].tobytes()
    t0 = time.perf_counter()
    out = analyze_image_bytes(buf)
    ms = (time.perf_counter() - t0) * 1000.0
    assert out is not None
    assert ms < 1500.0, ms
