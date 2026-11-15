"""Phase 7A: MUSIQ worker selectable quality engine (adapter, fallback, isolation)."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app.services import musiq_worker_client as client
from app.services import musiq_quality_adapter as adapter
from app.services.media_evaluator import (
    QUALITY_ENGINE_MUSIQ_WORKER,
    QUALITY_ENGINE_OPENCV,
    evaluate_photo,
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


def _worker_ok_payload(*, opq: float = 78.79, status: str = "ok") -> dict:
    return {
        "status": status,
        "media_type": "photo",
        "classical_map_version": "phase9_a_priori_equal_bin_v1",
        "musiq": {
            "status": "ok" if status in ("ok", "partial") else status,
            "musiq_opq_raw": opq,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "model_version": "paq2piq/1",
            "engine_handle": "https://tfhub.dev/google/musiq/paq2piq/1",
            "error": None,
        },
        # Higher-is-better q-space — must NOT be used as production raw metrics.
        "criteria_q": {
            "sharpness": 0.9,
            "blur": 0.9,
            "brightness": 0.8,
            "contrast": 0.7,
            "blocking_artifacts": 0.95,
        },
        "criteria_raw": {
            "sharpness_laplacian_var": 336.0,  # → sharpness 0.8
            "brightness_mean": 0.48,
            "contrast_rms": 0.55,
            "blocking_flat_frac": 0.12,
            "noise_residual_std": 7.2,  # → noise 0.2
            "ringing_edge_lap": 4.0,
            "blur_inv_laplacian": 0.2,
        },
        "experimental_feedback": {"issue_count": 0},
        "frames_analyzed": 1,
        "error": None,
        "production_payload_mutated": False,
    }


@pytest.fixture
def musiq_settings(monkeypatch):
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    monkeypatch.setattr(client.settings, "musiq_worker_url", "https://worker.test")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "secret")
    monkeypatch.setattr(client.settings, "musiq_worker_timeout_sec", 5.0)
    monkeypatch.setattr(client.settings, "musiq_worker_tls_verify", True)


def test_adapter_maps_criteria_raw_polarities(musiq_settings):
    mapped = adapter.metrics_from_worker_result(_worker_ok_payload(), content=None)
    assert mapped is not None
    clean, ctx = adapter.strip_adapter_metadata(mapped)
    assert clean["sharpness"] == pytest.approx(0.8)
    assert clean["blur"] == pytest.approx(0.2)  # higher-is-worse
    assert clean["blocking_artifacts"] == pytest.approx(0.12)  # higher-is-worse
    assert clean["noise"] == pytest.approx(0.2)
    assert clean["brightness"] == pytest.approx(0.48)
    assert ctx is not None
    assert ctx["context_only"] is True
    assert ctx["musiq_opq_raw"] == pytest.approx(78.79)
    assert "sharpness" not in (ctx or {})


def test_adapter_rejects_criteria_q_only(musiq_settings):
    bad = _worker_ok_payload()
    del bad["criteria_raw"]
    assert adapter.worker_result_mappable(bad) is False
    assert adapter.metrics_from_worker_result(bad) is None


def test_adapter_rejects_missing_raw_keys(musiq_settings):
    bad = _worker_ok_payload()
    del bad["criteria_raw"]["blocking_flat_frac"]
    assert adapter.metrics_from_worker_result(bad) is None


def test_quality_engine_is_musiq_worker(musiq_settings):
    assert client.quality_engine() == "musiq_worker"


def test_musiq_worker_selected(musiq_settings, monkeypatch):
    with patch(
        "app.services.musiq_worker_client.evaluate_bytes",
        return_value=_worker_ok_payload(),
    ) as worker:
        metrics, engine, fallback = resolve_quality_engine_for_bytes(b"fake-jpeg")
    worker.assert_called_once()
    assert engine == QUALITY_ENGINE_MUSIQ_WORKER
    assert fallback is False
    assert metrics is not None
    assert metrics["sharpness"] == pytest.approx(0.8)


def test_worker_timeout_falls_back_to_opencv(musiq_settings, monkeypatch):
    unavailable = client._unavailable("worker_timeout", media_type="photo")
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=unavailable):
        with patch("app.services.media_evaluator.opencv_available", return_value=True):
            with patch(
                "app.services.media_evaluator.opencv_analyze",
                return_value=dict(_METRICS),
            ):
                metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpg")
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True
    assert metrics["sharpness"] == 0.7


def test_worker_offline_falls_back_to_opencv(musiq_settings, monkeypatch):
    unavailable = client._unavailable("worker_timeout", media_type="photo")
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=unavailable):
        with patch("app.services.media_evaluator.opencv_available", return_value=True):
            with patch(
                "app.services.media_evaluator.opencv_analyze",
                return_value=dict(_METRICS),
            ):
                metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpg")
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True
    assert metrics is not None


def test_unmappable_worker_schema_falls_back_to_opencv(musiq_settings, monkeypatch):
    bad = _worker_ok_payload()
    bad["criteria_raw"] = {"sharpness_laplacian_var": 100.0}  # incomplete
    with patch("app.services.musiq_worker_client.evaluate_bytes", return_value=bad):
        with patch("app.services.media_evaluator.opencv_available", return_value=True):
            with patch(
                "app.services.media_evaluator.opencv_analyze",
                return_value=dict(_METRICS),
            ):
                _metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpg")
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True


def test_api_payload_shape_and_musiq_context(musiq_settings, monkeypatch):
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    auth = {
        "verdict": "authentic",
        "probability": 0.04,
        "detector_backend": "probe",
        "label": "human",
    }
    color = (
        {
            "name": "Color Balance",
            "score": 4,
            "label": "Good",
            "available": True,
            "explanation": "ok",
            "suggestion": "ok",
        },
        {
            "name": "Color Saturation",
            "score": 4,
            "label": "Good",
            "available": True,
            "explanation": "ok",
            "suggestion": "ok",
        },
    )
    with patch(
        "app.services.musiq_worker_client.evaluate_bytes",
        return_value=_worker_ok_payload(),
    ):
        with patch(
            "app.services.media_evaluator.analyze_color_criteria_bytes",
            return_value=color,
        ):
            with patch(
                "app.services.media_evaluator.build_photo_supplementary_insights",
                return_value={},
            ):
                with patch(
                    "app.services.media_evaluator.detect_ai_generated",
                    return_value=auth,
                ) as detect:
                    with patch(
                        "app.services.media_evaluator.apply_integrity_evaluation_policy",
                        side_effect=lambda p: p,
                    ):
                        payload = evaluate_photo(b"fake-jpeg", file_name="x.jpg")
    assert payload is not None
    detect.assert_called_once()
    names = [c["name"] for c in payload["criteria"]]
    assert names[:5] == [
        "Sharpness",
        "Blur",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
    ]
    assert "Color Balance" in names
    assert "Color Saturation" in names
    assert 1 <= int(payload["criteria"][0]["score"]) <= 5
    assert payload["analysis"]["quality_engine"] == QUALITY_ENGINE_MUSIQ_WORKER
    assert payload["analysis"]["musiq_opq_context_only"] is True
    assert payload["analysis"]["musiq_opq"]["musiq_opq_raw"] == pytest.approx(78.79)
    assert payload["analysis"]["musiq_opq"]["not_used_for_criteria"] is True
    # OPQ must not replace criterion-mean overall
    assert payload["overall_score"] != pytest.approx(78.79)
    assert "legacy" in payload
    assert payload["evaluation_available"] is True


def test_authenticity_isolated_from_musiq_path(musiq_settings, monkeypatch):
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    auth = {"verdict": "ai_generated", "probability": 0.91, "detector_backend": "probe"}
    color = (
        {"name": "Color Balance", "score": 3, "label": "Fair", "available": True},
        {"name": "Color Saturation", "score": 3, "label": "Fair", "available": True},
    )
    with patch(
        "app.services.musiq_worker_client.evaluate_bytes",
        return_value=_worker_ok_payload(),
    ):
        with patch(
            "app.services.media_evaluator.analyze_color_criteria_bytes",
            return_value=color,
        ):
            with patch(
                "app.services.media_evaluator.build_photo_supplementary_insights",
                return_value={},
            ):
                with patch(
                    "app.services.media_evaluator.detect_ai_generated",
                    return_value=auth,
                ) as detect:
                    with patch(
                        "app.services.media_evaluator.apply_integrity_evaluation_policy",
                        side_effect=lambda p: p,
                    ):
                        payload = evaluate_photo(b"bytes", include_authenticity=True)
    assert payload["ai_detection"]["detector_backend"] == "probe"
    assert payload["analysis"]["quality_engine"] != payload["ai_detection"]["detector_backend"]
    assert detect.call_count == 1
    # Worker response must not be the authenticity source
    assert "musiq" not in (payload.get("ai_detection") or {})


def test_preview_skips_authenticity_still_uses_quality(musiq_settings, monkeypatch):
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    color = (
        {"name": "Color Balance", "score": 4, "label": "Good", "available": True},
        {"name": "Color Saturation", "score": 4, "label": "Good", "available": True},
    )
    with patch(
        "app.services.musiq_worker_client.evaluate_bytes",
        return_value=_worker_ok_payload(),
    ):
        with patch(
            "app.services.media_evaluator.analyze_color_criteria_bytes",
            return_value=color,
        ):
            with patch(
                "app.services.media_evaluator.build_photo_supplementary_insights",
                return_value={},
            ):
                with patch("app.services.media_evaluator.detect_ai_generated") as detect:
                    payload = evaluate_photo(b"bytes", include_authenticity=False)
    detect.assert_not_called()
    assert payload is not None
    assert payload.get("authenticity_deferred") is True
    assert payload["analysis"]["quality_engine"] == QUALITY_ENGINE_MUSIQ_WORKER
