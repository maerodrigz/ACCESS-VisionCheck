#!/usr/bin/env python3
"""Phase 7B: controlled local /media/evaluate verification via MUSIQ worker.

Process-local overrides only (does NOT write .env or activate production cutover).
Does not upload, create evaluation rows, or touch research artifacts.

Usage (Windows CMD):
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\verify_musiq_phase7b_media_evaluate.py
"""

from __future__ import annotations

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

# Process-local defaults for this verification only. load_dotenv(override=False)
# will not overwrite these once set; we also re-bind settings after import.
os.environ.setdefault("MUSIQ_WORKER_URL", "http://127.0.0.1:8080")
os.environ.setdefault("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
os.environ.setdefault("MUSIQ_WORKER_TIMEOUT_SEC", "90")
os.environ.setdefault("MUSIQ_WORKER_TLS_VERIFY", "false")
# Do NOT setdefault QUALITY_ENGINE here before dotenv; we force it after Settings load.

REAL_IMAGE = Path(
    os.environ.get(
        "PHASE7B_TEST_IMAGE",
        r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg",
    )
)
REPORT_PATH = ROOT / "scripts" / "_verify_out" / "phase7b_media_evaluate_verify.json"
# Ephemeral verify output only; does not modify Phase 1-6B research artifacts.


def _bind_worker_settings(*, quality_engine: str, worker_url: str) -> None:
    from app.config import settings

    settings.quality_engine = quality_engine
    settings.musiq_worker_url = worker_url
    settings.musiq_worker_token = os.environ.get("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
    settings.musiq_worker_timeout_sec = float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "90"))
    settings.musiq_worker_tls_verify = os.environ.get("MUSIQ_WORKER_TLS_VERIFY", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    # Explicitly keep shadow off so this run does not append shadow research logs.
    settings.quality_shadow_enabled = False


def _fake_approved_user():
    from app.models.enums import RoleName, UserStatus

    return SimpleNamespace(
        id=0,
        email="phase7b-verify@local.test",
        fullname="Phase7B Verify",
        is_active=True,
        status=UserStatus.APPROVED,
        role=SimpleNamespace(role_name=RoleName.MEMBER),
    )


def _post_evaluate(client, image_path: Path) -> dict[str, Any]:
    content = image_path.read_bytes()
    response = client.post(
        "/api/media/evaluate",
        files={"file": (image_path.name, content, "image/jpeg")},
    )
    body: Any
    try:
        body = response.json()
    except Exception:  # noqa: BLE001
        body = {"raw_text": (response.text or "")[:500]}
    return {
        "http_status": response.status_code,
        "body": body,
    }


def _summarize_evaluation(body: dict[str, Any]) -> dict[str, Any]:
    ev = body.get("evaluation") if isinstance(body, dict) else None
    if not isinstance(ev, dict):
        return {"parse_ok": False}
    analysis = ev.get("analysis") if isinstance(ev.get("analysis"), dict) else {}
    ai = ev.get("ai_detection") if isinstance(ev.get("ai_detection"), dict) else {}
    criteria = ev.get("criteria") if isinstance(ev.get("criteria"), list) else []
    criterion_scores = {
        str(c.get("name")): c.get("score")
        for c in criteria
        if isinstance(c, dict) and c.get("name")
    }
    return {
        "parse_ok": True,
        "media_type_envelope": body.get("media_type"),
        "scoring_engine_envelope": body.get("scoring_engine"),
        "scoring_engine": ev.get("scoring_engine"),
        "scoring_model": ev.get("scoring_model"),
        "overall_score": ev.get("overall_score"),
        "quality_level": ev.get("quality_level"),
        "evaluation_status": ev.get("evaluation_status"),
        "evaluation_available": ev.get("evaluation_available"),
        "authenticity_deferred": ev.get("authenticity_deferred"),
        "quality_provisional": ev.get("quality_provisional"),
        "xp_eligible": ev.get("xp_eligible"),
        "criterion_names": list(criterion_scores.keys()),
        "criterion_scores": criterion_scores,
        "legacy_keys": sorted((ev.get("legacy") or {}).keys()) if isinstance(ev.get("legacy"), dict) else [],
        "analysis_quality_engine": analysis.get("quality_engine"),
        "analysis_opencv_fallback": analysis.get("opencv_fallback"),
        "analysis_efficientnet_used": analysis.get("efficientnet_used"),
        "analysis_musiq_opq_context_only": analysis.get("musiq_opq_context_only"),
        "analysis_musiq_opq": analysis.get("musiq_opq"),
        "ai_detection": {
            "analysis_status": ai.get("analysis_status"),
            "is_final": ai.get("is_final"),
            "verdict": ai.get("verdict"),
            "detector_backend": ai.get("detector_backend"),
            "keys": sorted(ai.keys()),
        },
    }


def main() -> int:
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)

    report: dict[str, Any] = {
        "phase": "7B",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "test_image": str(REAL_IMAGE),
        "test_image_exists": REAL_IMAGE.is_file(),
        "test_image_bytes": REAL_IMAGE.stat().st_size if REAL_IMAGE.is_file() else None,
        "env_file_modified": False,
        "production_cutover": False,
        "cases": {},
    }

    if not REAL_IMAGE.is_file():
        print("FAIL: test image missing:", REAL_IMAGE, file=sys.stderr)
        report["error"] = f"missing_image:{REAL_IMAGE}"
        _write_report(report)
        return 2

    from app.api.deps import require_approved
    from app.services.musiq_worker_client import (
        production_uses_enet,
        quality_engine,
        readiness_check,
    )
    from fastapi.testclient import TestClient
    from main import app

    worker_url = os.environ.get("MUSIQ_WORKER_URL", "http://127.0.0.1:8080").rstrip("/")
    _bind_worker_settings(quality_engine="musiq_worker", worker_url=worker_url)

    report["process_local"] = {
        "quality_engine": quality_engine(),
        "production_uses_enet": production_uses_enet(),
        "musiq_worker_url": worker_url,
    }
    print("process_local quality_engine", quality_engine())
    print("process_local production_uses_enet", production_uses_enet())

    ready = readiness_check()
    report["worker_ready"] = ready
    print("worker_ready", json.dumps(ready, default=str))

    app.dependency_overrides[require_approved] = _fake_approved_user
    try:
        with TestClient(app, base_url="http://127.0.0.1") as client:
            # Case A: worker path (requires /ready)
            if ready.get("ready"):
                print("--- case_musiq_worker ---")
                raw_a = _post_evaluate(client, REAL_IMAGE)
                summary_a = _summarize_evaluation(raw_a.get("body") or {})
                report["cases"]["musiq_worker"] = {"http": raw_a["http_status"], **summary_a}
                print("http", raw_a["http_status"])
                print(json.dumps(summary_a, indent=2, default=str))
            else:
                report["cases"]["musiq_worker"] = {
                    "skipped": True,
                    "reason": "worker_not_ready",
                    "ready": ready,
                }
                print("SKIP musiq_worker case: worker not ready")

            # Case B: worker unavailable -> ENET/OpenCV fallback (process-local dead URL)
            print("--- case_worker_unavailable_fallback ---")
            _bind_worker_settings(
                quality_engine="musiq_worker",
                worker_url="http://127.0.0.1:59999",
            )
            print("fallback quality_engine", quality_engine())
            print("fallback production_uses_enet", production_uses_enet())
            raw_b = _post_evaluate(client, REAL_IMAGE)
            summary_b = _summarize_evaluation(raw_b.get("body") or {})
            report["cases"]["worker_unavailable_fallback"] = {
                "http": raw_b["http_status"],
                "forced_worker_url": "http://127.0.0.1:59999",
                **summary_b,
            }
            print("http", raw_b["http_status"])
            print(json.dumps(summary_b, indent=2, default=str))

            # Case C: restore default enet briefly to show production default still works
            print("--- case_default_enet_control ---")
            _bind_worker_settings(quality_engine="enet", worker_url=worker_url)
            print("control quality_engine", quality_engine())
            print("control production_uses_enet", production_uses_enet())
            raw_c = _post_evaluate(client, REAL_IMAGE)
            summary_c = _summarize_evaluation(raw_c.get("body") or {})
            report["cases"]["default_enet_control"] = {
                "http": raw_c["http_status"],
                **summary_c,
            }
            print("http", raw_c["http_status"])
            print(json.dumps(summary_c, indent=2, default=str))
    except Exception as exc:  # noqa: BLE001
        report["error"] = str(exc)
        report["traceback"] = traceback.format_exc()
        print("FAIL:", exc, file=sys.stderr)
        traceback.print_exc()
        _write_report(report)
        return 1
    finally:
        app.dependency_overrides.pop(require_approved, None)
        # Leave process settings on enet after the script (no .env write).
        try:
            _bind_worker_settings(quality_engine="enet", worker_url=worker_url)
        except Exception:  # noqa: BLE001
            pass

    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    _write_report(report)
    print("report_written", REPORT_PATH)

    # Exit non-zero only if the primary ready path failed when worker was ready.
    case_a = report["cases"].get("musiq_worker") or {}
    if case_a.get("skipped"):
        return 3
    if case_a.get("http") != 200 or not case_a.get("parse_ok"):
        return 4
    if case_a.get("analysis_quality_engine") != "musiq_worker":
        return 5
    case_b = report["cases"].get("worker_unavailable_fallback") or {}
    if case_b.get("http") != 200 or case_b.get("analysis_quality_engine") == "musiq_worker":
        return 6
    return 0


def _write_report(report: dict[str, Any]) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
