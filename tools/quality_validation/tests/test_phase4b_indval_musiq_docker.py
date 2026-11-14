"""Tests for INDVAL Docker MUSIQ runner: failure handling + output isolation."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import httpx
import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

import run_phase4b_indval_musiq_docker as runner  # noqa: E402


def _jpeg_bytes(tag: bytes = b"x") -> bytes:
    # Minimal valid-enough JPEG header + payload for hashing / upload tests.
    return (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
        + tag
        + b"\xff\xd9"
    )


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _ok_musiq_body(score: float = 71.5) -> dict:
    return {
        "status": "ok",
        "worker_version": "1.0.0",
        "classical_map_version": "phase9_a_priori_equal_bin_v1",
        "duration_ms": 12.0,
        "soft_score_applied_to_musiq": False,
        "production_payload_mutated": False,
        "musiq": {
            "status": "ok",
            "musiq_opq_raw": score,
            "musiq_scale": runner.EXPECTED_SCALE,
            "model_id": runner.EXPECTED_MODEL_ID,
            "model_version": runner.EXPECTED_MODEL_VERSION,
            "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
            "error": None,
        },
        "criteria_q": {"sharpness": 0.5},
        "criteria_badge_equal_bin": {"sharpness": 3},
        "criteria_raw": {},
    }


def test_assert_output_isolation_rejects_root_and_bad_names(tmp_path: Path) -> None:
    root = tmp_path / "machine_output"
    root.mkdir()
    with pytest.raises(SystemExit, match="subdirectory"):
        runner.assert_output_isolation(root, root)
    with pytest.raises(SystemExit, match="musiq_live_docker_"):
        runner.assert_output_isolation(root / "other_dir", root)
    with pytest.raises(SystemExit, match="direct child"):
        runner.assert_output_isolation(root / "nested" / "musiq_live_docker_x", root)
    # Valid name under root is accepted
    runner.assert_output_isolation(root / "musiq_live_docker_test", root)


def test_musiq_score_ok_requires_status_and_finite() -> None:
    good = {
        "status": "ok",
        "musiq_opq_raw": 70.0,
        "model_id": runner.EXPECTED_MODEL_ID,
        "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
    }
    assert runner.musiq_score_ok(good)
    assert not runner.musiq_score_ok({**good, "status": "unavailable"})
    assert not runner.musiq_score_ok({**good, "musiq_opq_raw": None})
    assert not runner.musiq_score_ok({**good, "musiq_opq_raw": float("nan")})
    assert not runner.musiq_score_ok({**good, "model_id": "other"})
    assert not runner.musiq_score_ok(None)


def test_flatten_never_imputes_failed_score() -> None:
    rec = {
        "media_id": "INDVAL-001",
        "filename": "a.jpg",
        "path": "/a.jpg",
        "http_status": 200,
        "client_error": None,
        "wall_ms": 10,
        "raw": {
            "status": "partial",
            "musiq": {"status": "unavailable", "musiq_opq_raw": None, "error": "down"},
        },
    }
    flat = runner.flatten_musiq_row(
        rec,
        {
            "indval_id": "INDVAL-001",
            "source_media_key": "a.jpg",
            "file_sha256": "abc",
            "path": "/a.jpg",
        },
    )
    assert flat["musiq_opq_raw"] is None
    assert flat["musiq_finite_ok"] is False
    assert flat["cached_musiq_csv_used"] is False
    assert flat["fabricated_or_imputed"] is False
    assert runner.failed_row_from(flat) is not None


def test_check_ready_rejects_wrong_model() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/ready")
        return httpx.Response(
            200,
            json={
                "status": "ready",
                "musiq_ready": True,
                "model_id": "wrong-model",
                "model_version": runner.EXPECTED_MODEL_VERSION,
                "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
            },
        )

    transport = httpx.MockTransport(handler)
    # Patch Client used inside check_ready via monkeypatch of module httpx would be heavy;
    # call through a thin wrapper by temporarily replacing httpx.Client.
    real_client = httpx.Client

    class _C(real_client):
        def __init__(self, *a, **k):
            k["transport"] = transport
            super().__init__(*a, **k)

    original = runner.httpx.Client
    runner.httpx.Client = _C  # type: ignore[misc]
    try:
        with pytest.raises(SystemExit, match="unexpected model_id"):
            runner.check_ready("http://worker.test", 5.0)
    finally:
        runner.httpx.Client = original  # type: ignore[misc]


def test_check_ready_rejects_unavailable() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, text="not ready")

    transport = httpx.MockTransport(handler)

    class _C(httpx.Client):
        def __init__(self, *a, **k):
            k["transport"] = transport
            super().__init__(*a, **k)

    original = runner.httpx.Client
    runner.httpx.Client = _C  # type: ignore[misc]
    try:
        with pytest.raises(SystemExit, match="do not substitute"):
            runner.check_ready("http://worker.test", 5.0)
    finally:
        runner.httpx.Client = original  # type: ignore[misc]


def test_smoke_failure_refuses_batch_and_isolates_machine_scores(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "machine_output"
    root.mkdir()
    protected = root / "machine_scores.csv"
    protected.write_text("indval_id,hybrid_q_sharpness\nINDVAL-001,0.9\n", encoding="utf-8")
    before = protected.read_text(encoding="utf-8")

    img_dir = tmp_path / "images"
    img_dir.mkdir()
    manifest_rows = []
    for i in range(1, 101):
        data = _jpeg_bytes(f"{i:03d}".encode())
        p = img_dir / f"src_{i:03d}.jpg"
        p.write_bytes(data)
        manifest_rows.append(
            {
                "indval_id": f"INDVAL-{i:03d}",
                "blind_file_name": f"INDVAL-{i:03d}.jpg",
                "source_media_key": p.name,
                "pool": "test",
                "path": str(p),
                "mos_quality_raw": "3",
                "koniq_media_id": f"K-{i}",
                "file_sha256": _sha(data),
            }
        )
    manifest = tmp_path / "holdout_manifest.csv"
    keys = list(manifest_rows[0].keys())
    with manifest.open("w", encoding="utf-8", newline="") as f:
        import csv

        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(manifest_rows)

    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/ready"):
            return httpx.Response(
                200,
                json={
                    "status": "ready",
                    "musiq_ready": True,
                    "model_id": runner.EXPECTED_MODEL_ID,
                    "model_version": runner.EXPECTED_MODEL_VERSION,
                    "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
                },
            )
        if request.url.path.endswith("/v1/evaluate"):
            calls["n"] += 1
            # Force smoke failure: unavailable MUSIQ, no fabricated score
            return httpx.Response(
                200,
                json={
                    "status": "partial",
                    "musiq": {
                        "status": "unavailable",
                        "musiq_opq_raw": None,
                        "model_id": runner.EXPECTED_MODEL_ID,
                        "model_version": runner.EXPECTED_MODEL_VERSION,
                        "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
                        "error": "model_down",
                    },
                },
            )
        return httpx.Response(404)

    transport = httpx.MockTransport(handler)

    class _C(httpx.Client):
        def __init__(self, *a, **k):
            k["transport"] = transport
            super().__init__(*a, **k)

    monkeypatch.setattr(runner.httpx, "Client", _C)
    monkeypatch.setattr(runner, "MACHINE_SCORES_CSV", protected)
    monkeypatch.setenv("MUSIQ_WORKER_TOKEN", "test-token")

    code = runner.main(
        [
            "--manifest",
            str(manifest),
            "--output-root",
            str(root),
            "--worker-url",
            "http://worker.test",
            "--run-tag",
            "unitfail",
            "--timeout-sec",
            "5",
        ]
    )
    assert code == 3
    assert protected.read_text(encoding="utf-8") == before

    out = root / "musiq_live_docker_unitfail"
    assert out.is_dir()
    meta = json.loads((out / "run_meta.json").read_text(encoding="utf-8"))
    assert meta["cached_musiq_csv_used"] is False
    assert meta["preserves_machine_scores_csv"] is True
    assert "smoke" in meta["blocker"].lower() or "smoke" in str(meta.get("blocker", "")).lower()
    smoke = json.loads((out / "smoke_test_3.json").read_text(encoding="utf-8"))
    assert smoke["all_pass"] is False
    assert (out / "musiq_live_scores.csv").is_file()
    failed_txt = (out / "failed_or_partial.csv").read_text(encoding="utf-8")
    assert "batch_not_run" in failed_txt
    assert (out / "live_evaluations.jsonl").is_file()
    # Smoke does 3 images × 2 passes; must not proceed to full 100
    assert calls["n"] == 6


def test_successful_limited_run_writes_artifacts_only_in_new_dir(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "machine_output"
    root.mkdir()
    protected = root / "machine_scores.csv"
    protected.write_text("keep,me\n1,2\n", encoding="utf-8")
    before = protected.read_bytes()

    img_dir = tmp_path / "images"
    img_dir.mkdir()
    manifest_rows = []
    for i in range(1, 101):
        data = _jpeg_bytes(f"{i:03d}".encode())
        p = img_dir / f"src_{i:03d}.jpg"
        p.write_bytes(data)
        manifest_rows.append(
            {
                "indval_id": f"INDVAL-{i:03d}",
                "blind_file_name": f"INDVAL-{i:03d}.jpg",
                "source_media_key": p.name,
                "pool": "test",
                "path": str(p),
                "mos_quality_raw": "3",
                "koniq_media_id": f"K-{i}",
                "file_sha256": _sha(data),
            }
        )
    manifest = tmp_path / "holdout_manifest.csv"
    keys = list(manifest_rows[0].keys())
    with manifest.open("w", encoding="utf-8", newline="") as f:
        import csv

        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(manifest_rows)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/ready"):
            return httpx.Response(
                200,
                json={
                    "status": "ready",
                    "musiq_ready": True,
                    "model_id": runner.EXPECTED_MODEL_ID,
                    "model_version": runner.EXPECTED_MODEL_VERSION,
                    "engine_handle": runner.EXPECTED_ENGINE_HANDLE,
                },
            )
        if request.url.path.endswith("/v1/evaluate"):
            return httpx.Response(200, json=_ok_musiq_body(72.25))
        return httpx.Response(404)

    transport = httpx.MockTransport(handler)

    class _C(httpx.Client):
        def __init__(self, *a, **k):
            k["transport"] = transport
            super().__init__(*a, **k)

    monkeypatch.setattr(runner.httpx, "Client", _C)
    monkeypatch.setattr(runner, "MACHINE_SCORES_CSV", protected)
    monkeypatch.setenv("MUSIQ_WORKER_TOKEN", "test-token")

    code = runner.main(
        [
            "--manifest",
            str(manifest),
            "--output-root",
            str(root),
            "--worker-url",
            "http://worker.test",
            "--run-tag",
            "unitok",
            "--limit",
            "4",
            "--timeout-sec",
            "5",
        ]
    )
    assert code == 0
    assert protected.read_bytes() == before

    out = root / "musiq_live_docker_unitok"
    for name in (
        "run_meta.json",
        "smoke_test_3.json",
        "live_evaluations.jsonl",
        "musiq_live_scores.csv",
        "failed_or_partial.csv",
    ):
        assert (out / name).is_file(), name

    meta = json.loads((out / "run_meta.json").read_text(encoding="utf-8"))
    assert meta["n_musiq_ok"] == 4
    assert meta["cached_musiq_csv_used"] is False
    assert meta["fabricated_or_imputed"] is False

    scores = (out / "musiq_live_scores.csv").read_text(encoding="utf-8")
    assert "INDVAL-001" in scores
    assert "72.25" in scores
    assert "True" in scores or "true" in scores.lower() or "musiq_finite_ok" in scores

    failed = (out / "failed_or_partial.csv").read_text(encoding="utf-8")
    assert "no_failed_or_partial_rows" in failed

    # Isolation: no extra writes beside protected file + new dir
    names = {p.name for p in root.iterdir()}
    assert names == {"machine_scores.csv", "musiq_live_docker_unitok"}


def test_sha_mismatch_aborts(tmp_path: Path) -> None:
    import csv

    rows = []
    for i in range(1, 101):
        data = _jpeg_bytes(f"{i:03d}".encode())
        p = tmp_path / f"i{i:03d}.jpg"
        p.write_bytes(data)
        rows.append(
            {
                "indval_id": f"INDVAL-{i:03d}",
                "blind_file_name": f"INDVAL-{i:03d}.jpg",
                "source_media_key": p.name,
                "pool": "t",
                "path": str(p),
                "mos_quality_raw": "1",
                "koniq_media_id": "K",
                "file_sha256": _sha(data) if i != 5 else ("deadbeef" * 8),
            }
        )
    manifest = tmp_path / "holdout_manifest.csv"
    with manifest.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    with pytest.raises(SystemExit, match="SHA-256 mismatch"):
        runner.load_and_verify_manifest(manifest)
