"""Controlled synthetic tests for experimental_classical_v2 Blur/Noise/Blocking/Ringing."""

from __future__ import annotations

import numpy as np
import pytest

cv2 = pytest.importorskip("cv2")

from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    ENGINE_ID,
    analyze_bgr,
    analyze_image_bytes,
)


def _tex_image(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = (rng.random((256, 256, 3)) * 40 + 100).astype(np.uint8)
    img[:, 120:136] = 220
    return img


def _flat_panel() -> np.ndarray:
    return np.full((256, 256, 3), 120, dtype=np.uint8)


def test_engine_id_is_v2() -> None:
    out = analyze_bgr(_tex_image())
    assert out["engine_id"] == ENGINE_ID == "experimental_classical_v2"
    assert "Blur" in out["revised_criteria"]


def test_blur_raw_decreases_with_gaussian_sigma() -> None:
    base = _tex_image()
    vals = []
    for sigma in (0.0, 0.8, 1.5, 3.0, 6.0):
        img = base if sigma == 0.0 else cv2.GaussianBlur(base, (0, 0), sigma)
        vals.append(analyze_bgr(img)["raw"]["laplacian_var"])
    assert all(vals[i] >= vals[i + 1] for i in range(len(vals) - 1))
    assert analyze_bgr(base)["criterion_scores"]["Blur"] > analyze_bgr(
        cv2.GaussianBlur(base, (0, 0), 3.0)
    )["criterion_scores"]["Blur"]


def test_noise_raw_increases_with_awgn_on_flat() -> None:
    rng = np.random.default_rng(0)
    base = _flat_panel()
    vals = []
    for sigma in (0, 5, 10, 20, 40):
        if sigma == 0:
            img = base
        else:
            img = np.clip(
                base.astype(np.int16) + rng.normal(0, sigma, base.shape).astype(np.int16),
                0,
                255,
            ).astype(np.uint8)
        vals.append(analyze_bgr(img)["raw"]["homogeneous_residual_std"])
    assert all(vals[i] <= vals[i + 1] for i in range(len(vals) - 1))
    assert analyze_bgr(base)["criterion_scores"]["Noise"] >= analyze_bgr(
        np.clip(base.astype(np.int16) + rng.normal(0, 40, base.shape).astype(np.int16), 0, 255).astype(
            np.uint8
        )
    )["criterion_scores"]["Noise"]


def test_noise_texture_alone_not_worse_than_flat_plus_strong_awgn() -> None:
    rng = np.random.default_rng(1)
    tex = _tex_image(1)
    flat_noisy = np.clip(
        _flat_panel().astype(np.int16) + rng.normal(0, 35, (256, 256, 3)).astype(np.int16),
        0,
        255,
    ).astype(np.uint8)
    tex_amount = analyze_bgr(tex)["raw"]["homogeneous_residual_std"]
    noisy_amount = analyze_bgr(flat_noisy)["raw"]["homogeneous_residual_std"]
    assert noisy_amount > tex_amount


def test_blocking_seam_higher_for_heavy_jpeg_than_light_jpeg() -> None:
    # Smooth gradient preserves JPEG 8x8 seams better than high-frequency texture.
    yy, xx = np.mgrid[0:256, 0:256]
    img = np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )
    light = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 95])[1].tobytes()
    heavy = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 20])[1].tobytes()
    light_r = analyze_image_bytes(light)
    heavy_r = analyze_image_bytes(heavy)
    assert light_r is not None and heavy_r is not None
    assert (
        heavy_r["raw"]["smooth_weighted_seam_delta"]
        > light_r["raw"]["smooth_weighted_seam_delta"]
    )
    assert (
        heavy_r["criterion_scores"]["Blocking Artifacts"]
        <= light_r["criterion_scores"]["Blocking Artifacts"]
    )


def test_ringing_sinc_raises_oscillation_vs_clean_step() -> None:
    step = np.zeros((256, 256, 3), dtype=np.uint8)
    step[:, :128] = 255
    kernel = np.array([0.06, -0.12, 0.25, -0.45, 1.52, -0.45, 0.25, -0.12, 0.06], dtype=np.float32)
    kernel /= kernel.sum()
    gibbs = step.copy()
    for _ in range(2):
        gibbs = cv2.filter2D(gibbs, -1, kernel.reshape(1, -1))
        gibbs = cv2.filter2D(gibbs, -1, kernel.reshape(-1, 1))
    clean = analyze_bgr(step)["raw"]["near_edge_oscillation"]
    osc = analyze_bgr(gibbs)["raw"]["near_edge_oscillation"]
    assert osc >= clean


def test_ringing_not_forced_equal_to_inverse_sharpness_badge() -> None:
    img = _tex_image(4)
    out = analyze_bgr(img)
    sharp = out["criterion_scores"]["Sharpness"]
    ring = out["criterion_scores"]["Ringing Artifacts"]
    # Must not hard-wire ringing badge as a transform of sharpness alone.
    assert not (ring == sharp and out["raw"]["near_edge_oscillation"] == out["raw"]["laplacian_var"])
