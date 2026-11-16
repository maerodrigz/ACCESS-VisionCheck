#!/usr/bin/env python3
"""Research-only Ringing v4: monotone ESF fit + bipolar halo lobe detection.

Does not modify Ringing v2/v3, production, or combined_v1.

Approach:
1. Probe strong-gradient edge pixels; sample a 1-D profile along the normal.
2. Fit a monotone edge-spread function (robust logistic) to the profile.
3. Residual = profile − fit.
4. Require paired opposite-sign lobes near the edge (overshoot/undershoot).
5. Clean sharp steps have near-zero bipolar score; unsharp/Gibbs raise it.

Scales a priori from controlled unsharp/sinc ladders. Not fitted on SPAQ or ACCESS pilot.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

RINGING_V4_ID = "experimental_ringing_v4_halo"
RESIZE_CAP = 1024
PROFILE_RADIUS = 8
MAX_PROBES = 140
MIN_STEP = 26.0
MAX_FAR_VAR = 70.0
MIN_SCORED = 10
MIN_SCORED_FRAC = 0.07
# Lobe search window in samples from edge (index offset).
LOBE_NEAR = 1
LOBE_FAR = 5
# A priori from controlled ladders (not pilot).
RING_AMOUNT_REF = 10.0
AMOUNT_CAP = 28.0


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


def _monotone_logistic_esf(prof: np.ndarray) -> np.ndarray | None:
    """Fit a monotone ESF: hard two-plateau step or logistic, whichever has lower RMSE."""
    r = PROFILE_RADIUS
    t = np.arange(prof.size, dtype=float) - r
    left = prof[:3]
    right = prof[-3:]
    if float(np.var(left)) > MAX_FAR_VAR or float(np.var(right)) > MAX_FAR_VAR:
        return None
    L = float(np.median(left))
    R = float(np.median(right))
    step = abs(R - L)
    if step < MIN_STEP:
        return None

    best_sse = float("inf")
    best_hard = None
    for split in range(max(3, r - 2), min(prof.size - 3, r + 3) + 1):
        model = np.empty_like(prof)
        model[:split] = L
        model[split:] = R
        sse = float(np.sum((prof - model) ** 2))
        if sse < best_sse:
            best_sse = sse
            best_hard = model

    dabs = np.abs(np.diff(prof))
    slope = float(np.max(dabs)) if dabs.size else 0.0
    k = float(np.clip(4.0 * slope / max(step, 1e-6), 0.5, 25.0))
    logistic = L + (R - L) / (1.0 + np.exp(-k * t))
    sse_log = float(np.sum((prof - logistic) ** 2))
    if best_hard is not None and best_sse <= sse_log:
        return best_hard
    return logistic


def _bipolar_lobe_score(resid: np.ndarray) -> tuple[float, bool]:
    """Score paired opposite-sign lobes near the edge in the residual.

    Returns (score, found_pair).
    """
    r = PROFILE_RADIUS
    # Left side indices approaching edge: r-LOBE_FAR .. r-LOBE_NEAR
    # Right side: r+LOBE_NEAR .. r+LOBE_FAR
    left = resid[r - LOBE_FAR : r - LOBE_NEAR + 1]
    right = resid[r + LOBE_NEAR : r + LOBE_FAR + 1]
    if left.size < 2 or right.size < 2:
        return 0.0, False

    def side_lobes(seg: np.ndarray) -> tuple[float, float]:
        pos = float(np.max(seg))
        neg = float(np.min(seg))
        return max(pos, 0.0), max(-neg, 0.0)

    # A true halo often shows opposite-sign structure on at least one side
    # (overshoot then undershoot), or complementary signs across the edge.
    lp, ln = side_lobes(left)
    rp, rn = side_lobes(right)

    pair_left = min(lp, ln)  # both polarities on left
    pair_right = min(rp, rn)
    # Cross-edge complementary: left positive & right negative (or vice versa)
    cross = max(min(lp, rn), min(ln, rp))

    best_pair = max(pair_left, pair_right, 0.5 * cross)
    # Ignore tiny fitting ripples on near-ideal steps.
    if best_pair <= 1.25:
        return 0.0, False
    energy = 0.5 * (lp + ln + rp + rn)
    score = 0.65 * best_pair + 0.35 * (energy / 4.0)
    return float(score), True


def _score_profile(prof: np.ndarray) -> dict[str, float] | None:
    model = _monotone_logistic_esf(prof)
    if model is None:
        return None
    resid = prof - model
    # Fit quality: clean edges should have small residual RMSE.
    rmse = float(np.sqrt(np.mean(resid ** 2)))
    lobe, found = _bipolar_lobe_score(resid)
    if not found:
        # No bipolar halo → ringing amount near zero for this probe.
        return {"amount": 0.0, "lobe": 0.0, "rmse": rmse, "fit_ok": 1.0}
    # Downweight if residual is huge everywhere (texture), keep lobe-driven score.
    amount = min(AMOUNT_CAP, lobe + 0.15 * min(rmse, 20.0))
    return {"amount": float(amount), "lobe": float(lobe), "rmse": rmse, "fit_ok": 1.0}


def estimate_ringing_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV required for Ringing v4")
    work = _resize_longest(bgr, RESIZE_CAP)
    gray_u8 = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    g = gray_u8.astype(np.float64)
    h, w = g.shape
    scales = {
        "RING_AMOUNT_REF": RING_AMOUNT_REF,
        "MIN_STEP": MIN_STEP,
        "MAX_FAR_VAR": MAX_FAR_VAR,
        "AMOUNT_CAP": AMOUNT_CAP,
        "fitted_on_access_pilot": False,
        "fitted_on_spaq": False,
    }
    empty = {
        "ringing_amount": 0.0,
        "quality_cleanliness_0_1": 1.0,
        "n_probes": 0,
        "n_scored": 0,
        "n_with_bipolar_lobes": 0,
        "median_lobe": 0.0,
        "median_fit_rmse": 0.0,
        "reliable_edge_profile": False,
        "limitation": "image_too_small_or_no_edges",
        "a_priori_scales": scales,
        "estimator_id": RINGING_V4_ID,
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
        out = dict(empty)
        out["limitation"] = "insufficient_strong_edges"
        return out

    order = np.argsort(mag[ys, xs])[::-1]
    xs = xs[order]
    ys = ys[order]
    step_i = max(1, len(xs) // MAX_PROBES)

    amounts: list[float] = []
    lobes: list[float] = []
    rmses: list[float] = []
    n_bipolar = 0
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
        lobes.append(scored["lobe"])
        rmses.append(scored["rmse"])
        if scored["lobe"] > 0.5:
            n_bipolar += 1

    min_needed = max(MIN_SCORED, int(round(MIN_SCORED_FRAC * max(n_probes, 1))))
    if len(amounts) < min_needed:
        out = dict(empty)
        out["n_probes"] = int(n_probes)
        out["n_scored"] = int(len(amounts))
        out["reliable_edge_profile"] = False
        out["limitation"] = "could_not_obtain_enough_reliable_edge_profiles"
        return out

    arr = np.asarray(amounts, dtype=float)
    p90 = float(np.percentile(arr, 90))
    thr_a = float(np.percentile(arr, 75))
    top = arr[arr >= thr_a]
    amount = float(min(AMOUNT_CAP, 0.7 * p90 + 0.3 * float(np.mean(top))))
    q = clip01(1.0 - amount / RING_AMOUNT_REF)

    return {
        "ringing_amount": amount,
        "quality_cleanliness_0_1": float(q),
        "n_probes": int(n_probes),
        "n_scored": int(len(amounts)),
        "n_with_bipolar_lobes": int(n_bipolar),
        "median_lobe": float(np.median(lobes)),
        "median_fit_rmse": float(np.median(rmses)),
        "reliable_edge_profile": True,
        "limitation": None,
        "a_priori_scales": scales,
        "estimator_id": RINGING_V4_ID,
    }
