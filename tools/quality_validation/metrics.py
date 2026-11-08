"""Correlation, error, and inter-rater metrics for validation analysis."""

from __future__ import annotations

import math
from typing import Any, Sequence

import numpy as np
from scipy import stats


def pearson_spearman(x: Sequence[float], y: Sequence[float]) -> dict[str, float | None]:
    if len(x) < 2 or len(y) < 2 or len(x) != len(y):
        return {"pearson_r": None, "pearson_p": None, "spearman_r": None, "spearman_p": None, "n": len(x)}
    xa = np.asarray(x, dtype=float)
    ya = np.asarray(y, dtype=float)
    if float(np.std(xa)) == 0.0 or float(np.std(ya)) == 0.0:
        return {
            "pearson_r": None,
            "pearson_p": None,
            "spearman_r": None,
            "spearman_p": None,
            "n": len(x),
            "note": "correlation undefined when a series has zero variance",
        }
    pr, pp = stats.pearsonr(xa, ya)
    sr, sp = stats.spearmanr(xa, ya)
    return {
        "pearson_r": float(pr),
        "pearson_p": float(pp),
        "spearman_r": float(sr),
        "spearman_p": float(sp),
        "n": len(x),
    }


def mae_rmse(x: Sequence[float], y: Sequence[float]) -> dict[str, float | None]:
    if len(x) == 0 or len(x) != len(y):
        return {"mae": None, "rmse": None, "n": len(x)}
    d = np.asarray(x, dtype=float) - np.asarray(y, dtype=float)
    return {
        "mae": float(np.mean(np.abs(d))),
        "rmse": float(np.sqrt(np.mean(d * d))),
        "n": len(x),
    }


def quadratic_weighted_kappa(rater_a: Sequence[int], rater_b: Sequence[int], min_rating: int = 1, max_rating: int = 5) -> float | None:
    if len(rater_a) != len(rater_b) or len(rater_a) == 0:
        return None
    n_ratings = max_rating - min_rating + 1
    conf_mat = np.zeros((n_ratings, n_ratings), dtype=float)
    for a, b in zip(rater_a, rater_b, strict=True):
        if a < min_rating or a > max_rating or b < min_rating or b > max_rating:
            continue
        conf_mat[a - min_rating, b - min_rating] += 1
    if conf_mat.sum() == 0:
        return None
    conf_mat /= conf_mat.sum()
    hist_a = conf_mat.sum(axis=1)
    hist_b = conf_mat.sum(axis=0)
    expected = np.outer(hist_a, hist_b)
    weights = np.zeros((n_ratings, n_ratings))
    for i in range(n_ratings):
        for j in range(n_ratings):
            weights[i, j] = ((i - j) ** 2) / ((n_ratings - 1) ** 2) if n_ratings > 1 else 0.0
    observed = (weights * conf_mat).sum()
    expected_score = (weights * expected).sum()
    if expected_score == 0:
        return 1.0 if observed == 0 else 0.0
    return float(1.0 - observed / expected_score)


def fleiss_kappa(ratings_matrix: np.ndarray) -> float | None:
    """
    ratings_matrix: shape (n_items, n_raters) with integer category labels or NaN for missing.
    """
    if ratings_matrix.size == 0:
        return None
    n_items, n_raters = ratings_matrix.shape
    valid = ratings_matrix[~np.isnan(ratings_matrix)]
    if valid.size == 0:
        return None
    categories = np.unique(valid.astype(int))
    n_categories = len(categories)
    if n_categories < 2:
        return None

    p_i = []
    for i in range(n_items):
        row = ratings_matrix[i]
        row = row[~np.isnan(row)]
        if len(row) == 0:
            continue
        counts = np.array([(row == c).sum() for c in categories], dtype=float)
        n = counts.sum()
        if n <= 1:
            continue
        p_i.append((np.sum(counts**2) - n) / (n * (n - 1)))
    if not p_i:
        return None
    p_bar = float(np.mean(p_i))

    p_j = []
    for j, c in enumerate(categories):
        col_counts = []
        for i in range(n_items):
            row = ratings_matrix[i]
            row = row[~np.isnan(row)]
            if len(row) == 0:
                continue
            col_counts.append((row == c).sum())
        total = sum(col_counts)
        n_all = sum(len(ratings_matrix[i][~np.isnan(ratings_matrix[i])]) for i in range(n_items))
        if n_all == 0:
            continue
        p_j.append(total / n_all)
    p_e = sum(p**2 for p in p_j)

    if math.isclose(1.0 - p_e, 0.0):
        return 1.0
    return float((p_bar - p_e) / (1.0 - p_e))


def repeatability_std(values: Sequence[float]) -> dict[str, float | None]:
    if len(values) < 2:
        return {"mean": float(values[0]) if values else None, "std": 0.0, "n": len(values)}
    arr = np.asarray(values, dtype=float)
    return {"mean": float(arr.mean()), "std": float(arr.std(ddof=1)), "n": len(arr)}


def spearman_bootstrap(
    x: Sequence[float],
    y: Sequence[float],
    *,
    n_boot: int = 1000,
    seed: int = 20261107,
    ci: float = 0.95,
) -> dict[str, float | None]:
    """Percentile bootstrap on Spearman r. Does not refit score maps."""
    base = pearson_spearman(x, y)
    n = len(x)
    if n < 5 or base.get("spearman_r") is None:
        return {**base, "spearman_ci_low": None, "spearman_ci_high": None, "n_boot": 0}
    rng = np.random.default_rng(seed)
    xa = np.asarray(x, dtype=float)
    ya = np.asarray(y, dtype=float)
    samples: list[float] = []
    for _ in range(n_boot):
        idx = rng.integers(0, n, size=n)
        corr = pearson_spearman(xa[idx], ya[idx])
        r = corr.get("spearman_r")
        if r is not None:
            samples.append(float(r))
    if len(samples) < 20:
        return {**base, "spearman_ci_low": None, "spearman_ci_high": None, "n_boot": len(samples)}
    alpha = (1.0 - ci) / 2.0
    lo, hi = np.quantile(samples, [alpha, 1.0 - alpha])
    return {
        **base,
        "spearman_ci_low": float(lo),
        "spearman_ci_high": float(hi),
        "n_boot": len(samples),
    }


def correlation_bootstrap(
    x: Sequence[float],
    y: Sequence[float],
    *,
    n_boot: int = 1000,
    seed: int = 20261107,
    ci: float = 0.95,
) -> dict[str, float | None]:
    """Percentile bootstrap on Pearson and Spearman r. Does not refit maps."""
    base = spearman_bootstrap(x, y, n_boot=n_boot, seed=seed, ci=ci)
    n = len(x)
    if n < 5 or base.get("pearson_r") is None:
        return {**base, "pearson_ci_low": None, "pearson_ci_high": None}
    rng = np.random.default_rng(seed)
    xa = np.asarray(x, dtype=float)
    ya = np.asarray(y, dtype=float)
    samples: list[float] = []
    for _ in range(n_boot):
        idx = rng.integers(0, n, size=n)
        corr = pearson_spearman(xa[idx], ya[idx])
        r = corr.get("pearson_r")
        if r is not None:
            samples.append(float(r))
    if len(samples) < 20:
        return {**base, "pearson_ci_low": None, "pearson_ci_high": None}
    alpha = (1.0 - ci) / 2.0
    lo, hi = np.quantile(samples, [alpha, 1.0 - alpha])
    return {**base, "pearson_ci_low": float(lo), "pearson_ci_high": float(hi)}
