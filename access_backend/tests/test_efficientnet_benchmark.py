"""Sanity checks for EfficientNet-B0 benchmark helpers."""

from app.services.efficientnet_benchmark import criterion_metrics, pearson_correlation
from app.services.efficientnet_synthetic_iqa import labels_vector, synthesize_iqa_sample


def test_pearson_perfect_correlation():
    y = [0.1, 0.3, 0.5, 0.8, 0.9]
    assert pearson_correlation(__import__("numpy").array(y), __import__("numpy").array(y)) == 1.0


def test_criterion_metrics_zero_error():
    m = criterion_metrics("sharpness", [0.2, 0.5, 0.8], [0.2, 0.5, 0.8])
    assert m.mae == 0.0
    assert m.rmse == 0.0


def test_synthetic_labels_match_criterion_keys():
    _, labels = synthesize_iqa_sample(rng=__import__("random").Random(0))
    vec = labels_vector(labels)
    assert len(vec) == 7
    assert all(0.0 <= v <= 1.0 for v in vec)
