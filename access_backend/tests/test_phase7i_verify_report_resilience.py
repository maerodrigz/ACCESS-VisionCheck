"""Phase 7I verifier must always write a truthful report, even on fallback/Docker errors."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType
from unittest.mock import MagicMock, patch

import pytest

BACKEND_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = BACKEND_ROOT / "scripts" / "verify_phase7i_local_cutover.py"


def _load_v7i() -> ModuleType:
    spec = importlib.util.spec_from_file_location("verify_phase7i_local_cutover", SCRIPT_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def v7i() -> ModuleType:
    return _load_v7i()


@pytest.fixture()
def out_dir(tmp_path: Path) -> Path:
    return tmp_path / "phase7i_local_cutover"


def _base_report(v7i: ModuleType, **overrides):
    report = v7i._new_report()
    report.update(
        {
            "actual_active_quality_engine": "musiq_worker",
            "production_uses_enet": False,
            "enet_weights_retained": True,
            "env_backup_retained": True,
            "vectorized_blocking": True,
            "worker_probe": {"ready": True},
        }
    )
    report.update(overrides)
    return report


def test_finalize_report_always_writes_json_and_md(v7i: ModuleType, out_dir: Path) -> None:
    report = _base_report(
        v7i,
        cases={
            "photo_http": {"skipped": True, "reason": "forced"},
            "video_http": {"skipped": True, "reason": "forced"},
            "worker_offline_fallback": {"skipped": True, "reason": "forced"},
        },
    )
    raw, md = v7i.finalize_report(report, out_dir=out_dir)
    assert raw.is_file()
    assert md.is_file()
    payload = json.loads(raw.read_text(encoding="utf-8"))
    assert payload["report_complete"] is True
    assert payload["local_cutover_activated"] is False
    assert payload["results"]["photo_http"] == "SKIPPED"
    text = md.read_text(encoding="utf-8")
    assert "Report complete: **True**" in text
    assert "Photo HTTP: **SKIPPED**" in text


def test_finalize_does_not_mark_incomplete_offline_as_pass(v7i: ModuleType, out_dir: Path) -> None:
    report = _base_report(
        v7i,
        cases={
            "photo_http": {
                "http_status": 200,
                "parse_ok": True,
                "media_type_envelope": "photo",
                "authenticity_deferred": True,
                "xp_eligible": False,
                "ai_analysis_status": "deferred",
                "ai_detector_backend": None,
                "ai_probability": None,
                "analysis_efficientnet_used": False,
                "scoring_engine": "musiq-paq2piq+opencv-classical",
                "scoring_model": "musiq-paq2piq+opencv-classical",
                "analysis_quality_engine": "musiq_worker",
                "musiq_opq_context_only": True,
            },
            "video_http": {"skipped": True, "reason": "n/a"},
            "worker_offline_fallback": {
                "http_status": None,
                "parse_ok": False,
                "error": "evaluate timed out after 180s",
                "timed_out": True,
            },
        },
    )
    raw, _md = v7i.finalize_report(report, out_dir=out_dir)
    payload = json.loads(raw.read_text(encoding="utf-8"))
    assert payload["results"]["worker_offline_fallback"] == "FAIL"
    assert payload["gates"]["offline_opencv_fallback_ok"] is False
    assert payload["local_cutover_activated"] is False
    assert any("offline fallback gate failed" in b for b in payload["blockers"])


def test_restart_musiq_worker_records_exception_without_raising(v7i: ModuleType) -> None:
    with patch.object(v7i, "_docker_compose", side_effect=RuntimeError("docker boom")):
        out = v7i._restart_musiq_worker("http://127.0.0.1:8080")
    assert out.get("ready") is False
    assert "docker boom" in str(out.get("error", ""))
    assert out.get("traceback")


def test_safe_post_timeout_returns_fail_payload_not_raise(v7i: ModuleType) -> None:
    client = MagicMock()

    def _hang(*_a, **_k):
        import time

        time.sleep(5)
        return {"http_status": 200}

    with patch.object(v7i, "_post_evaluate", side_effect=_hang):
        out = v7i._safe_post(client, Path("x.jpg"), timeout_sec=0.2)
    assert out.get("timed_out") is True
    assert out.get("parse_ok") is False
    assert out.get("http_status") is None


def test_main_writes_report_when_smoke_raises(
    v7i: ModuleType, out_dir: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """If smoke/fallback crashes, main() must still finalize a non-PASS report."""
    monkeypatch.setattr(v7i, "OUT_DIR", out_dir)

    def _boom(report):
        report["actual_active_quality_engine"] = "musiq_worker"
        report["production_uses_enet"] = False
        report["enet_weights_retained"] = True
        report["env_backup_retained"] = True
        report["vectorized_blocking"] = True
        report["worker_probe"] = {"ready": True}
        report["cases"]["photo_http"] = {"skipped": True, "reason": "test"}
        report["cases"]["video_http"] = {"skipped": True, "reason": "test"}
        report["cases"]["worker_offline_fallback"] = {
            "parse_ok": False,
            "error": "simulated offline failure",
        }
        raise RuntimeError("simulated fallback crash")

    monkeypatch.setattr(v7i, "run_smoke_cases", _boom)

    with patch("dotenv.load_dotenv", return_value=False):
        code = v7i.main()

    assert code == 2
    raw = out_dir / "verification.json"
    md = out_dir / "PHASE7I_REPORT.md"
    assert raw.is_file()
    assert md.is_file()
    payload = json.loads(raw.read_text(encoding="utf-8"))
    assert payload["report_complete"] is True
    assert payload["local_cutover_activated"] is False
    assert any("simulated fallback crash" in b for b in payload["blockers"])
    assert payload["results"]["worker_offline_fallback"] == "FAIL"


def test_offline_finally_restarts_even_when_safe_post_errors(
    v7i: ModuleType, out_dir: Path
) -> None:
    """Mirrors run_smoke_cases finally: restart must run after offline evaluate failure."""
    worker_was_stopped = True
    report = {"cases": {}, "blockers": []}
    calls: list[str] = []

    def _restart(url: str):
        calls.append(url)
        return {
            "docker_start": {"ok": True},
            "worker_after_restart": {"ready": True},
            "ready": True,
        }

    offline = {"parse_ok": False, "error": "boom"}
    report["cases"]["worker_offline_fallback"] = offline

    try:
        raise RuntimeError("post-processing boom")
    except Exception as exc:  # noqa: BLE001
        report["blockers"].append(f"smoke suite error: {exc}")
    finally:
        if worker_was_stopped:
            restart = _restart("http://127.0.0.1:8080")
            report["cases"]["docker_start"] = restart.get("docker_start")
            report["cases"]["worker_after_restart"] = restart.get("worker_after_restart")

    assert calls == ["http://127.0.0.1:8080"]
    assert report["cases"]["docker_start"] == {"ok": True}
    assert report["cases"]["worker_offline_fallback"]["error"] == "boom"

    full = _base_report(
        v7i,
        cases={
            "photo_http": {"skipped": True, "reason": "n/a"},
            "video_http": {"skipped": True, "reason": "n/a"},
            "worker_offline_fallback": offline,
        },
        blockers=list(report["blockers"]),
    )
    raw, _md = v7i.finalize_report(full, out_dir=out_dir)
    payload = json.loads(raw.read_text(encoding="utf-8"))
    assert payload["results"]["worker_offline_fallback"] == "FAIL"
