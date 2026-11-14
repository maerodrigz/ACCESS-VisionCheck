"""Phase 7G: MUSIQ primary + OpenCV fallback; ENET inactive on cutover path."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest

from app.services import musiq_worker_client as client
from app.services import opencv_quality as oq
from app.services.media_evaluator import (
    QUALITY_ENGINE_EFFICIENTNET,
    QUALITY_ENGINE_MUSIQ_WORKER,
    QUALITY_ENGINE_OPENCV,
    resolve_quality_engine_for_bytes,
)
from app.services.efficientnet_b0_scorer import weights_path


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
    monkeypatch.setattr(client.settings, "quality_engine", "enet")


def test_vectorized_blocking_remains_enabled_after_reimport() -> None:
    import importlib

    mod = importlib.reload(oq)
    assert mod.USE_VECTORIZED_BLOCKING is True
    assert mod._blocking_artifacts.__name__ == "_blocking_artifacts"


def test_enet_weights_still_on_disk_for_rollback() -> None:
    assert weights_path().is_file()
    assert weights_path().name == "efficientnet_b0_heads.pt"


def test_musiq_path_does_not_call_enet_on_fallback(monkeypatch) -> None:
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    unavailable = client._unavailable("worker_offline", media_type="photo")
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=unavailable):
        with patch("app.services.media_evaluator.efficientnet_analyze") as enet:
            with patch("app.services.media_evaluator.opencv_available", return_value=True):
                with patch(
                    "app.services.media_evaluator.opencv_analyze",
                    return_value=dict(_METRICS),
                ):
                    metrics, engine, fallback = resolve_quality_engine_for_bytes(b"x")
    enet.assert_not_called()
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True
    assert metrics is not None


def test_rollback_enet_path_still_selectable(monkeypatch) -> None:
    monkeypatch.setattr(client.settings, "quality_engine", "enet")
    with patch("app.services.media_evaluator.efficientnet_available", return_value=True):
        with patch("app.services.media_evaluator.ensure_weights", return_value=True):
            with patch(
                "app.services.media_evaluator.efficientnet_analyze",
                return_value=dict(_METRICS),
            ) as enet:
                with patch("app.services.media_evaluator.opencv_analyze") as opencv:
                    metrics, engine, fallback = resolve_quality_engine_for_bytes(b"x")
    enet.assert_called_once()
    opencv.assert_not_called()
    assert engine == QUALITY_ENGINE_EFFICIENTNET
    assert fallback is False
    assert metrics is not None


def test_enet_load_error_is_surfaced(monkeypatch) -> None:
    from app.services import efficientnet_b0_scorer as enet_mod

    monkeypatch.setattr(enet_mod, "_model", None)
    monkeypatch.setattr(enet_mod, "_WEIGHTS_PATH", Path("/nonexistent/efficientnet_b0_heads.pt"))
    assert enet_mod.ensure_weights() is False
    assert enet_mod.last_load_error()
    assert "weights_missing" in (enet_mod.last_load_error() or "")


def test_musiq_success_labels(monkeypatch) -> None:
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
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
        with patch("app.services.media_evaluator.efficientnet_analyze") as enet:
            metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpeg-bytes")
    enet.assert_not_called()
    assert engine == QUALITY_ENGINE_MUSIQ_WORKER
    assert fallback is False
    assert metrics is not None
