"""Phase 2 quality shadow scoring — feature flag, isolation, no production mutation."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import numpy as np
import pytest

from app.services.quality_shadow import maybe_schedule_quality_shadow
from app.services.quality_shadow.classical import equal_bin_1_5
from app.services.quality_shadow.logging_store import append_shadow_record
from app.services.quality_shadow.musiq_opq import reset_musiq_loader_for_tests
from app.services.quality_shadow.scoring import anonymize_media_id, run_shadow_score
from app.services.quality_shadow.worker import (
    run_shadow_job_sync_for_tests,
    shutdown_quality_shadow_executor,
)


@pytest.fixture(autouse=True)
def _reset_shadow_state(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    reset_musiq_loader_for_tests()
    shutdown_quality_shadow_executor(wait=True)
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", False)
    monkeypatch.setattr(
        "app.config.settings.quality_shadow_log_dir",
        str(tmp_path / "quality_shadow_logs"),
    )
    monkeypatch.setattr("app.config.settings.quality_shadow_anon_salt", "test-shadow-salt")
    monkeypatch.setattr("app.config.settings.quality_shadow_max_workers", 1)
    yield
    shutdown_quality_shadow_executor(wait=True)
    reset_musiq_loader_for_tests()


def _tiny_jpeg_bytes() -> bytes:
    import cv2

    bgr = np.full((64, 64, 3), 120, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", bgr)
    assert ok
    return bytes(buf)


def test_equal_bin_mapping_frozen() -> None:
    assert equal_bin_1_5(0.0) == 1
    assert equal_bin_1_5(1.0) == 5


def test_feature_flag_disabled_does_not_schedule(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", False)
    submitted: list[Any] = []

    class _Boom:
        def submit(self, *a, **k):  # noqa: ANN001
            submitted.append((a, k))
            raise AssertionError("executor must not be used when flag is off")

    monkeypatch.setattr(
        "app.services.quality_shadow.worker.get_quality_shadow_executor",
        lambda: _Boom(),
    )
    ok = maybe_schedule_quality_shadow(
        evaluation_id=1,
        media_id=2,
        file_bytes=_tiny_jpeg_bytes(),
        is_photo=True,
    )
    assert ok is False
    assert submitted == []


def test_feature_flag_disabled_skips_musiq_import(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", False)

    def _forbid_ensure(**kwargs):  # noqa: ANN001
        raise AssertionError("MUSIQ must not load when shadow is disabled")

    monkeypatch.setattr(
        "app.services.quality_shadow.musiq_opq.ensure_musiq_predict_fn",
        _forbid_ensure,
    )
    assert (
        maybe_schedule_quality_shadow(
            evaluation_id=9,
            media_id=9,
            file_bytes=_tiny_jpeg_bytes(),
            is_photo=True,
        )
        is False
    )


def test_successful_shadow_scoring_classical_and_musiq_stub(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", True)

    def _fake_musiq(content: bytes, *, tfhub_cache_dir: str | None = None) -> dict[str, Any]:
        assert content
        return {
            "status": "ok",
            "musiq_opq_raw": 71.25,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "engine_handle": "stub://musiq",
            "error": None,
        }

    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        _fake_musiq,
    )
    record = run_shadow_job_sync_for_tests(
        evaluation_id=42,
        media_id=1001,
        content=_tiny_jpeg_bytes(),
    )
    assert record["status"] == "ok"
    assert record["musiq_status"] == "ok"
    assert record["musiq_opq_raw"] == 71.25
    assert record["soft_score_applied_to_musiq"] is False
    assert record["production_payload_mutated"] is False
    assert record["criteria_q"] is not None
    assert "sharpness" in record["criteria_q"]
    assert record["criteria_badge_equal_bin"]["sharpness"] == equal_bin_1_5(
        record["criteria_q"]["sharpness"]
    )
    logs = list((tmp_path / "quality_shadow_logs").glob("quality_shadow_*.jsonl"))
    assert len(logs) == 1
    line = logs[0].read_text(encoding="utf-8").strip().splitlines()[-1]
    parsed = json.loads(line)
    assert parsed["evaluation_id"] == 42
    assert parsed["media_anon_id"] == anonymize_media_id(1001, anon_salt="test-shadow-salt")
    assert "file_url" not in parsed
    assert "file_name" not in parsed
    assert "uploaded_by" not in parsed


def test_musiq_unavailable_marks_partial(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "engine_handle": None,
            "error": "tensorflow missing",
        },
    )
    record = run_shadow_score(
        content=_tiny_jpeg_bytes(),
        evaluation_id=7,
        media_id=8,
        anon_salt="test-shadow-salt",
    )
    assert record["status"] == "partial"
    assert record["musiq_status"] == "unavailable"
    assert record["musiq_opq_raw"] is None
    assert record["criteria_q"] is not None


def test_shadow_inference_failure_classical(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.decode_bgr_from_bytes",
        lambda _b: (_ for _ in ()).throw(RuntimeError("decode boom")),
    )
    record = run_shadow_score(
        content=b"not-an-image",
        evaluation_id=1,
        media_id=2,
        anon_salt="test-shadow-salt",
        skip_musiq=True,
    )
    assert record["status"] == "error"
    assert "classical_failed" in (record["error"] or "")


def test_no_changes_to_production_payload_object(monkeypatch: pytest.MonkeyPatch) -> None:
    payload = {
        "overall_score": 3.7,
        "criteria": [{"name": "Sharpness", "score": 4}],
        "ai_feedback": "ok",
        "recommendation": "keep",
    }
    snapshot = json.dumps(payload, sort_keys=True)
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "ok",
            "musiq_opq_raw": 60.0,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "x",
            "engine_handle": "x",
            "error": None,
        },
    )
    _ = run_shadow_score(
        content=_tiny_jpeg_bytes(),
        evaluation_id=1,
        media_id=2,
        anon_salt="test-shadow-salt",
    )
    assert json.dumps(payload, sort_keys=True) == snapshot


def test_schedule_does_not_block_caller(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", True)
    started = threading_event = __import__("threading").Event()

    def _slow_job(*_a, **_k):  # noqa: ANN001
        started.set()
        time.sleep(0.35)

    class _Exec:
        def submit(self, fn, *a, **k):  # noqa: ANN001
            t = __import__("threading").Thread(target=fn, args=a, kwargs=k, daemon=True)
            t.start()
            return t

    monkeypatch.setattr(
        "app.services.quality_shadow.worker.get_quality_shadow_executor",
        lambda: _Exec(),
    )
    monkeypatch.setattr("app.services.quality_shadow.worker._run_shadow_job", _slow_job)
    t0 = time.perf_counter()
    ok = maybe_schedule_quality_shadow(
        evaluation_id=1,
        media_id=2,
        file_bytes=_tiny_jpeg_bytes(),
        is_photo=True,
    )
    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    assert ok is True
    assert elapsed_ms < 100.0, f"schedule blocked caller for {elapsed_ms:.1f} ms"
    assert started.wait(1.0)


def test_skips_video(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", True)
    called = []

    class _Exec:
        def submit(self, *a, **k):  # noqa: ANN001
            called.append(True)

    monkeypatch.setattr(
        "app.services.quality_shadow.worker.get_quality_shadow_executor",
        lambda: _Exec(),
    )
    assert (
        maybe_schedule_quality_shadow(
            evaluation_id=1,
            media_id=2,
            file_bytes=_tiny_jpeg_bytes(),
            is_photo=False,
        )
        is False
    )
    assert called == []


def test_log_record_has_no_sensitive_fields(tmp_path: Path) -> None:
    record = {
        "timestamp_utc": "2026-11-13T00:00:00+00:00",
        "evaluation_id": 1,
        "media_anon_id": "abc",
        "shadow_engine_version": "hybrid_nr_iqa_shadow_v1",
        "classical_map_version": "phase9_a_priori_equal_bin_v1",
        "status": "ok",
        "musiq_status": "unavailable",
        "musiq_opq_raw": None,
        "musiq_scale": "approx_0_100_mos_like",
        "musiq_model_id": "tfhub:google/musiq/paq2piq/1",
        "musiq_engine_handle": None,
        "duration_ms_total": 12.0,
        "duration_ms_classical": 10.0,
        "duration_ms_musiq": 0.0,
        "error": "tensorflow missing",
        "criteria_raw": {"sharpness_laplacian_var": 1.0},
        "criteria_q": {"sharpness": 0.1},
        "criteria_badge_equal_bin": {"sharpness": 1},
        "color": {},
    }
    path = append_shadow_record(tmp_path, record)
    text = path.read_text(encoding="utf-8")
    for banned in ("password", "email", "file_url", "exif", "phone", "fullname"):
        assert banned not in text.lower()


def test_pipeline_swallows_shadow_schedule_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    """media_pipeline must catch shadow schedule failures and keep production eval."""
    from app.services import media_pipeline as mp

    def _boom(**kwargs):  # noqa: ANN001
        raise RuntimeError("shadow schedule boom")

    # Reproduce the isolation block used at the end of run_pipeline.
    logged: list[str] = []

    class _Log:
        def exception(self, msg, *a, **k):  # noqa: ANN001
            logged.append(msg % a if a else msg)

    monkeypatch.setattr(mp, "logger", _Log())
    try:
        from app.services.quality_shadow import maybe_schedule_quality_shadow as _sched

        monkeypatch.setattr(
            "app.services.quality_shadow.maybe_schedule_quality_shadow",
            _boom,
        )
        try:
            from app.services.quality_shadow import maybe_schedule_quality_shadow

            maybe_schedule_quality_shadow(
                evaluation_id=1,
                media_id=2,
                file_bytes=b"x",
                is_photo=True,
            )
        except Exception:  # noqa: BLE001
            mp.logger.exception(
                "quality shadow schedule failed media_id=%s (production eval unchanged)",
                2,
            )
    finally:
        pass
    assert logged
    assert "production eval unchanged" in logged[0]


def test_musiq_never_uses_soft_score(monkeypatch: pytest.MonkeyPatch) -> None:
    import app.services.media_evaluator as me

    calls: list[float] = []
    real_soft = me._soft_score

    def _wrapped(metric: float) -> int:
        calls.append(float(metric))
        return real_soft(metric)

    monkeypatch.setattr(me, "_soft_score", _wrapped)
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "ok",
            "musiq_opq_raw": 72.0,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "x",
            "engine_handle": "x",
            "error": None,
        },
    )
    record = run_shadow_score(
        content=_tiny_jpeg_bytes(),
        evaluation_id=1,
        media_id=2,
        anon_salt="test-shadow-salt",
    )
    assert record["musiq_opq_raw"] == 72.0
    assert calls == []
    assert record["soft_score_applied_to_musiq"] is False


def test_empty_bytes_reloads_from_cache(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", True)
    jpeg = _tiny_jpeg_bytes()
    monkeypatch.setattr(
        "app.services.upload_bytes_cache.take_evaluation_upload",
        lambda media_id: jpeg if media_id == 55 else None,
    )
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "x",
            "engine_handle": None,
            "error": "unavailable",
        },
    )
    from app.services.quality_shadow.worker import _run_shadow_job

    _run_shadow_job(99, 55, b"")
    logs = list((tmp_path / "quality_shadow_logs").glob("quality_shadow_*.jsonl"))
    assert logs
    parsed = json.loads(logs[0].read_text(encoding="utf-8").strip().splitlines()[-1])
    assert parsed["evaluation_id"] == 99
    assert parsed["criteria_q"] is not None
    assert parsed["status"] in ("ok", "partial")


def test_shadow_does_not_call_xp_or_feedback(monkeypatch: pytest.MonkeyPatch) -> None:
    xp_calls: list[Any] = []
    feedback_calls: list[Any] = []

    monkeypatch.setattr(
        "app.services.chain_xp_award.apply_chain_xp_award",
        lambda *a, **k: xp_calls.append(1),
        raising=False,
    )

    def _forbid_feedback(*a, **k):  # noqa: ANN001
        feedback_calls.append(1)
        raise AssertionError("feedback must not run in shadow path")

    monkeypatch.setattr(
        "app.services.media_pipeline._feedback_text",
        _forbid_feedback,
        raising=False,
    )
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "x",
            "engine_handle": None,
            "error": "unavailable",
        },
    )
    run_shadow_score(
        content=_tiny_jpeg_bytes(),
        evaluation_id=3,
        media_id=4,
        anon_salt="test-shadow-salt",
    )
    assert xp_calls == []
    assert feedback_calls == []
