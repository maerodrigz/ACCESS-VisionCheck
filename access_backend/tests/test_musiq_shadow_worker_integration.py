"""Shadow-mode integration with musiq_worker_client (mocked HTTP + pipeline isolation)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
import pytest

from app.services import musiq_worker_client as client
from app.services.quality_shadow.musiq_opq import reset_musiq_loader_for_tests
from app.services.quality_shadow.scoring import run_shadow_score
from app.services.quality_shadow.worker import (
    maybe_schedule_quality_shadow,
    shutdown_quality_shadow_executor,
)


def _jpeg() -> bytes:
    import cv2

    img = np.full((48, 48, 3), 130, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    return bytes(buf)


@pytest.fixture(autouse=True)
def _shadow_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    reset_musiq_loader_for_tests()
    shutdown_quality_shadow_executor(wait=True)
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", True)
    monkeypatch.setattr("app.config.settings.quality_engine", "enet")
    monkeypatch.setattr("app.config.settings.musiq_worker_prefer_remote", True)
    monkeypatch.setattr("app.config.settings.musiq_worker_url", "http://127.0.0.1:8080")
    monkeypatch.setattr("app.config.settings.musiq_worker_token", "dev-local-musiq-token")
    monkeypatch.setattr("app.config.settings.musiq_worker_timeout_sec", 5.0)
    monkeypatch.setattr("app.config.settings.musiq_worker_tls_verify", False)
    monkeypatch.setattr(
        "app.config.settings.quality_shadow_log_dir",
        str(tmp_path / "quality_shadow_logs"),
    )
    monkeypatch.setattr("app.config.settings.quality_shadow_anon_salt", "test-shadow-salt")
    yield
    shutdown_quality_shadow_executor(wait=True)
    reset_musiq_loader_for_tests()


def _worker_ok_body() -> dict[str, Any]:
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
        "classical_map_version": "phase9_a_priori_equal_bin_v1",
        "criteria_raw": {"sharpness_laplacian_var": 100.0},
        "criteria_q": {
            "sharpness": 0.8,
            "blur": 0.8,
            "brightness": 0.7,
            "contrast": 0.6,
            "blocking_artifacts": 0.9,
        },
        "criteria_badge_equal_bin": {
            "sharpness": 5,
            "blur": 5,
            "brightness": 4,
            "contrast": 4,
            "blocking_artifacts": 5,
        },
        "color": {"color_balance": {"available": True, "badge": 5}},
        "experimental_feedback": {
            "feedback_ruleset_version": "hybrid_feedback_rules_v1",
            "issue_count": 0,
            "research_only": True,
        },
        "duration_ms": 1234.5,
    }


class _FakeResp:
    def __init__(self, status_code: int = 200, body: Any = None, text: str = ""):
        self.status_code = status_code
        self._body = body if body is not None else {}
        self.text = text or json.dumps(self._body)

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise client.httpx.HTTPStatusError("err", request=None, response=self)

    def json(self) -> Any:
        return self._body


class _FakeHttp:
    def __init__(self, handler):
        self._handler = handler

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def post(self, *a, **k):
        return self._handler(*a, **k)

    def get(self, *a, **k):
        return self._handler(*a, **k)


def test_shadow_success_uses_worker_payload(monkeypatch: pytest.MonkeyPatch) -> None:
    def _post(*_a, **_k):
        return _FakeResp(200, _worker_ok_body())

    monkeypatch.setattr(client.httpx, "Client", lambda **k: _FakeHttp(_post))
    # Ensure local TF path is not required
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: (_ for _ in ()).throw(AssertionError("local musiq must not run")),
    )
    record = run_shadow_score(
        content=_jpeg(),
        evaluation_id=11,
        media_id=22,
        anon_salt="test-shadow-salt",
    )
    assert record["status"] == "ok"
    assert record["musiq_status"] == "ok"
    assert record["musiq_opq_raw"] == pytest.approx(78.79)
    assert record["musiq_source"] == "musiq_worker"
    assert record["duration_ms_worker"] == pytest.approx(1234.5)
    assert record["criteria_q"]["sharpness"] == pytest.approx(0.8)
    assert record["experimental_feedback"]["feedback_ruleset_version"] == "hybrid_feedback_rules_v1"
    assert record["production_payload_mutated"] is False
    assert record["quality_engine_production"] == "enet"
    assert client.production_uses_enet() is True


def test_worker_unavailable_keeps_classical_partial(monkeypatch: pytest.MonkeyPatch) -> None:
    def _post(*_a, **_k):
        raise client.httpx.ConnectError("connection refused")

    monkeypatch.setattr(client.httpx, "Client", lambda **k: _FakeHttp(_post))
    record = run_shadow_score(
        content=_jpeg(),
        evaluation_id=1,
        media_id=2,
        anon_salt="test-shadow-salt",
    )
    assert record["musiq_status"] == "unavailable"
    assert record["musiq_opq_raw"] is None
    assert record["musiq_source"] == "musiq_worker"
    assert record["criteria_q"] is not None
    assert record["status"] == "partial"
    assert "offline" in (record["error"] or "") or "worker" in (record["error"] or "")


def test_worker_auth_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    def _post(*_a, **_k):
        return _FakeResp(401, {"detail": "Invalid bearer token"}, text="Invalid bearer token")

    monkeypatch.setattr(client.httpx, "Client", lambda **k: _FakeHttp(_post))
    out = client.evaluate_bytes(_jpeg())
    assert out["musiq"]["musiq_opq_raw"] is None
    assert out["error"] == "worker_auth_failed_401"

    record = run_shadow_score(
        content=_jpeg(),
        evaluation_id=3,
        media_id=4,
        anon_salt="test-shadow-salt",
    )
    assert record["musiq_opq_raw"] is None
    assert record["error"] == "worker_auth_failed_401"
    assert record["criteria_q"] is not None


def test_worker_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def _post(*_a, **_k):
        raise client.httpx.TimeoutException("timed out")

    monkeypatch.setattr(client.httpx, "Client", lambda **k: _FakeHttp(_post))
    out = client.evaluate_bytes(_jpeg())
    assert out["error"] == "worker_timeout"
    assert out["musiq"]["musiq_opq_raw"] is None

    record = run_shadow_score(
        content=_jpeg(),
        evaluation_id=5,
        media_id=6,
        anon_salt="test-shadow-salt",
    )
    assert record["musiq_opq_raw"] is None
    assert record["error"] == "worker_timeout"
    assert record["production_payload_mutated"] is False


def test_production_payload_preserved(monkeypatch: pytest.MonkeyPatch) -> None:
    production = {
        "overall_score": 4.2,
        "criteria": [{"name": "Sharpness", "score": 5}],
        "ai_feedback": "keep shooting",
        "recommendation": "Good",
        "ai_detection": {"label": "human", "probability": 0.1},
    }
    snap = json.dumps(production, sort_keys=True)

    def _post(*_a, **_k):
        return _FakeResp(200, _worker_ok_body())

    monkeypatch.setattr(client.httpx, "Client", lambda **k: _FakeHttp(_post))
    _ = run_shadow_score(
        content=_jpeg(),
        evaluation_id=9,
        media_id=10,
        anon_salt="test-shadow-salt",
    )
    assert json.dumps(production, sort_keys=True) == snap
    assert client.quality_engine() == "enet"
    assert client.production_uses_enet() is True


def test_shadow_flag_off_skips_worker(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", False)
    called = {"n": 0}

    def _boom(*_a, **_k):
        called["n"] += 1
        raise AssertionError("evaluate_bytes must not run when shadow disabled")

    monkeypatch.setattr(client, "evaluate_bytes", _boom)
    assert (
        maybe_schedule_quality_shadow(
            evaluation_id=1,
            media_id=2,
            file_bytes=_jpeg(),
            is_photo=True,
        )
        is False
    )
    assert called["n"] == 0
