#!/usr/bin/env python3
"""Research-only Blocking Artifacts v3 estimator for ACCESS VisionCheck.

Does not modify experimental_classical_v2, Noise v3, or production scoring.

Why v2 Blocking fails (diagnosis):
- v2 measures smoothness-weighted |Δ| on every native 8-pixel seam.
- Absolute seam magnitude rises on natural gradients, foliage, architecture, and
  other high-contrast structure that happens to cross the 8-grid.
- JPEG blocking is a *relative* effect: discontinuities at block boundaries
  exceed typical within-block adjacent differences, especially in flat areas.
- On the ACCESS pilot, humans mostly rate 4–5 (little blocking) while v2 often
  assigns 1–3 on clean textured photos → Spearman ρ ≈ −0.33.

v3 approach (a priori; not fitted on SPAQ or ACCESS pilot):
1. Center-crop to at most ANALYSIS_CAP on the long side (multiple of 8; no
   resize/interpolation) so megapixel SPAQ/phone stills stay tractable while
   preserving the local JPEG lattice inside the crop.
2. Trim to a multiple of 8.
3. Consider only pairs of neighboring 8×8 tiles that are both flat (low std).
4. On those tiles, compare mean |Δ| across the shared block boundary versus
   mean |Δ| of within-tile adjacent pairs (interior).
5. amount = mean max(0, boundary − interior) over flat H/V seams, plus a
   capped relative term. This targets JPEG lattice steps, not texture energy.
6. Map to cleanliness q with REF from controlled JPEG ladders (not pilot).
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

BLOCKING_V3_ID = "experimental_blocking_v3"
BLOCK = 8
ANALYSIS_CAP = 1280  # longest side; center crop only (no resize)

# A priori from synthetic smooth-gradient JPEG ladders (Q95→Q10). Not SPAQ/pilot.
BLOCK_AMOUNT_REF = 5.0
RATIO_WEIGHT = 1.25
RATIO_EXCESS_CAP = 2.0
INTERIOR_MEAN_FLOOR = 0.5
FLAT_TILE_STD_MAX = 12.0
MIN_FLAT_SEAMS = 8


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def _center_crop_cap(gray_u8: np.ndarray, cap: int = ANALYSIS_CAP) -> np.ndarray:
    """Center crop so longest side <= cap, keeping dimensions multiples of 8."""
    h, w = gray_u8.shape
    longest = max(h, w)
    if longest <= cap:
        return gray_u8
    th = min(h, cap - (cap % BLOCK))
    tw = min(w, cap - (cap % BLOCK))
    th = max(BLOCK * 2, th - (th % BLOCK))
    tw = max(BLOCK * 2, tw - (tw % BLOCK))
    y0 = max(0, (h - th) // 2)
    x0 = max(0, (w - tw) // 2)
    # Align crop origin to 8-grid so seams stay on the JPEG lattice.
    y0 -= y0 % BLOCK
    x0 -= x0 % BLOCK
    return gray_u8[y0 : y0 + th, x0 : x0 + tw]


def _native_multiple_of_8(gray_u8: np.ndarray) -> np.ndarray:
    h, w = gray_u8.shape
    nh, nw = h - (h % BLOCK), w - (w % BLOCK)
    if nh < BLOCK * 2 or nw < BLOCK * 2:
        return gray_u8
    return gray_u8[:nh, :nw]


def _tile_std(tile: np.ndarray) -> float:
    return float(np.std(tile))


def _interior_adjacent_mean(tile: np.ndarray, orient: str) -> float:
    """Mean absolute adjacent difference inside an 8×8 tile."""
    if orient == "vertical":
        # Horizontal neighbors (column pairs) inside the tile.
        diffs = np.abs(tile[:, 1:] - tile[:, :-1])
    else:
        diffs = np.abs(tile[1:, :] - tile[:-1, :])
    return float(np.mean(diffs)) if diffs.size else 0.0


def _collect_vertical(gray: np.ndarray) -> tuple[list[float], list[float]]:
    """Boundary and interior means for flat left/right tile pairs."""
    h, w = gray.shape
    boundary: list[float] = []
    interior: list[float] = []
    for x in range(BLOCK, w, BLOCK):
        for by in range(0, h - BLOCK + 1, BLOCK):
            left = gray[by : by + BLOCK, x - BLOCK : x]
            right = gray[by : by + BLOCK, x : x + BLOCK]
            if _tile_std(left) > FLAT_TILE_STD_MAX or _tile_std(right) > FLAT_TILE_STD_MAX:
                continue
            seam = np.abs(gray[by : by + BLOCK, x] - gray[by : by + BLOCK, x - 1])
            boundary.append(float(np.mean(seam)))
            interior.append(
                0.5
                * (
                    _interior_adjacent_mean(left, "vertical")
                    + _interior_adjacent_mean(right, "vertical")
                )
            )
    return boundary, interior


def _collect_horizontal(gray: np.ndarray) -> tuple[list[float], list[float]]:
    h, w = gray.shape
    boundary: list[float] = []
    interior: list[float] = []
    for y in range(BLOCK, h, BLOCK):
        for bx in range(0, w - BLOCK + 1, BLOCK):
            top = gray[y - BLOCK : y, bx : bx + BLOCK]
            bottom = gray[y : y + BLOCK, bx : bx + BLOCK]
            if _tile_std(top) > FLAT_TILE_STD_MAX or _tile_std(bottom) > FLAT_TILE_STD_MAX:
                continue
            seam = np.abs(gray[y, bx : bx + BLOCK] - gray[y - 1, bx : bx + BLOCK])
            boundary.append(float(np.mean(seam)))
            interior.append(
                0.5
                * (
                    _interior_adjacent_mean(top, "horizontal")
                    + _interior_adjacent_mean(bottom, "horizontal")
                )
            )
    return boundary, interior


def _axis_from_lists(boundary: list[float], interior: list[float]) -> tuple[float, float, float, float, int]:
    if len(boundary) < MIN_FLAT_SEAMS or len(interior) < MIN_FLAT_SEAMS:
        return 0.0, 0.0, 0.0, 0.0, len(boundary)
    b_mean = float(np.mean(boundary))
    i_mean = float(np.mean(interior))
    excess = max(0.0, b_mean - i_mean)
    i_floor = max(i_mean, INTERIOR_MEAN_FLOOR)
    ratio_excess = min(RATIO_EXCESS_CAP, max(0.0, (b_mean / i_floor) - 1.0))
    return excess, ratio_excess, b_mean, i_mean, len(boundary)


def _fallback_global(gray: np.ndarray) -> tuple[float, float, float, float, float, float]:
    """Unmasked global B vs I when too few flat tile pairs exist."""
    h, w = gray.shape
    vb: list[float] = []
    vi: list[float] = []
    hb: list[float] = []
    hi: list[float] = []
    for x in range(1, w):
        m = float(np.mean(np.abs(gray[:, x] - gray[:, x - 1])))
        (vb if x % BLOCK == 0 else vi).append(m)
    for y in range(1, h):
        m = float(np.mean(np.abs(gray[y, :] - gray[y - 1, :])))
        (hb if y % BLOCK == 0 else hi).append(m)
    if not vb or not vi or not hb or not hi:
        return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    bm_v, im_v = float(np.mean(vb)), float(np.mean(vi))
    bm_h, im_h = float(np.mean(hb)), float(np.mean(hi))
    ex_v = max(0.0, bm_v - im_v)
    ex_h = max(0.0, bm_h - im_h)
    r_v = min(RATIO_EXCESS_CAP, max(0.0, bm_v / max(im_v, INTERIOR_MEAN_FLOOR) - 1.0))
    r_h = min(RATIO_EXCESS_CAP, max(0.0, bm_h / max(im_h, INTERIOR_MEAN_FLOOR) - 1.0))
    return ex_v, ex_h, r_v, r_h, bm_v, bm_h


def estimate_blocking_gray(gray_u8: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Blocking v3")
    gray = _native_multiple_of_8(_center_crop_cap(gray_u8)).astype(np.float64)
    h, w = gray.shape
    empty = {
        "blocking_amount": 0.0,
        "quality_cleanliness_0_1": 1.0,
        "vertical_excess": 0.0,
        "horizontal_excess": 0.0,
        "vertical_ratio_excess": 0.0,
        "horizontal_ratio_excess": 0.0,
        "boundary_mean_v": 0.0,
        "interior_mean_v": 0.0,
        "boundary_mean_h": 0.0,
        "interior_mean_h": 0.0,
        "n_flat_seams_v": 0,
        "n_flat_seams_h": 0,
        "used_fallback": False,
        "a_priori_scales": {
            "BLOCK_AMOUNT_REF": BLOCK_AMOUNT_REF,
            "RATIO_WEIGHT": RATIO_WEIGHT,
            "RATIO_EXCESS_CAP": RATIO_EXCESS_CAP,
            "FLAT_TILE_STD_MAX": FLAT_TILE_STD_MAX,
            "ANALYSIS_CAP": ANALYSIS_CAP,
        },
        "estimator_id": BLOCKING_V3_ID,
    }
    if h < BLOCK * 2 or w < BLOCK * 2:
        return empty

    vb, vi = _collect_vertical(gray)
    hb, hi = _collect_horizontal(gray)
    v_ex, v_r, bm_v, im_v, n_v = _axis_from_lists(vb, vi)
    h_ex, h_r, bm_h, im_h, n_h = _axis_from_lists(hb, hi)
    used_fallback = False
    if n_v < MIN_FLAT_SEAMS and n_h < MIN_FLAT_SEAMS:
        v_ex, h_ex, v_r, h_r, bm_v, bm_h = _fallback_global(gray)
        im_v = im_h = float("nan")
        used_fallback = True

    amount = 0.5 * (v_ex + h_ex) + RATIO_WEIGHT * 0.5 * (v_r + h_r)
    q = clip01(1.0 - amount / BLOCK_AMOUNT_REF)

    return {
        "blocking_amount": float(amount),
        "quality_cleanliness_0_1": float(q),
        "vertical_excess": float(v_ex),
        "horizontal_excess": float(h_ex),
        "vertical_ratio_excess": float(v_r),
        "horizontal_ratio_excess": float(h_r),
        "boundary_mean_v": float(bm_v),
        "interior_mean_v": float(im_v) if im_v == im_v else None,
        "boundary_mean_h": float(bm_h),
        "interior_mean_h": float(im_h) if im_h == im_h else None,
        "n_flat_seams_v": int(n_v),
        "n_flat_seams_h": int(n_h),
        "used_fallback": used_fallback,
        "a_priori_scales": {
            "BLOCK_AMOUNT_REF": BLOCK_AMOUNT_REF,
            "RATIO_WEIGHT": RATIO_WEIGHT,
            "RATIO_EXCESS_CAP": RATIO_EXCESS_CAP,
            "FLAT_TILE_STD_MAX": FLAT_TILE_STD_MAX,
            "INTERIOR_MEAN_FLOOR": INTERIOR_MEAN_FLOOR,
            "ANALYSIS_CAP": ANALYSIS_CAP,
        },
        "estimator_id": BLOCKING_V3_ID,
    }


def estimate_blocking_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Blocking v3")
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    return estimate_blocking_gray(gray)
