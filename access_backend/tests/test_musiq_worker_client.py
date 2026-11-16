"""Unit tests for the remote MUSIQ worker client (mocked HTTP)."""

from __future__ import annotations

import numpy as np
import pytest

from app.services import musiq_worker_client as client


def _tiny_jpeg() -> bytes:
    import cv2

    img = np.zeros((32, 32, 3), dtype=np.uint8)
    img[:, :] = (40, 80, 120)
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    return buf.tobytes()


@pytest.fixture(autouse=True)
def _reset_settings(monkeypatch):
    monkeypatch.setattr(client.settings, "musiq_worker_url", "")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "")
    monkeypatch.setattr(client.settings, "musiq_worker_timeout_sec", 5.0)
    monkeypatch.setattr(client.settings, "musiq_worker_tls_verify", True)
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    monkeypatch.setattr(client.settings, "musiq_worker_prefer_remote", True)


def test_not_configured_returns_unavailable():
    out = client.evaluate_bytes(_tiny_jpeg())
    assert out["status"] == "unavailable"
    assert out["musiq"]["musiq_opq_raw"] is None
    assert out["production_payload_mutated"] is False
    assert client.quality_engine() == "musiq_worker"


def test_quality_engine_is_musiq_worker(monkeypatch):
    monkeypatch.setattr(client.settings, "quality_engine", "musiq_worker")
    assert client.quality_engine() == "musiq_worker"


def test_evaluate_bytes_maps_ok_response(monkeypatch):
    monkeypatch.setattr(client.settings, "musiq_worker_url", "https://worker.test")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "secret-token")

    class _Resp:
        status_code = 200

        def raise_for_status(self):
            return None

        def json(self):
            return {
                "status": "ok",
                "media_type": "photo",
                "musiq": {
                    "status": "ok",
                    "musiq_opq_raw": 78.79,
                    "musiq_scale": "approx_0_100_mos_like",
                    "model_id": "tfhub:google/musiq/paq2piq/1",
                    "model_version": "paq2piq/1",
                    "engine_handle": "https://tfhub.dev/google/musiq/paq2piq/1",
                    "error": None,
                },
                "criteria_q": {"sharpness": 0.9},
                "experimental_feedback": {"issue_count": 0},
                "duration_ms": 12.5,
            }

    class _Http:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def post(self, *a, **k):
            return _Resp()

    monkeypatch.setattr(client.httpx, "Client", _Http)
    out = client.evaluate_bytes(_tiny_jpeg(), filename="clear.jpg")
    assert out["status"] == "ok"
    assert out["musiq"]["musiq_opq_raw"] == pytest.approx(78.79)
    assert out["production_payload_mutated"] is False
    mapped = client.musiq_opq_from_worker_result(out)
    assert mapped["status"] == "ok"
    assert mapped["source"] == "musiq_worker"


def test_timeout_does_not_invent_score(monkeypatch):
    monkeypatch.setattr(client.settings, "musiq_worker_url", "https://worker.test")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "secret-token")

    class _Http:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def post(self, *a, **k):
            raise client.httpx.TimeoutException("slow")

    monkeypatch.setattr(client.httpx, "Client", _Http)
    out = client.evaluate_bytes(_tiny_jpeg())
    assert out["status"] == "unavailable"
    assert out["musiq"]["musiq_opq_raw"] is None
    assert "timeout" in (out["error"] or "")


def test_offline_does_not_invent_score(monkeypatch):
    monkeypatch.setattr(client.settings, "musiq_worker_url", "https://worker.test")
    monkeypatch.setattr(client.settings, "musiq_worker_token", "secret-token")

    class _Http:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def post(self, *a, **k):
            raise client.httpx.ConnectError("down")

    monkeypatch.setattr(client.httpx, "Client", _Http)
    out = client.evaluate_bytes(_tiny_jpeg())
    assert out["musiq"]["musiq_opq_raw"] is None
    assert "offline" in (out["error"] or "")
