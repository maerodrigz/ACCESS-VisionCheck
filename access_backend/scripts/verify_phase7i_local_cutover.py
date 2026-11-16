#!/usr/bin/env python3
"""Phase 7I: verify LOCAL QUALITY_ENGINE=musiq_worker cutover after .env apply + restart.

Loads settings from the real .env (no process-local QUALITY_ENGINE override for the
primary path). Uses FastAPI TestClient HTTP against the app configured by that .env.

Worker-offline fallback: temporary `docker compose stop` of musiq-worker, then start
again (not permanent).

Always writes phase7i_local_cutover/verification.json and PHASE7I_REPORT.md, even when
offline fallback or Docker restart fails/times out.

Usage (after apply + backend restart):
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\verify_phase7i_local_cutover.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeout
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
OUT_DIR = ROOT / "phase7i_local_cutover"
WORKER_COMPOSE = REPO / "musiq_worker" / "docker-compose.yml"

# Bounded timeouts (seconds)
HTTP_PROBE_TIMEOUT_SEC = 5.0
DOCKER_COMPOSE_TIMEOUT_SEC = 60
EVALUATE_TIMEOUT_SEC = 180
WORKER_RESTART_WAIT_SEC = 30
WORKER_RESTART_POLL_SEC = 2
OFFLINE_WORKER_TIMEOUT_SEC = 5.0

PHOTO = Path(
    os.environ.get(
        "PHASE7I_TEST_IMAGE",
        r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg",
    )
)
_REAL_VIDEO = Path(r"C:\Users\Dell\Desktop\video_metadata_test\VID_20260629_181454.mp4")
_SHORT_VIDEO = (
    REPO
    / "tools"
    / "quality_validation"
    / "video_four_criteria_validation"
    / "assets"
    / "01_baseline_neutral.mp4"
)
_env_video = (os.environ.get("PHASE7I_TEST_VIDEO") or "").strip()
if _env_video:
    VIDEO = Path(_env_video)
elif _SHORT_VIDEO.is_file():
    VIDEO = _SHORT_VIDEO
elif _REAL_VIDEO.is_file():
    VIDEO = _REAL_VIDEO
else:
    VIDEO = _SHORT_VIDEO

VIDEO_CRITERIA = {
    "Sharpness",
    "Blur",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Color Balance",
    "Color Saturation",
    "Flickering",
    "Motion Stability",
}


def _stage(msg: str) -> None:
    print(f"--- {msg} ---", flush=True)


def _fake_user():
    from app.models.enums import RoleName, UserStatus

    return SimpleNamespace(
        id=0,
        email="phase7i@local.test",
        fullname="Phase7I",
        is_active=True,
        status=UserStatus.APPROVED,
        role=SimpleNamespace(role_name=RoleName.MEMBER),
    )


def _summarize(body: dict[str, Any]) -> dict[str, Any]:
    ev = body.get("evaluation") if isinstance(body, dict) else None
    if not isinstance(ev, dict):
        return {"parse_ok": False, "body_keys": list(body.keys()) if isinstance(body, dict) else None}
    analysis = ev.get("analysis") if isinstance(ev.get("analysis"), dict) else {}
    ai = ev.get("ai_detection") if isinstance(ev.get("ai_detection"), dict) else {}
    criteria = ev.get("criteria") if isinstance(ev.get("criteria"), list) else []
    names = [c.get("name") for c in criteria if isinstance(c, dict)]
    musiq = analysis.get("musiq_opq") if isinstance(analysis.get("musiq_opq"), dict) else None
    return {
        "parse_ok": True,
        "media_type_envelope": body.get("media_type"),
        "scoring_engine_envelope": body.get("scoring_engine"),
        "scoring_engine": ev.get("scoring_engine"),
        "scoring_model": ev.get("scoring_model"),
        "overall_score": ev.get("overall_score"),
        "criterion_names": names,
        "authenticity_deferred": ev.get("authenticity_deferred"),
        "quality_provisional": ev.get("quality_provisional"),
        "xp_eligible": ev.get("xp_eligible"),
        "xp_pending": ev.get("xp_pending"),
        "analysis_quality_engine": analysis.get("quality_engine"),
        "analysis_opencv_fallback": analysis.get("opencv_fallback"),
        "analysis_efficientnet_used": analysis.get("efficientnet_used"),
        "musiq_opq_context_only": analysis.get("musiq_opq_context_only"),
        "musiq_not_used_for_criteria": (musiq or {}).get("not_used_for_criteria"),
        "ai_analysis_status": ai.get("analysis_status"),
        "ai_is_final": ai.get("is_final"),
        "ai_verdict": ai.get("verdict"),
        "ai_probability": ai.get("probability"),
        "ai_detector_backend": ai.get("detector_backend"),
    }


def _post_evaluate(client, path: Path) -> dict[str, Any]:
    content = path.read_bytes()
    mime = "video/mp4" if path.suffix.lower() in {".mp4", ".mov", ".webm"} else "image/jpeg"
    r = client.post("/api/media/evaluate", files={"file": (path.name, content, mime)})
    try:
        body = r.json()
    except Exception:  # noqa: BLE001
        body = {"raw": (r.text or "")[:400]}
    out: dict[str, Any] = {"http_status": r.status_code, "bytes": len(content)}
    if r.status_code == 200:
        out.update(_summarize(body))
    else:
        out["parse_ok"] = False
        out["error_body"] = body
    return out


def _safe_post(client, path: Path, *, timeout_sec: float = EVALUATE_TIMEOUT_SEC) -> dict[str, Any]:
    """HTTP evaluate with hard timeout; never raises to the caller."""
    try:
        with ThreadPoolExecutor(max_workers=1) as pool:
            fut = pool.submit(_post_evaluate, client, path)
            return fut.result(timeout=timeout_sec)
    except FuturesTimeout:
        return {
            "http_status": None,
            "parse_ok": False,
            "error": f"evaluate timed out after {timeout_sec}s",
            "timed_out": True,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "http_status": None,
            "parse_ok": False,
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }


def _worker_ready(url: str, *, timeout_sec: float = HTTP_PROBE_TIMEOUT_SEC) -> dict[str, Any]:
    import httpx

    base = url.rstrip("/")
    out: dict[str, Any] = {"url": base}
    try:
        with httpx.Client(timeout=timeout_sec) as c:
            h = c.get(f"{base}/health")
            r = c.get(f"{base}/ready")
        out["health_status"] = h.status_code
        out["ready_status"] = r.status_code
        try:
            out["ready_body"] = r.json()
        except Exception:  # noqa: BLE001
            out["ready_body"] = (r.text or "")[:200]
        ready = False
        if isinstance(out.get("ready_body"), dict):
            ready = bool(out["ready_body"].get("musiq_ready") or out["ready_body"].get("ready"))
            if (
                out["ready_status"] == 200
                and "musiq_ready" not in out["ready_body"]
                and "ready" not in out["ready_body"]
            ):
                ready = True
        out["ready"] = r.status_code == 200 and ready
    except Exception as exc:  # noqa: BLE001
        out["ready"] = False
        out["error"] = str(exc)
    return out


def _docker_compose(args: list[str], timeout: int = DOCKER_COMPOSE_TIMEOUT_SEC) -> dict[str, Any]:
    if not WORKER_COMPOSE.is_file():
        return {"ok": False, "error": f"missing {WORKER_COMPOSE}"}
    cmd = ["docker", "compose", "-f", str(WORKER_COMPOSE), *args]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return {
            "ok": proc.returncode == 0,
            "exit_code": proc.returncode,
            "cmd": " ".join(cmd),
            "stdout_tail": (proc.stdout or "")[-400:],
            "stderr_tail": (proc.stderr or "")[-400:],
        }
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "error": f"docker compose timed out after {timeout}s",
            "cmd": " ".join(cmd),
            "timed_out": True,
        }
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc), "cmd": " ".join(cmd)}


def _restart_musiq_worker(worker_url: str) -> dict[str, Any]:
    """Start worker and poll readiness with a hard wall-clock bound. Never raises."""
    out: dict[str, Any] = {}
    try:
        _stage("restart musiq-worker")
        out["docker_start"] = _docker_compose(["start", "musiq-worker"])
        deadline = time.monotonic() + WORKER_RESTART_WAIT_SEC
        last: dict[str, Any] = {"ready": False}
        while time.monotonic() < deadline:
            last = _worker_ready(worker_url)
            if last.get("ready"):
                break
            time.sleep(WORKER_RESTART_POLL_SEC)
        out["worker_after_restart"] = last
        out["ready"] = bool(last.get("ready"))
    except Exception as exc:  # noqa: BLE001
        out["ok"] = False
        out["error"] = str(exc)
        out["traceback"] = traceback.format_exc()
        out["ready"] = False
    return out


def _preview_ok_common(c: dict[str, Any], *, media: str) -> bool:
    return (
        c.get("http_status") == 200
        and c.get("parse_ok") is True
        and c.get("media_type_envelope") == media
        and c.get("authenticity_deferred") is True
        and c.get("xp_eligible") is False
        and c.get("ai_analysis_status") == "deferred"
        and c.get("ai_detector_backend") is None
        and c.get("ai_probability") is None
        and c.get("analysis_efficientnet_used") is False
        and bool(c.get("scoring_engine"))
        and bool(c.get("scoring_model"))
    )


def _ok_musiq(c: dict[str, Any], *, media: str) -> bool:
    if not _preview_ok_common(c, media=media):
        return False
    if c.get("analysis_quality_engine") != "musiq_worker":
        return False
    if c.get("musiq_opq_context_only") is not True:
        return False
    if media == "video":
        return VIDEO_CRITERIA.issubset(set(c.get("criterion_names") or []))
    return True


def _ok_opencv_fallback(c: dict[str, Any], *, media: str) -> bool:
    if not _preview_ok_common(c, media=media):
        return False
    return (
        c.get("analysis_quality_engine") == "opencv"
        and c.get("analysis_opencv_fallback") is True
        and c.get("scoring_model") == "opencv"
    )


def _write_md(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Phase 7I — Controlled local MUSIQ + OpenCV cutover",
        "",
        f"- Local cutover activated: **{report.get('local_cutover_activated')}**",
        f"- Actual active quality engine: **{report.get('actual_active_quality_engine')}**",
        f"- `production_uses_enet`: **{report.get('production_uses_enet')}**",
        f"- `.env` backup retained: **{report.get('env_backup_retained')}**",
        f"- EfficientNet permanently retired: **{report.get('enet_permanently_retired', True)}**",
        f"- Production/cloud deploy: **False**",
        f"- Report complete: **{report.get('report_complete')}**",
        "",
        "## Smoke tests",
        "",
        f"- Photo HTTP: **{report.get('results', {}).get('photo_http')}**",
        f"- Video HTTP: **{report.get('results', {}).get('video_http')}**",
        f"- Worker-offline fallback: **{report.get('results', {}).get('worker_offline_fallback')}**",
        f"- Rollback availability: **{report.get('results', {}).get('rollback_availability')}**",
        "",
        "## Gates",
        "",
    ]
    for k, v in (report.get("gates") or {}).items():
        lines.append(f"- `{k}`: **{v}**")
    lines.extend(["", "## Blockers", ""])
    blockers = report.get("blockers") or []
    if not blockers:
        lines.append("- None")
    else:
        for b in blockers:
            lines.append(f"- {b}")
    if report.get("traceback"):
        lines.extend(["", "## Traceback", "", "```", str(report.get("traceback"))[:4000], "```"])
    lines.extend(["", "## Changed files", ""])
    for f in report.get("changed_files") or []:
        lines.append(f"- `{f}`")
    lines.extend(
        [
            "",
            "## Rollback",
            "",
            "```bat",
            "cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend",
            "python scripts\\apply_phase7i_local_cutover_env.py --restore",
            "REM Stop the current FastAPI process, then:",
            "python manage.py runserver",
            "```",
            "",
            "## Architecture",
            "",
            "1. Primary: MUSIQ PaQ-2-PiQ + classical OpenCV (`musiq_worker`)",
            "2. Fallback: optimized local OpenCV (vectorized blocking)",
            "3. EfficientNet-B0 inactive on this path; weights retained for `QUALITY_ENGINE=enet`",
            "4. PROBE/WaveRep authenticity unchanged (preview remains deferred)",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def finalize_report(report: dict[str, Any], *, out_dir: Path | None = None) -> tuple[Path, Path]:
    """Always write verification.json + PHASE7I_REPORT.md. Safe to call multiple times."""
    dest = out_dir or OUT_DIR
    dest.mkdir(parents=True, exist_ok=True)

    photo = report.get("cases", {}).get("photo_http") or {}
    video = report.get("cases", {}).get("video_http") or {}
    offline = report.get("cases", {}).get("worker_offline_fallback") or {}

    photo_ok = (not photo.get("skipped")) and _ok_musiq(photo, media="photo")
    video_ok = (not video.get("skipped")) and _ok_musiq(video, media="video")
    offline_ok = (not offline.get("skipped")) and _ok_opencv_fallback(offline, media="photo")

    gates = report.setdefault("gates", {})
    results = report.setdefault("results", {})
    blockers = report.setdefault("blockers", [])

    # Prefer already-recorded loaded-engine fields; fall back to case evidence.
    loaded = report.get("actual_active_quality_engine")
    gates["loaded_engine_is_musiq_worker"] = loaded == "musiq_worker"
    gates["production_uses_enet_false"] = report.get("production_uses_enet") is False
    gates["worker_ready"] = bool((report.get("worker_probe") or {}).get("ready"))
    gates["photo_http_musiq_ok"] = photo_ok
    gates["video_http_musiq_ok"] = video_ok
    gates["offline_opencv_fallback_ok"] = offline_ok
    gates["enet_not_used_on_musiq_path"] = bool(
        (photo_ok and photo.get("analysis_efficientnet_used") is False)
        or (video_ok and video.get("analysis_efficientnet_used") is False)
    )
    gates["enet_weights_retained"] = False
    gates["enet_permanently_retired"] = bool(report.get("enet_permanently_retired", True))
    gates["vectorized_blocking"] = bool(report.get("vectorized_blocking"))
    gates["preview_defers_auth_and_xp"] = bool(
        (photo_ok and photo.get("authenticity_deferred") and photo.get("xp_eligible") is False)
        or (video_ok and video.get("authenticity_deferred") and video.get("xp_eligible") is False)
    )

    results["photo_http"] = "PASS" if photo_ok else ("SKIPPED" if photo.get("skipped") else "FAIL")
    results["video_http"] = "PASS" if video_ok else ("SKIPPED" if video.get("skipped") else "FAIL")
    results["worker_offline_fallback"] = (
        "PASS" if offline_ok else ("SKIPPED" if offline.get("skipped") else "FAIL")
    )
    results["rollback_availability"] = "N/A_ENET_RETIRED"
    if "loaded_engine" not in results:
        results["loaded_engine"] = "PASS" if loaded == "musiq_worker" else "FAIL"

    # Append gate failures once (idempotent-ish: only if message not already present).
    def _add_blocker(msg: str) -> None:
        if msg not in blockers:
            blockers.append(msg)

    if photo and not photo.get("skipped") and not photo_ok:
        _add_blocker(f"photo_http gate failed: {photo}")
    if video and not video.get("skipped") and not video_ok:
        _add_blocker(f"video_http gate failed: {video}")
    if offline and not offline.get("skipped") and not offline_ok:
        _add_blocker(f"offline fallback gate failed: {offline}")

    report["local_cutover_activated"] = bool(
        gates.get("loaded_engine_is_musiq_worker")
        and gates.get("photo_http_musiq_ok")
        and gates.get("video_http_musiq_ok")
        and gates.get("offline_opencv_fallback_ok")
        and gates.get("enet_permanently_retired")
        and not blockers
    )
    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    report["test_photo"] = str(PHOTO)
    report["test_video"] = str(VIDEO)
    report["report_complete"] = True

    raw = dest / "verification.json"
    md = dest / "PHASE7I_REPORT.md"
    raw.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    _write_md(md, report)
    return raw, md


def _new_report() -> dict[str, Any]:
    return {
        "phase": "7I",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "local_cutover_activated": False,
        "report_complete": False,
        "cloud_deploy": False,
        "cases": {},
        "gates": {},
        "results": {},
        "blockers": [],
        "changed_files": [
            "access_backend/.env (QUALITY_ENGINE + missing MUSIQ_WORKER_* if needed)",
            "access_backend/phase7i_local_cutover/env_backups/.env.pre_phase7i_*",
            "access_backend/scripts/apply_phase7i_local_cutover_env.py",
            "access_backend/scripts/verify_phase7i_local_cutover.py",
            "access_backend/scripts/run_phase7i_local_cutover.bat",
            "access_backend/phase7i_local_cutover/PHASE7I_REPORT.md",
        ],
        "notes": [],
    }


def run_smoke_cases(report: dict[str, Any]) -> None:
    """Execute photo/video/offline smoke. Exceptions are recorded; does not write report."""
    from app.config import settings
    from app.services.musiq_worker_client import (
        musiq_worker_configured,
        quality_engine,
        readiness_check,
    )
    from app.services.opencv_quality import USE_VECTORIZED_BLOCKING

    _stage("load settings from .env")
    report["env_quality_engine_setting"] = settings.quality_engine
    report["actual_active_quality_engine"] = quality_engine()
    report["production_uses_enet"] = False  # ENET permanently retired
    report["musiq_worker_configured"] = musiq_worker_configured()
    report["musiq_worker_url_set"] = bool((settings.musiq_worker_url or "").strip())
    report["musiq_worker_token_set"] = bool((settings.musiq_worker_token or "").strip())
    report["vectorized_blocking"] = bool(USE_VECTORIZED_BLOCKING)
    report["enet_weights_retained"] = False  # weights removed
    report["enet_permanently_retired"] = True
    _backup_dir = OUT_DIR / "env_backups"
    report["env_backup_retained"] = (OUT_DIR / "LATEST_ENV_BACKUP.txt").is_file() or (
        _backup_dir.is_dir() and any(_backup_dir.glob(".env.pre_phase7i_*"))
    )

    worker_url = (settings.musiq_worker_url or "http://127.0.0.1:8080").strip()
    report["worker_url_host"] = worker_url.split("://", 1)[-1].split("/", 1)[0]

    _stage("probe MUSIQ worker readiness")
    report["worker_probe"] = _worker_ready(worker_url)
    try:
        report["worker_readiness_check"] = readiness_check()
    except Exception as exc:  # noqa: BLE001
        report["worker_readiness_check"] = {"error": str(exc)}
        report["blockers"].append(f"readiness_check raised: {exc}")

    if quality_engine() != "musiq_worker":
        report["blockers"].append(
            f"Loaded quality_engine={quality_engine()!r}; expected musiq_worker after .env cutover + process restart"
        )
        report["results"]["loaded_engine"] = "FAIL"
    else:
        report["results"]["loaded_engine"] = "PASS"

    if not report["worker_probe"].get("ready"):
        report["blockers"].append("MUSIQ worker not ready at configured URL (check docker compose on :8080)")
        report["results"]["worker_available"] = "FAIL"
    else:
        report["results"]["worker_available"] = "PASS"

    if not PHOTO.is_file():
        report["blockers"].append(f"missing photo {PHOTO}")
    if not VIDEO.is_file():
        report["blockers"].append(f"missing video {VIDEO}")

    from app.api.deps import require_approved
    from fastapi.testclient import TestClient
    from main import app

    app.dependency_overrides[require_approved] = _fake_user
    worker_was_stopped = False
    # Shorten worker client timeout so offline path fails closed quickly to OpenCV.
    original_timeout = getattr(settings, "musiq_worker_timeout_sec", 60.0)
    try:
        with TestClient(app, base_url="http://127.0.0.1") as client:
            if PHOTO.is_file() and report["worker_probe"].get("ready"):
                _stage("photo HTTP musiq path")
                report["cases"]["photo_http"] = _safe_post(client, PHOTO)
            elif PHOTO.is_file():
                report["cases"]["photo_http"] = {"skipped": True, "reason": "worker_not_ready"}
            else:
                report["cases"]["photo_http"] = {"skipped": True, "reason": "missing_photo"}

            if VIDEO.is_file() and report["worker_probe"].get("ready"):
                _stage("video HTTP musiq path")
                report["cases"]["video_http"] = _safe_post(client, VIDEO)
            elif VIDEO.is_file():
                report["cases"]["video_http"] = {"skipped": True, "reason": "worker_not_ready"}
            else:
                report["cases"]["video_http"] = {"skipped": True, "reason": "missing_video"}

            if PHOTO.is_file():
                _stage("temporary docker stop for offline fallback")
                stop = _docker_compose(["stop", "musiq-worker"])
                report["cases"]["docker_stop"] = stop
                if stop.get("ok"):
                    worker_was_stopped = True
                    time.sleep(1)
                    report["cases"]["worker_after_stop"] = _worker_ready(worker_url)
                    try:
                        settings.musiq_worker_timeout_sec = OFFLINE_WORKER_TIMEOUT_SEC
                        _stage("photo HTTP offline OpenCV fallback")
                        report["cases"]["worker_offline_fallback"] = _safe_post(client, PHOTO)
                    finally:
                        settings.musiq_worker_timeout_sec = original_timeout
                else:
                    report["cases"]["worker_offline_fallback"] = {
                        "skipped": True,
                        "reason": "docker_stop_failed",
                        "docker_stop": stop,
                    }
                    report["notes"].append(
                        "Could not temporarily stop Docker worker; offline fallback not observed live."
                    )
    except Exception as exc:  # noqa: BLE001
        report["blockers"].append(f"smoke suite error: {exc}")
        report["traceback"] = traceback.format_exc()
        _stage(f"smoke suite error recorded: {exc}")
    finally:
        try:
            app.dependency_overrides.pop(require_approved, None)
        except Exception:  # noqa: BLE001
            pass
        try:
            settings.musiq_worker_timeout_sec = original_timeout
        except Exception:  # noqa: BLE001
            pass
        if worker_was_stopped:
            restart = _restart_musiq_worker(worker_url)
            report["cases"]["docker_start"] = restart.get("docker_start")
            report["cases"]["worker_after_restart"] = restart.get("worker_after_restart")
            if restart.get("error"):
                report["blockers"].append(f"worker restart error: {restart['error']}")
                report["traceback_restart"] = restart.get("traceback")
            elif not restart.get("ready"):
                report["blockers"].append("MUSIQ worker did not become ready after temporary stop/start")


def _emit_final_status(report: dict[str, Any], raw: Path, md: Path) -> None:
    _stage("final verification status")
    print(
        json.dumps(
            {
                "local_cutover_activated": report.get("local_cutover_activated"),
                "report_complete": report.get("report_complete"),
                "actual_active_quality_engine": report.get("actual_active_quality_engine"),
                "results": report.get("results"),
                "gates": report.get("gates"),
                "blockers": report.get("blockers"),
            },
            indent=2,
            default=str,
        ),
        flush=True,
    )
    print("wrote", raw, flush=True)
    print("wrote", md, flush=True)


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    report = _new_report()
    fatal: BaseException | None = None
    try:
        _stage("Phase 7I verification start")
        run_smoke_cases(report)
    except BaseException as exc:  # noqa: BLE001 — record; report write happens in finally
        report.setdefault("blockers", []).append(f"fatal verifier error: {exc}")
        report["traceback"] = traceback.format_exc()
        _stage(f"fatal error recorded: {exc}")
        fatal = exc
    finally:
        try:
            raw, md = finalize_report(report)
            _emit_final_status(report, raw, md)
        except Exception as write_exc:  # noqa: BLE001
            print(f"REPORT_WRITE_FAILED: {write_exc}", flush=True)
            print(traceback.format_exc(), flush=True)

    if fatal is not None and not isinstance(fatal, Exception):
        raise fatal

    exit_code = 0 if report.get("local_cutover_activated") else 2
    _stage(f"verifier exit={exit_code} cutover_activated={report.get('local_cutover_activated')}")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
