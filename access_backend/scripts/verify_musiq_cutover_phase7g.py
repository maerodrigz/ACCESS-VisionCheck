#!/usr/bin/env python3
"""Phase 7G: controlled cutover verification (process-local; does not edit .env).

Architecture under test (QUALITY_ENGINE=musiq_worker in-process only):
  Primary: MUSIQ worker + classical OpenCV (adapter)
  Fallback: optimized local OpenCV (vectorized blocking)
  EfficientNet-B0: inactive on this path; weights retained for QUALITY_ENGINE=enet rollback

Usage:
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\verify_musiq_cutover_phase7g.py
"""

from __future__ import annotations

import importlib
import json
import os
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "phase7g_musiq_cutover_verification"
PHOTO = Path(
    os.environ.get(
        "PHASE7G_TEST_IMAGE",
        r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg",
    )
)
# Optional short practice video; skipped if missing.
VIDEO = Path(
    os.environ.get(
        "PHASE7G_TEST_VIDEO",
        r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\_missing_optional.mp4",
    )
)

os.environ.setdefault("MUSIQ_WORKER_URL", "http://127.0.0.1:8080")
os.environ.setdefault("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
os.environ.setdefault("MUSIQ_WORKER_TIMEOUT_SEC", "120")
os.environ.setdefault("MUSIQ_WORKER_TLS_VERIFY", "false")


def _bind(*, quality_engine: str, worker_url: str) -> None:
    from app.config import settings

    settings.quality_engine = quality_engine
    settings.musiq_worker_url = worker_url
    settings.musiq_worker_token = os.environ.get("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
    settings.musiq_worker_timeout_sec = float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "120"))
    settings.musiq_worker_tls_verify = False
    settings.quality_shadow_enabled = False


def _fake_user():
    from app.models.enums import RoleName, UserStatus

    return SimpleNamespace(
        id=0,
        email="phase7g@local.test",
        fullname="Phase7G",
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
    musiq = analysis.get("musiq_opq") if isinstance(analysis.get("musiq_opq"), dict) else None
    criteria = ev.get("criteria") if isinstance(ev.get("criteria"), list) else []
    return {
        "parse_ok": True,
        "media_type_envelope": body.get("media_type"),
        "scoring_engine_envelope": body.get("scoring_engine"),
        "scoring_engine": ev.get("scoring_engine"),
        "scoring_model": ev.get("scoring_model"),
        "overall_score": ev.get("overall_score"),
        "criterion_names": [c.get("name") for c in criteria if isinstance(c, dict)],
        "authenticity_deferred": ev.get("authenticity_deferred"),
        "xp_eligible": ev.get("xp_eligible"),
        "analysis_quality_engine": analysis.get("quality_engine"),
        "analysis_opencv_fallback": analysis.get("opencv_fallback"),
        "analysis_efficientnet_used": analysis.get("efficientnet_used"),
        "musiq_opq_context_only": analysis.get("musiq_opq_context_only"),
        "musiq_opq_raw": (musiq or {}).get("musiq_opq_raw"),
        "musiq_not_used_for_criteria": (musiq or {}).get("not_used_for_criteria"),
        "ai_detection_keys": sorted(ai.keys()),
        "ai_analysis_status": ai.get("analysis_status"),
        "ai_detector_backend": ai.get("detector_backend"),
    }


def _post(client, path: Path) -> dict[str, Any]:
    content = path.read_bytes()
    mime = "video/mp4" if path.suffix.lower() in {".mp4", ".mov", ".webm"} else "image/jpeg"
    r = client.post("/api/media/evaluate", files={"file": (path.name, content, mime)})
    try:
        body = r.json()
    except Exception:  # noqa: BLE001
        body = {"raw": (r.text or "")[:400]}
    return {"http_status": r.status_code, **_summarize(body)}


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "phase": "7G",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "env_file_modified": False,
        "production_cutover_activated": False,
        "note": "Process-local QUALITY_ENGINE=musiq_worker only; .env left unchanged (still enet).",
        "cases": {},
        "blockers": [],
        "gates": {},
    }

    # Fresh import check for vectorized blocking (simulates backend restart load).
    oq = importlib.import_module("app.services.opencv_quality")
    oq = importlib.reload(oq)
    report["gates"]["vectorized_blocking_enabled"] = bool(oq.USE_VECTORIZED_BLOCKING)
    if not oq.USE_VECTORIZED_BLOCKING:
        report["blockers"].append("USE_VECTORIZED_BLOCKING is False after reload")

    from app.services.efficientnet_b0_scorer import weights_path

    report["gates"]["enet_weights_retained"] = weights_path().is_file()
    if not weights_path().is_file():
        report["blockers"].append("ENET weights missing (rollback broken)")

    from app.api.deps import require_approved
    from app.services.musiq_worker_client import production_uses_enet, quality_engine, readiness_check
    from fastapi.testclient import TestClient
    from main import app

    worker_url = os.environ["MUSIQ_WORKER_URL"].rstrip("/")
    _bind(quality_engine="musiq_worker", worker_url=worker_url)
    report["process_local"] = {
        "quality_engine": quality_engine(),
        "production_uses_enet": production_uses_enet(),
        "worker_url": worker_url,
    }

    ready = readiness_check()
    report["worker_ready"] = ready

    app.dependency_overrides[require_approved] = _fake_user
    try:
        with TestClient(app, base_url="http://127.0.0.1") as client:
            if not PHOTO.is_file():
                report["blockers"].append(f"missing photo {PHOTO}")
            else:
                if ready.get("ready"):
                    print("--- photo musiq online ---", flush=True)
                    report["cases"]["photo_musiq_online"] = _post(client, PHOTO)
                else:
                    report["cases"]["photo_musiq_online"] = {
                        "skipped": True,
                        "reason": "worker_not_ready",
                        "ready": ready,
                    }
                    report["blockers"].append("MUSIQ worker /ready not green")

                print("--- photo worker offline fallback ---", flush=True)
                _bind(quality_engine="musiq_worker", worker_url="http://127.0.0.1:59999")
                report["cases"]["photo_worker_offline_fallback"] = _post(client, PHOTO)

                print("--- rollback QUALITY_ENGINE=enet ---", flush=True)
                _bind(quality_engine="enet", worker_url=worker_url)
                from app.services.efficientnet_b0_scorer import warm_main_thread
                from app.services.media_evaluator import preferred_quality_engine

                # Main-thread warm + diagnostics (mirrors FastAPI evaluate pre-to_thread warm).
                enet_diag = warm_main_thread()
                enet_diag["preferred_quality_engine"] = preferred_quality_engine()
                enet_diag["settings_quality_engine"] = quality_engine()
                report["enet_rollback_diagnostics"] = enet_diag
                print("enet_rollback_diagnostics", json.dumps(enet_diag, default=str), flush=True)
                report["cases"]["rollback_enet_control"] = _post(client, PHOTO)
                report["cases"]["rollback_enet_control"]["diagnostics"] = enet_diag

            if VIDEO.is_file():
                _bind(quality_engine="musiq_worker", worker_url=worker_url)
                print("--- video musiq path ---", flush=True)
                report["cases"]["video_musiq"] = _post(client, VIDEO)
            else:
                report["cases"]["video_musiq"] = {
                    "skipped": True,
                    "reason": f"optional video missing: {VIDEO}",
                }
    except Exception as exc:  # noqa: BLE001
        report["blockers"].append(str(exc))
        report["traceback"] = traceback.format_exc()
    finally:
        app.dependency_overrides.pop(require_approved, None)
        # Leave process on enet (matches untouched .env default).
        try:
            _bind(quality_engine="enet", worker_url=worker_url)
        except Exception:  # noqa: BLE001
            pass

    # Gate evaluation
    online = report["cases"].get("photo_musiq_online") or {}
    offline = report["cases"].get("photo_worker_offline_fallback") or {}
    rollback = report["cases"].get("rollback_enet_control") or {}

    def _ok_musiq(c: dict[str, Any]) -> bool:
        return (
            c.get("http_status") == 200
            and c.get("analysis_quality_engine") == "musiq_worker"
            and c.get("musiq_opq_context_only") is True
            and c.get("musiq_not_used_for_criteria") is True
            and c.get("analysis_efficientnet_used") is False
            and c.get("authenticity_deferred") is True
            and c.get("ai_detector_backend") is None
        )

    def _ok_opencv_fallback(c: dict[str, Any]) -> bool:
        return (
            c.get("http_status") == 200
            and c.get("analysis_quality_engine") == "opencv"
            and c.get("analysis_opencv_fallback") is True
            and c.get("analysis_efficientnet_used") is False
            and c.get("scoring_model") == "opencv"
        )

    def _ok_enet_rollback(c: dict[str, Any]) -> bool:
        return (
            c.get("http_status") == 200
            and c.get("analysis_quality_engine") == "efficientnet-b0"
            and c.get("analysis_efficientnet_used") is True
        )

    report["gates"]["photo_musiq_online_ok"] = bool(online.get("skipped")) is False and _ok_musiq(online)
    report["gates"]["photo_offline_opencv_fallback_ok"] = _ok_opencv_fallback(offline)
    report["gates"]["rollback_enet_ok"] = _ok_enet_rollback(rollback)
    report["gates"]["flutter_compat_labels_present"] = all(
        (online.get("scoring_engine") or offline.get("scoring_engine"))
        and (online.get("scoring_model") or offline.get("scoring_model"))
        for _ in (0,)
    )

    if online and not online.get("skipped") and not _ok_musiq(online):
        report["blockers"].append(f"photo_musiq_online gate failed: {online}")
    if not _ok_opencv_fallback(offline):
        report["blockers"].append(f"offline OpenCV fallback gate failed: {offline}")
    if not _ok_enet_rollback(rollback):
        report["blockers"].append(f"enet rollback gate failed: {rollback}")

    report["cutover_ready"] = (
        report["gates"].get("vectorized_blocking_enabled")
        and report["gates"].get("enet_weights_retained")
        and report["gates"].get("photo_musiq_online_ok")
        and report["gates"].get("photo_offline_opencv_fallback_ok")
        and report["gates"].get("rollback_enet_ok")
        and not report["blockers"]
    )
    report["finished_at"] = datetime.now(timezone.utc).isoformat()

    raw = OUT_DIR / "verification.json"
    md = OUT_DIR / "PHASE7G_REPORT.md"
    raw.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    _write_md(md, report)
    print(json.dumps({
        "cutover_ready": report["cutover_ready"],
        "gates": report["gates"],
        "blockers": report["blockers"],
        "cases": {k: {kk: vv for kk, vv in (v or {}).items() if kk in (
            "http_status", "analysis_quality_engine", "analysis_opencv_fallback",
            "analysis_efficientnet_used", "musiq_opq_context_only", "scoring_model",
            "authenticity_deferred", "skipped", "reason",
        )} for k, v in report["cases"].items()},
    }, indent=2, default=str))
    print("wrote", raw)
    print("wrote", md)
    return 0 if report["cutover_ready"] else 2


def _write_md(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Phase 7G — MUSIQ cutover verification",
        "",
        f"- Cutover ready (tests only; .env NOT flipped): **{report.get('cutover_ready')}**",
        f"- Production cutover activated: **{report.get('production_cutover_activated')}**",
        f"- Vectorized blocking: **{report.get('gates', {}).get('vectorized_blocking_enabled')}**",
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
    lines.extend(
        [
            "",
            "## Rollback",
            "",
            "- Keep `QUALITY_ENGINE=enet` in `.env` (current) to stay on EfficientNet.",
            "- After a future cutover, roll back by setting `QUALITY_ENGINE=enet` and restarting FastAPI.",
            "- ENET weights: `access_backend/ml/efficientnet_b0_heads.pt` (not deleted).",
            "",
            "## Architecture under test",
            "",
            "1. Primary: `musiq_worker`",
            "2. Fallback: optimized local `opencv`",
            "3. EfficientNet inactive on musiq path; available when `QUALITY_ENGINE=enet`",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
