from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
for p in (_REPO, _TOOLKIT):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from phase11_scoring_diagnostics import (  # noqa: E402
    ridge_fit,
    ridge_predict,
    stratified_folds,
    univariate_linear_fit,
)
from scoring_candidates import production_soft_score  # noqa: E402


def test_soft_score_1_unreachable() -> None:
    assert production_soft_score(0.0) == 2
    assert min(production_soft_score(i / 200.0) for i in range(201)) == 2


def test_stratified_folds_eight_per_stratum() -> None:
    rows = [{"stratum_id": s} for s in range(1, 6) for _ in range(40)]
    folds = stratified_folds(rows, n_folds=5, seed=20261107)
    assert len(folds) == 200
    for s in range(1, 6):
        idxs = [i for i, r in enumerate(rows) if r["stratum_id"] == s]
        counts = [sum(1 for i in idxs if folds[i] == f) for f in range(5)]
        assert counts == [8, 8, 8, 8, 8]


def test_ridge_does_not_use_test_targets() -> None:
    rng = np.random.default_rng(0)
    Xtr = rng.normal(size=(20, 3))
    ytr = Xtr @ np.array([1.0, -2.0, 0.5]) + 0.1
    coef = ridge_fit(Xtr, ytr, lam=0.01)
    Xte = rng.normal(size=(5, 3))
    y_poison = np.full(5, 999.0)
    pred = ridge_predict(coef, Xte)
    coef2 = ridge_fit(Xtr, ytr, lam=0.01)
    pred2 = ridge_predict(coef2, Xte)
    assert np.allclose(pred, pred2)
    assert not np.allclose(pred, y_poison)


def test_positive_linear_map_keeps_slope_sign() -> None:
    x = np.linspace(0.1, 0.9, 10)
    y = 3.0 * x + 2.0
    a, b = univariate_linear_fit(x, y)
    assert b > 0
