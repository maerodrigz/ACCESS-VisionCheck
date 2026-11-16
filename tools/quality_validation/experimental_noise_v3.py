#!/usr/bin/env python3
"""Research-only Noise v3 estimator for ACCESS VisionCheck.

Does not modify experimental_classical_v2 or production scoring.

Why v2 fails (diagnosis):
- v2 uses |Y - GaussianBlur(Y)| std on a low-gradient mask.
- Structured texture, sharpening residuals, and JPEG grain in 'flat' masks still
  leak into that residual.
- Chrominance noise is invisible to a luma-only residual.
- On the ACCESS pilot, the detector often assigns badge 5 while humans rate 3
  (under-detection), producing a wrong-signed rank relationship.

v3 approach (a priori; not fitted on SPAQ or ACCESS pilot):
1. Select flat 8x8 blocks by low luminance std AND low edge density.
2. Estimate robust high-pass energy per block with MAD of Laplacian (luma)
   and MAD of chroma residuals (U/V).
3. Aggregate with a median over flat blocks (resistant to outlier textured tiles).
4. Also compute a v2-style homogeneous luma residual as a safety channel
   (preserves rank signal when flat MAD under-fires on processed photos).
5. amount = max(luma_mad, CHROMA_WEIGHT * chroma_mad, homog_residual).
6. Mild dark-visibility weight (a priori).
7. Map to cleanliness q with REF from synthetic AWGN.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

NOISE_V3_ID = "experimental_noise_v3"
RESIZE_CAP = 1024

# A priori from synthetic AWGN ladders (flat + photo + chroma). Not SPAQ/pilot.
NOISE_AMOUNT_REF = 10.0
CHROMA_WEIGHT = 1.35
BLOCK = 8
MIN_FLAT_BLOCKS = 12
# Flat block gates (8-bit).
FLAT_STD_MAX = 6.5
FLAT_EDGE_MAX = 0.08
DARK_VISIBILITY_GAIN = 0.45  # amount *= 1 + gain*(1 - mean_luma)


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def _resize_longest(bgr: np.ndarray, cap: int = RESIZE_CAP) -> np.ndarray:
    h, w = bgr.shape[:2]
    longest = max(h, w)
    if longest <= cap:
        return bgr
    scale = cap / float(longest)
    nh, nw = max(1, int(round(h * scale))), max(1, int(round(w * scale)))
    return cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)


def _mad(values: np.ndarray) -> float:
    if values.size == 0:
        return 0.0
    med = float(np.median(values))
    return float(np.median(np.abs(values - med)))


def _sigma_from_mad(mad: float) -> float:
    # Robust Gaussian scale: sigma ≈ 1.4826 * MAD
    return 1.4826 * float(mad)


def _flat_block_coords(y: np.ndarray, edges: np.ndarray) -> list[tuple[int, int]]:
    h, w = y.shape
    coords: list[tuple[int, int]] = []
    for by in range(0, h - BLOCK + 1, BLOCK):
        for bx in range(0, w - BLOCK + 1, BLOCK):
            tile = y[by : by + BLOCK, bx : bx + BLOCK]
            if float(np.std(tile)) > FLAT_STD_MAX:
                continue
            e = edges[by : by + BLOCK, bx : bx + BLOCK]
            if float(np.mean(e > 0)) > FLAT_EDGE_MAX:
                continue
            coords.append((by, bx))
    return coords


def estimate_noise_bgr(bgr: np.ndarray) -> dict[str, Any]:
    """Return noise amount / cleanliness for a BGR image."""
    if cv2 is None:
        raise RuntimeError("OpenCV required for Noise v3")
    work = _resize_longest(bgr, RESIZE_CAP)
    yuv = cv2.cvtColor(work, cv2.COLOR_BGR2YUV)
    y = yuv[:, :, 0].astype(np.float64)
    u = yuv[:, :, 1].astype(np.float64)
    v = yuv[:, :, 2].astype(np.float64)
    y_u8 = yuv[:, :, 0]
    edges = cv2.Canny(y_u8, 60, 140)

    coords = _flat_block_coords(y, edges)
    luma_sigs: list[float] = []
    chroma_sigs: list[float] = []

    # Mild blur for chroma residual; Laplacian MAD for luma high-frequency grain.
    u_blur = cv2.GaussianBlur(u, (3, 3), 0)
    v_blur = cv2.GaussianBlur(v, (3, 3), 0)

    for by, bx in coords:
        y_tile = y[by : by + BLOCK, bx : bx + BLOCK]
        lap = cv2.Laplacian(y_tile, cv2.CV_64F)
        luma_sigs.append(_sigma_from_mad(_mad(lap.ravel())) / 6.0)
        # /6 approximates Immerkaer-style scaling for 3x3 Laplacian energy.

        u_res = (u[by : by + BLOCK, bx : bx + BLOCK] - u_blur[by : by + BLOCK, bx : bx + BLOCK]).ravel()
        v_res = (v[by : by + BLOCK, bx : bx + BLOCK] - v_blur[by : by + BLOCK, bx : bx + BLOCK]).ravel()
        chroma_sigs.append(
            max(_sigma_from_mad(_mad(u_res)), _sigma_from_mad(_mad(v_res)))
        )

    n_flat = len(coords)
    if n_flat < MIN_FLAT_BLOCKS:
        # Fallback: global low-gradient MAD (still robust, still chroma-aware).
        gx = cv2.Sobel(y, cv2.CV_64F, 1, 0, ksize=3)
        gy = cv2.Sobel(y, cv2.CV_64F, 0, 1, ksize=3)
        mag = np.sqrt(gx * gx + gy * gy)
        thr = max(float(np.percentile(mag, 25)), 6.0)
        mask = mag <= thr
        if int(np.count_nonzero(mask)) < 256:
            mask = np.ones_like(y, dtype=bool)
        lap = cv2.Laplacian(y, cv2.CV_64F)
        luma_sigma = _sigma_from_mad(_mad(lap[mask].ravel())) / 6.0
        chroma_sigma = max(
            _sigma_from_mad(_mad((u - u_blur)[mask].ravel())),
            _sigma_from_mad(_mad((v - v_blur)[mask].ravel())),
        )
        fallback = True
    else:
        luma_sigma = float(np.median(np.asarray(luma_sigs, dtype=float)))
        chroma_sigma = float(np.median(np.asarray(chroma_sigs, dtype=float)))
        fallback = False

    # Homogeneous luma residual (v2-style) as a safety channel.
    y_blur = cv2.GaussianBlur(y_u8, (5, 5), 0).astype(np.float64)
    residual = np.abs(y - y_blur)
    gx = cv2.Sobel(y, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(y, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    thr = max(float(np.percentile(mag, 30)), 8.0)
    homog_mask = mag <= thr
    if int(np.count_nonzero(homog_mask)) < 256:
        homog_residual = float(np.std(residual))
    else:
        homog_residual = float(np.std(residual[homog_mask]))

    mean_luma = float(np.mean(y) / 255.0)
    amount_raw = max(float(luma_sigma), CHROMA_WEIGHT * float(chroma_sigma), homog_residual)
    visibility = 1.0 + DARK_VISIBILITY_GAIN * (1.0 - mean_luma)
    amount = float(amount_raw * visibility)
    q_clean = clip01(1.0 - amount / NOISE_AMOUNT_REF)

    return {
        "estimator_id": NOISE_V3_ID,
        "noise_amount": amount,
        "noise_amount_raw": amount_raw,
        "luma_sigma": float(luma_sigma),
        "chroma_sigma": float(chroma_sigma),
        "homog_residual": homog_residual,
        "quality_cleanliness_0_1": q_clean,
        "n_flat_blocks": n_flat,
        "used_fallback_mask": fallback,
        "mean_luma": mean_luma,
        "visibility_weight": visibility,
        "resize_cap": RESIZE_CAP,
        "a_priori_scales": {
            "NOISE_AMOUNT_REF": NOISE_AMOUNT_REF,
            "CHROMA_WEIGHT": CHROMA_WEIGHT,
            "FLAT_STD_MAX": FLAT_STD_MAX,
            "FLAT_EDGE_MAX": FLAT_EDGE_MAX,
            "DARK_VISIBILITY_GAIN": DARK_VISIBILITY_GAIN,
            "combine": "max(luma_mad, CHROMA_WEIGHT*chroma_mad, homog_residual)",
            "fitted_on_spaq": False,
            "fitted_on_access_pilot": False,
        },
        "notes": (
            "Flat-block MAD Laplacian (luma) + chroma residual MAD, combined via max "
            "with homogeneous luma residual. Higher noise_amount = more noise."
        ),
    }


def estimate_noise_bytes(content: bytes) -> dict[str, Any] | None:
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
    return estimate_noise_bgr(bgr)
