"""Worker API tests with mocked MUSIQ (no TensorFlow required)."""

from __future__ import annotations

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app import musiq_engine
from app.config import get_settings
from app.main import app


def _jpeg(color=(30, 60, 90)) -> bytes:
    import cv2

    img = np.zeros((48, 64, 3), dtype=np.uint8)
    img[:, :] = color
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    return buf.tobytes()


@pytest.fixture(autouse=True)
def _secure_token(monkeypatch):
    get_settings.cache_clear()
    monkeypatch.setenv("MUSIQ_WORKER_TOKEN", "test-token")
    monkeypatch.setenv("ALLOW_INSECURE_EMPTY_TOKEN", "false")
    monkeypatch.setenv("PRELOAD_MUSIQ", "false")
    get_settings.cache_clear()
    musiq_engine.reset_for_tests()
    yield
    musiq_engine.reset_for_tests()
    get_settings.cache_clear()


@pytest.fixture
def client(monkeypatch):
    # Avoid real TF preload during TestClient lifespan.
    monkeypatch.setenv("PRELOAD_MUSIQ", "false")
    get_settings.cache_clear()

    def _fake_load(*, tfhub_cache_dir: str, handle: str) -> None:
        return None

    monkeypatch.setattr("app.main.load_musiq", _fake_load)
    with TestClient(app) as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_ready_fails_without_model(client):
    r = client.get("/ready")
    assert r.status_code == 503


def test_evaluate_requires_auth(client):
    r = client.post(
        "/v1/evaluate",
        files={"file": ("a.jpg", _jpeg(), "image/jpeg")},
        data={"media_type": "photo"},
    )
    assert r.status_code == 401


def test_evaluate_photo_partial_without_musiq(client, monkeypatch):
    monkeypatch.setattr(
        "app.evaluate.score_image_bytes",
        lambda content: {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "model_version": "paq2piq/1",
            "engine_handle": None,
            "error": "not loaded",
        },
    )
    r = client.post(
        "/v1/evaluate",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("a.jpg", _jpeg(), "image/jpeg")},
        data={"media_type": "photo"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "partial"
    assert body["musiq"]["musiq_opq_raw"] is None
    assert body["criteria_q"] is not None
    assert body["experimental_feedback"]["feedback_ruleset_version"] == "hybrid_feedback_rules_v1"
    assert body["temporal_quality"]["preserved_on_backend"] is True


def test_evaluate_photo_ok_with_mocked_musiq(client, monkeypatch):
    monkeypatch.setattr(
        "app.evaluate.score_image_bytes",
        lambda content: {
            "status": "ok",
            "musiq_opq_raw": 78.79,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "model_version": "paq2piq/1",
            "engine_handle": "https://tfhub.dev/google/musiq/paq2piq/1",
            "error": None,
        },
    )
    # Mark ready for /ready symmetry (evaluate path uses mocked score).
    musiq_engine._predict_fn = object()  # noqa: SLF001
    musiq_engine._ready = True  # noqa: SLF001
    musiq_engine._engine_handle = "https://tfhub.dev/google/musiq/paq2piq/1"  # noqa: SLF001

    r = client.post(
        "/v1/evaluate",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("clear.jpg", _jpeg((200, 200, 200)), "image/jpeg")},
        data={"media_type": "photo"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["musiq"]["musiq_opq_raw"] == pytest.approx(78.79)
    assert body["musiq"]["model_id"] == "tfhub:google/musiq/paq2piq/1"
