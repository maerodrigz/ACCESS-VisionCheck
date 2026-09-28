"""Metrics helpers for EfficientNet-B0 IQA benchmark runs."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np

from app.services.efficientnet_b0_scorer import CRITERION_KEYS


@dataclass
class CriterionMetrics:
    key: str
    mae: float
    rmse: float
    pearson: float
    spearman: float
    n: int


def _rank(values: np.ndarray) -> np.ndarray:
    order = values.argsort()
    ranks = np.empty_like(order, dtype=np.float64)
    ranks[order] = np.arange(len(values), dtype=np.float64)
    return ranks


def pearson_correlation(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    if len(y_true) < 2:
        return float("nan")
    if np.std(y_true) < 1e-9 or np.std(y_pred) < 1e-9:
        return float("nan")
    return float(np.corrcoef(y_true, y_pred)[0, 1])


def spearman_correlation(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    return pearson_correlation(_rank(y_true), _rank(y_pred))


def criterion_metrics(key: str, y_true: list[float], y_pred: list[float]) -> CriterionMetrics:
    true = np.asarray(y_true, dtype=np.float64)
    pred = np.asarray(y_pred, dtype=np.float64)
    err = pred - true
    return CriterionMetrics(
        key=key,
        mae=float(np.mean(np.abs(err))),
        rmse=float(np.sqrt(np.mean(err**2))),
        pearson=pearson_correlation(true, pred),
        spearman=spearman_correlation(true, pred),
        n=len(true),
    )


def summarize_predictions(
    rows: list[dict[str, Any]],
) -> tuple[list[CriterionMetrics], float]:
    """Return per-criterion metrics and mean MAE across criteria."""
    metrics: list[CriterionMetrics] = []
    for key in CRITERION_KEYS:
        true = [float(r["labels"][key]) for r in rows]
        pred = [float(r["pred"][key]) for r in rows]
        metrics.append(criterion_metrics(key, true, pred))
    mean_mae = float(np.mean([m.mae for m in metrics])) if metrics else float("nan")
    return metrics, mean_mae
