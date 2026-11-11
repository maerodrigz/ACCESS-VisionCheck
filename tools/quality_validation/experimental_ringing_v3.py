#!/usr/bin/env python3
"""Research-only Ringing Artifacts v3 estimator for ACCESS VisionCheck.

Does not modify experimental_classical_v2, Noise/Blocking v3, or production.

Why v2 Ringing fails (diagnosis):
- v2 samples near-edge second differences on the 'smooth' side of Canny edges.
- |d2| responds to discrete curvature on clean steps and under-fires on real
  sharpening/compression halos that humans mark down.
- ACCESS pilot: humans often 3 while v2 assigns 4–5 → Spearman ρ ≈ −0.40.

v3 approach (a priori; not fitted on SPAQ or ACCESS pilot):
1. Probe strong-gradient edge pixels.
2. Sample a bilateral 1-D profile along the normal.
3. Estimate left/right plateaus from outermost samples; require stable plateaus
   and a real luminance step (rejects most natural texture crumbs).
4. On each side, score near-edge overshoot past the plateaus and residual
   oscillation relative to that side's plateau only (never across the step).
5. Aggregate with a robust high percentile.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

RINGING_V3_ID = "experimental_ringing_v3"
RESIZE_CAP = 1024

# A priori from controlled clean-step / unsharp / sinc ladders. Not SPAQ/pilot.
RING_AMOUNT_REF = 20.0
MIN_STEP = 28.0
MAX_PLATEAU_VAR = 90.0
MIN_SCORED = 12  # reject sparse texture false hits
MIN_SCORED_FRAC = 0.08
PROFILE_RADIUS = 8
MAX_PROBES = 160
OVERSHOOT_WEIGHT = 1.0
OSC_WEIGHT = 0.06  # second-diff magnitudes are large vs gray overshoot
AMOUNT_CAP = 48.0


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


def _profile(
    gray: np.ndarray, x: int, y: int, dx: float, dy: float, radius: int
) -> np.ndarray | None:
    h, w = gray.shape
    vals: list[float] = []
    for t in range(-radius, radius + 1):
        xx = int(round(x + t * dx))
        yy = int(round(y + t * dy))
        if not (0 <= xx < w and 0 <= yy < h):
            return None
        vals.append(float(gray[yy, xx]))
    return np.asarray(vals, dtype=float)


def _side_metrics(near: np.ndarray, plateau: float, lo: float, hi: float) -> tuple[float, float]:
    if near.size < 3:
        return 0.0, 0.0
    overshoot = float(np.mean(np.maximum(near - hi, 0.0) + np.maximum(lo - near, 0.0)))
    # Halo past the local plateau (classic sharpening bright/dark ring).
    halo = float(np.mean(np.abs(near - plateau)))
    # Prefer true overshoot beyond step levels; keep a small fraction of |halo|.
    overshoot = max(overshoot, 0.25 * halo)

    resid = near - plateau
    d2 = resid[2:] - 2.0 * resid[1:-1] + resid[:-2] if resid.size >= 3 else np.zeros(0)
    osc = float(np.mean(np.abs(d2))) if d2.size else 0.0
    signs = np.sign(resid[1:] - resid[:-1]) if resid.size >= 2 else np.zeros(0)
    signs = signs[signs != 0]
    flips = float(np.sum(signs[1:] * signs[:-1] < 0)) if signs.size >= 2 else 0.0
    if flips >= 1.0:
        osc *= 1.0 + 0.3 * min(flips, 3.0)
    return overshoot, osc


def _score_profile(prof: np.ndarray) -> dict[str, float] | None:
    r = PROFILE_RADIUS
    left_plateau_samples = prof[0:3]
    right_plateau_samples = prof[-3:]
    # If far taps are very unstable, fall back to the outermost pair only.
    if float(np.var(left_plateau_samples)) > MAX_PLATEAU_VAR:
        left_plateau_samples = prof[0:2]
    if float(np.var(right_plateau_samples)) > MAX_PLATEAU_VAR:
        right_plateau_samples = prof[-2:]
    if float(np.var(left_plateau_samples)) > MAX_PLATEAU_VAR * 1.5:
        return None
    if float(np.var(right_plateau_samples)) > MAX_PLATEAU_VAR * 1.5:
        return None

    lp = float(np.median(left_plateau_samples))
    rp = float(np.median(right_plateau_samples))
    step = abs(lp - rp)
    if step < MIN_STEP:
        return None

    lo, hi = (lp, rp) if lp <= rp else (rp, lp)
    # Near-edge halo band with a 1px guard from the edge sample itself.
    left_near = prof[r - 5 : r - 1]
    right_near = prof[r + 2 : r + 6]
    o_l, osc_l = _side_metrics(left_near, lp, lo, hi)
    o_r, osc_r = _side_metrics(right_near, rp, lo, hi)
    overshoot = 0.5 * (o_l + o_r)
    osc = 0.5 * (osc_l + osc_r)
    amount = OVERSHOOT_WEIGHT * overshoot + OSC_WEIGHT * osc
    return {
        "step": step,
        "overshoot": overshoot,
        "oscillation": osc,
        "amount": float(min(AMOUNT_CAP, amount)),
    }


def estimate_ringing_gray(gray_u8: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Ringing v3")
    g = gray_u8.astype(np.float64)
    h, w = g.shape
    scales = {
        "RING_AMOUNT_REF": RING_AMOUNT_REF,
        "MIN_STEP": MIN_STEP,
        "MAX_PLATEAU_VAR": MAX_PLATEAU_VAR,
        "MIN_SCORED": MIN_SCORED,
        "MIN_SCORED_FRAC": MIN_SCORED_FRAC,
        "OVERSHOOT_WEIGHT": OVERSHOOT_WEIGHT,
        "OSC_WEIGHT": OSC_WEIGHT,
        "AMOUNT_CAP": AMOUNT_CAP,
    }
    empty = {
        "ringing_amount": 0.0,
        "quality_cleanliness_0_1": 1.0,
        "n_probes": 0,
        "n_scored": 0,
        "median_overshoot": 0.0,
        "median_oscillation": 0.0,
        "p90_amount": 0.0,
        "a_priori_scales": scales,
        "estimator_id": RINGING_V3_ID,
    }
    if h < 32 or w < 32:
        return empty

    gx = cv2.Sobel(g, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(g, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    thr = max(float(np.percentile(mag, 92)), 25.0)
    ys, xs = np.where(mag >= thr)
    if len(xs) < 20:
        thr = max(float(np.percentile(mag, 85)), 15.0)
        ys, xs = np.where(mag >= thr)
    if len(xs) < 20:
        return empty

    order = np.argsort(mag[ys, xs])[::-1]
    xs = xs[order]
    ys = ys[order]
    step_i = max(1, len(xs) // MAX_PROBES)

    amounts: list[float] = []
    overs: list[float] = []
    oscs: list[float] = []
    n_probes = 0

    for i in range(0, len(xs), step_i):
        x, y = int(xs[i]), int(ys[i])
        m = float(mag[y, x]) + 1e-6
        dx, dy = float(gx[y, x] / m), float(gy[y, x] / m)
        n_probes += 1
        prof = _profile(g, x, y, dx, dy, PROFILE_RADIUS)
        if prof is None:
            continue
        scored = _score_profile(prof)
        if scored is None:
            continue
        amounts.append(scored["amount"])
        overs.append(scored["overshoot"])
        oscs.append(scored["oscillation"])

    min_needed = max(MIN_SCORED, int(round(MIN_SCORED_FRAC * max(n_probes, 1))))
    if len(amounts) < min_needed:
        out = dict(empty)
        out["n_probes"] = int(n_probes)
        out["n_scored"] = int(len(amounts))
        return out

    arr = np.asarray(amounts, dtype=float)
    p90 = float(np.percentile(arr, 90))
    thr_a = float(np.percentile(arr, 75))
    top = arr[arr >= thr_a]
    amount = float(min(AMOUNT_CAP, 0.65 * p90 + 0.35 * float(np.mean(top))))
    q = clip01(1.0 - amount / RING_AMOUNT_REF)

    return {
        "ringing_amount": amount,
        "quality_cleanliness_0_1": float(q),
        "n_probes": int(n_probes),
        "n_scored": int(len(amounts)),
        "median_overshoot": float(np.median(overs)),
        "median_oscillation": float(np.median(oscs)),
        "p90_amount": p90,
        "a_priori_scales": scales,
        "estimator_id": RINGING_V3_ID,
    }


def estimate_ringing_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Ringing v3")
    work = _resize_longest(bgr, RESIZE_CAP)
    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    return estimate_ringing_gray(gray)
