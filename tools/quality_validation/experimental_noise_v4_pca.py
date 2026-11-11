#!/usr/bin/env python3
"""Research-only Noise v4: patch PCA blind noise-level estimation.

Does not modify Noise v2/v3, production, or combined_v1.

Primary: weak-texture patch PCA / smallest-eigenvalue BNE (Liu–Tanaka–Okutomi class).
Secondary baseline: wavelet-style HH high-pass MAD (separable Haar detail), for comparison only.

Scales are a priori from synthetic AWGN ladders. Not fitted on SPAQ or the frozen ACCESS pilot.
"""

from __future__ import annotations

from typing import Any

import numpy as np
from numpy.linalg import svd

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

NOISE_V4_ID = "experimental_noise_v4_pca"
RESIZE_CAP = 1024
PATCH = 8
# Keep the weakest-texture fraction of patches for PCA.
WEAK_FRAC = 0.05
MIN_WEAK_PATCHES = 20
MAX_PATCHES_FOR_PCA = 400
# Absolute weak-texture gate (mean Sobel mag); rejects structured foliage patches.
WEAK_TEX_MAX = 8.0
# A priori REF from synthetic AWGN on flat panels (not pilot).
NOISE_SIGMA_REF = 14.0
CHROMA_WEIGHT = 1.15
DARK_VISIBILITY_GAIN = 0.35
# When weak patches still look structured, blend toward wavelet on flat-ish content only.
TEXTURE_GUARD = 18.0


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


def _mad_sigma(values: np.ndarray) -> float:
    if values.size == 0:
        return 0.0
    med = float(np.median(values))
    return 1.4826 * float(np.median(np.abs(values - med)))


def wavelet_hh_mad_sigma(gray_f: np.ndarray) -> float:
    """Secondary baseline: Haar-like HH detail MAD → Gaussian scale.

    Uses 2x2 diagonal differences (no PyWavelets dependency).
    """
    # Downsample-friendly even crop.
    h, w = gray_f.shape
    h2, w2 = h - (h % 2), w - (w % 2)
    g = gray_f[:h2, :w2]
    # HH ≈ (a - b - c + d) / 2 for 2x2 block [a b; c d]
    a = g[0::2, 0::2]
    b = g[0::2, 1::2]
    c = g[1::2, 0::2]
    d = g[1::2, 1::2]
    hh = 0.5 * (a - b - c + d)
    return _mad_sigma(hh.ravel())


def _collect_patches(channel: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (patches[N, P*P], structure_scores[N]).

    Structure score uses gradients of a mildly blurred image so AWGN flats stay
    low while natural texture remains high (noise-resistant weak-patch selection).
    """
    h, w = channel.shape
    blur = cv2.GaussianBlur(channel, (0, 0), 1.2)
    gx = cv2.Sobel(blur, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(blur, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    patches: list[np.ndarray] = []
    scores: list[float] = []
    step = PATCH  # non-overlapping for speed/stability
    for y in range(0, h - PATCH + 1, step):
        for x in range(0, w - PATCH + 1, step):
            tile = channel[y : y + PATCH, x : x + PATCH]
            tscore = float(np.mean(mag[y : y + PATCH, x : x + PATCH]))
            patches.append(tile.reshape(-1))
            scores.append(tscore)
    if not patches:
        return np.zeros((0, PATCH * PATCH), dtype=float), np.zeros(0, dtype=float)
    return np.asarray(patches, dtype=float), np.asarray(scores, dtype=float)


def _pca_noise_sigma(patches: np.ndarray) -> float:
    """Smallest singular value of centered weak patches ≈ noise scale."""
    if patches.shape[0] < 2:
        return 0.0
    # Center each patch
    x = patches - patches.mean(axis=1, keepdims=True)
    # Economy SVD on (n_patches x dim); noise ~ sigma_min / sqrt(n_pix) style.
    # For additive white noise, the smallest eigenvalue of cov ≈ σ².
    # Use SVD of data matrix: s[-1]^2 / (n-1) ≈ λ_min when rows are observations.
    n = x.shape[0]
    # Limit rows for runtime
    if n > MAX_PATCHES_FOR_PCA:
        rng = np.random.default_rng(0)
        idx = rng.choice(n, size=MAX_PATCHES_FOR_PCA, replace=False)
        x = x[idx]
        n = x.shape[0]
    # SVD of X (n x p); singular values relate to sqrt(eigenvalues of X'X)
    _, s, _ = svd(x, full_matrices=False)
    if s.size == 0:
        return 0.0
    # λ_min of sample covariance ≈ s_min^2 / (n - 1)
    lam_min = float(s[-1] ** 2) / max(n - 1, 1)
    return float(np.sqrt(max(lam_min, 0.0)))


def estimate_noise_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Noise v4")
    work = _resize_longest(bgr, RESIZE_CAP)
    yuv = cv2.cvtColor(work, cv2.COLOR_BGR2YUV).astype(np.float64)
    y = yuv[:, :, 0]
    u = yuv[:, :, 1]
    v = yuv[:, :, 2]

    # Secondary wavelet baseline on luma (always computed).
    wavelet_sigma = wavelet_hh_mad_sigma(y)

    y_patches, y_tex = _collect_patches(y)
    u_patches, _ = _collect_patches(u)
    v_patches, _ = _collect_patches(v)
    n_total = int(y_patches.shape[0])
    insufficient = n_total < MIN_WEAK_PATCHES

    # Chroma wavelet secondary (responds when luma is clean but U/V are noisy).
    chroma_wavelet = 0.5 * (wavelet_hh_mad_sigma(u) + wavelet_hh_mad_sigma(v))

    luma_sigma = 0.0
    chroma_sigma = 0.0
    n_weak = 0
    weak_idx = np.zeros(0, dtype=int)
    used_fallback = False
    fallback_reason = ""

    if insufficient:
        used_fallback = True
        fallback_reason = "insufficient_patches"
        luma_sigma = wavelet_sigma
        chroma_sigma = chroma_wavelet
    else:
        # Weak by texture rank AND absolute gate.
        order = np.argsort(y_tex)
        n_keep = max(MIN_WEAK_PATCHES, int(round(WEAK_FRAC * n_total)))
        n_keep = min(n_keep, n_total, MAX_PATCHES_FOR_PCA)
        cand = order[:n_keep]
        weak_idx = np.asarray([i for i in cand if y_tex[i] <= WEAK_TEX_MAX], dtype=int)
        if weak_idx.size < MIN_WEAK_PATCHES:
            # Relax absolute gate but keep weakest rank set.
            weak_idx = np.asarray(cand, dtype=int)
            used_fallback = True
            fallback_reason = "relaxed_weak_texture_gate"
        n_weak = int(weak_idx.size)
        if n_weak < MIN_WEAK_PATCHES:
            used_fallback = True
            fallback_reason = "insufficient_weak_texture_patches"
            luma_sigma = wavelet_sigma
            chroma_sigma = chroma_wavelet
        else:
            luma_sigma = _pca_noise_sigma(y_patches[weak_idx])
            if u_patches.shape[0] == n_total and v_patches.shape[0] == n_total:
                cu = _pca_noise_sigma(u_patches[weak_idx])
                cv_ = _pca_noise_sigma(v_patches[weak_idx])
                chroma_sigma = max(0.5 * (cu + cv_), chroma_wavelet)
            else:
                chroma_sigma = chroma_wavelet
            if luma_sigma <= 1e-6 and wavelet_sigma > 0:
                used_fallback = True
                fallback_reason = "pca_degenerate_used_wavelet"
                luma_sigma = wavelet_sigma

    # Guard: if selected "weak" patches are still textured, damp structured energy.
    if weak_idx.size > 0:
        weak_tex_med = float(np.median(y_tex[weak_idx]))
    elif n_total > 0:
        weak_tex_med = float(np.median(y_tex))
    else:
        weak_tex_med = 0.0
    amount_raw = max(luma_sigma, CHROMA_WEIGHT * chroma_sigma)
    if weak_tex_med > TEXTURE_GUARD and chroma_sigma < 2.0:
        # Structured content: damp luma-PCA; keep chroma channel.
        luma_damped = min(luma_sigma, max(wavelet_sigma, 0.45 * luma_sigma))
        amount_raw = max(luma_damped, CHROMA_WEIGHT * chroma_sigma)
    mean_luma = float(np.mean(y)) / 255.0
    visibility = 1.0 + DARK_VISIBILITY_GAIN * (1.0 - mean_luma)
    amount = float(amount_raw * visibility)
    q = clip01(1.0 - amount / NOISE_SIGMA_REF)

    return {
        "noise_amount": amount,
        "noise_amount_raw": float(amount_raw),
        "quality_cleanliness_0_1": float(q),
        "luma_sigma_pca": float(luma_sigma),
        "chroma_sigma_pca": float(chroma_sigma),
        "wavelet_hh_mad_sigma": float(wavelet_sigma),
        "chroma_wavelet_hh_mad_sigma": float(chroma_wavelet),
        "n_patches_total": n_total,
        "n_weak_patches": n_weak,
        "insufficient_homogeneous_patches": bool(insufficient or fallback_reason.startswith("insufficient")),
        "used_fallback": used_fallback,
        "fallback_reason": fallback_reason or None,
        "visibility_weight": float(visibility),
        "a_priori_scales": {
            "NOISE_SIGMA_REF": NOISE_SIGMA_REF,
            "CHROMA_WEIGHT": CHROMA_WEIGHT,
            "WEAK_FRAC": WEAK_FRAC,
            "MIN_WEAK_PATCHES": MIN_WEAK_PATCHES,
            "PATCH": PATCH,
            "fitted_on_access_pilot": False,
            "fitted_on_spaq": False,
        },
        "estimator_id": NOISE_V4_ID,
        "secondary_baseline": "wavelet_hh_mad",
    }
