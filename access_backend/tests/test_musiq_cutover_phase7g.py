"""MUSIQ primary + OpenCV fallback; EfficientNet permanently retired."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app.services import musiq_worker_client as client
from app.services import opencv_quality as oq
from app.services.media_evaluator import (
    QUALITY_ENGINE_MUSIQ_WORKER,
    QUALITY_ENGINE_OPENCV,
    resolve_quality_engine_for_bytes,
)


_METRICS = {
    "sharpness": 0.7,
    "blur": 0.3,
    "noise": 0.1,
    "brightness": 0.5,
    "contrast": 0.4,
    "blocking_artifacts": 0.1,
    "ringing_artifacts": 0.1,
    "width": 64,
    "height": 64,
}


@pytest.fixture(autouse=True)
def _settings(monkeypatch):
    monkeypatch.setattr(client.settings, "musiq_worker_url", "https://worker.test")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "secret")
    monkeypatch.setattr(client.settings, "musiq_worker_timeout_sec", 5.0)
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")


def test_vectorized_blocking_remains_enabled_after_reimport() -> None:
    import importlib

    mod = importlib.reload(oq)
    assert mod.USE_VECTORIZED_BLOCKING is True
    assert mod._blocking_artifacts.__name__ == "_blocking_artifacts"


def test_enet_quality_engine_rejected_at_settings() -> None:
    from pydantic import ValidationError

    from app.config import Settings

    with pytest.raises(ValidationError) as exc:
        Settings(QUALITY_ENGINE="enet")
    assert "no longer supported" in str(exc.value).lower() or "retired" in str(exc.value).lower()


def test_musiq_path_falls_back_to_opencv(monkeypatch) -> None:
    unavailable = client._unavailable("worker_offline", media_type="photo")
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=unavailable):
        with patch("app.services.media_evaluator.opencv_available", return_value=True):
            with patch(
                "app.services.media_evaluator.opencv_analyze",
                return_value=dict(_METRICS),
            ):
                metrics, engine, fallback = resolve_quality_engine_for_bytes(b"x")
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True
    assert metrics is not None


def test_unsupported_engine_raises_at_resolve(monkeypatch) -> None:
    monkeypatch.setattr(client.settings, "quality_engine", "enet")
    with pytest.raises(RuntimeError, match="Unsupported QUALITY_ENGINE"):
        resolve_quality_engine_for_bytes(b"x")


def test_musiq_success_labels(monkeypatch) -> None:
    payload = {
        "status": "ok",
        "classical_map_version": "phase9_a_priori_equal_bin_v1",
        "musiq": {
            "status": "ok",
            "musiq_opq_raw": 70.0,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "model_version": "paq2piq/1",
            "engine_handle": "x",
            "error": None,
        },
        "criteria_raw": {
            "sharpness_laplacian_var": 336.0,
            "brightness_mean": 0.48,
            "contrast_rms": 0.55,
            "blocking_flat_frac": 0.12,
            "noise_residual_std": 7.2,
            "ringing_edge_lap": 4.0,
        },
        "criteria_q": {"sharpness": 0.9, "blur": 0.9, "brightness": 0.8, "contrast": 0.7, "blocking_artifacts": 0.95},
    }
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=payload):
        metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpeg-bytes")
    assert engine == QUALITY_ENGINE_MUSIQ_WORKER
    assert fallback is False
    assert metrics is not None
