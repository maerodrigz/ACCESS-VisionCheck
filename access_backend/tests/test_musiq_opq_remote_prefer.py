"""Shadow MUSIQ prefers remote worker when configured."""

from __future__ import annotations

import numpy as np
import pytest

from app.services.quality_shadow import musiq_opq


def _jpeg() -> bytes:
    import cv2

    img = np.zeros((24, 24, 3), dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    return buf.tobytes()


def test_score_prefers_remote_worker(monkeypatch):
    musiq_opq.reset_musiq_loader_for_tests()
    monkeypatch.setattr(
        "app.config.settings.musiq_worker_prefer_remote",
        True,
    )
    monkeypatch.setattr(
        "app.services.musiq_worker_client.musiq_worker_configured",
        lambda: True,
    )
    monkeypatch.setattr(
        "app.services.musiq_worker_client.evaluate_bytes",
        lambda *a, **k: {
            "status": "ok",
            "musiq": {
                "status": "ok",
                "musiq_opq_raw": 53.52,
                "musiq_scale": "approx_0_100_mos_like",
                "model_id": "tfhub:google/musiq/paq2piq/1",
                "engine_handle": "https://tfhub.dev/google/musiq/paq2piq/1",
                "error": None,
            },
        },
    )
    out = musiq_opq.score_image_bytes_musiq(_jpeg())
    assert out["status"] == "ok"
    assert out["musiq_opq_raw"] == pytest.approx(53.52)
    assert out.get("source") == "musiq_worker"
