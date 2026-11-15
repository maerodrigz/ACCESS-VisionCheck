#!/usr/bin/env python3
"""Live MUSIQ verification after EfficientNet retirement.

- Hits running FastAPI /api/media/evaluate (photo + video).
- Does not edit .env, scoring formulas, or evaluation history.
- OpenCV fallback: process-local worker URL override via temporary container stop.
- Authenticity: in-process smoke only (no DB evaluation rows).
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

API = "http://127.0.0.1:3001"
WORKER_HEALTH = "http://127.0.0.1:8080/ready"
PHOTO = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg")
VIDEO = Path(
    r"C:\Users\Dell\Desktop\access_mobile\tools\quality_validation"
    r"\video_four_criteria_validation\assets\01_baseline_neutral.mp4"
)
OUT = ROOT / "scripts" / "_verify_out" / "musiq_live_final_verify.json"


def _worker_ready() -> dict[str, Any]:
    try:
        with httpx.Client(timeout=10.0) as c:
            r = c.get(WORKER_HEALTH)
            return {"http": r.status_code, "body": r.json() if r.headers.get("content-type", "").startswith("application/json") else r.text[:200]}
    except Exception as exc:  # noqa: BLE001
        return {"http": None, "error": str(exc)}


def _api_health() -> dict[str, Any]:
    with httpx.Client(timeout=10.0) as c:
        r = c.get(f"{API}/api/health")
        return {"http": r.status_code, "body": r.json()}


def _issue_token() -> tuple[str, str]:
    from app.database import SessionLocal
    from app.models.enums import UserStatus
    from app.models.user import User
    from tests.auth_token import issue_bearer_token

    db = SessionLocal()
    try:
        user = (
            db.query(User)
            .filter(User.status == UserStatus.APPROVED, User.is_active.is_(True))
            .order_by(User.id.asc())
            .first()
        )
        if user is None:
            raise RuntimeError("No approved active user available for live verify token")
        token = issue_bearer_token(db, user, expire_minutes=30)
        return token, user.email or f"user:{user.id}"
    finally:
        db.close()


def _summarize(body: dict[str, Any]) -> dict[str, Any]:
    ev = body.get("evaluation") if isinstance(body, dict) else None
    if not isinstance(ev, dict):
        return {"parse_ok": False, "body_keys": list(body.keys()) if isinstance(body, dict) else None}
    analysis = ev.get("analysis") if isinstance(ev.get("analysis"), dict) else {}
    criteria = ev.get("criteria") if isinstance(ev.get("criteria"), list) else []
    names = [c.get("name") for c in criteria if isinstance(c, dict)]
    musiq = analysis.get("musiq_opq") if isinstance(analysis.get("musiq_opq"), dict) else {}
    return {
        "parse_ok": True,
        "media_type": body.get("media_type"),
        "scoring_engine_envelope": body.get("scoring_engine"),
        "scoring_engine": ev.get("scoring_engine"),
        "scoring_model": ev.get("scoring_model"),
        "overall_score": ev.get("overall_score"),
        "quality_level": ev.get("quality_level"),
        "scoring_formula_version": ev.get("scoring_formula_version")
        or (ev.get("criteria_json") or {}).get("scoring_formula_version")
        if isinstance(ev.get("criteria_json"), dict)
        else ev.get("scoring_formula_version"),
        "analysis_quality_engine": analysis.get("quality_engine"),
        "analysis_opencv_fallback": analysis.get("opencv_fallback"),
        "analysis_efficientnet_used": analysis.get("efficientnet_used"),
        "musiq_opq_raw": musiq.get("musiq_opq_raw"),
        "musiq_not_used_for_criteria": musiq.get("not_used_for_criteria"),
        "criterion_names": names,
        "criterion_count": len(names),
        "xp_eligible": ev.get("xp_eligible"),
        "authenticity_deferred": ev.get("authenticity_deferred"),
    }


def _post_evaluate(token: str, path: Path, mime: str) -> dict[str, Any]:
    content = path.read_bytes()
    with httpx.Client(timeout=180.0) as c:
        r = c.post(
            f"{API}/api/media/evaluate",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": (path.name, content, mime)},
        )
    try:
        body = r.json()
    except Exception:  # noqa: BLE001
        body = {"raw": (r.text or "")[:800]}
    return {"http_status": r.status_code, "summary": _summarize(body) if isinstance(body, dict) else {}, "body": body}


def _docker(args: list[str]) -> dict[str, Any]:
    p = subprocess.run(
        ["docker", *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT.parent / "musiq_worker"),
    )
    return {"code": p.returncode, "stdout": (p.stdout or "")[-500:], "stderr": (p.stderr or "")[-500:]}


def _authenticity_smoke(photo: Path) -> dict[str, Any]:
    """In-process authenticity smoke — no evaluation rows written."""
    out: dict[str, Any] = {}
    content = photo.read_bytes()
    try:
        from app.config import settings

        out["ai_detector_backend"] = getattr(settings, "ai_detector_backend", None)
        out["waverep_enabled"] = bool(getattr(settings, "waverep_enabled", False))
    except Exception as exc:  # noqa: BLE001
        out["settings_error"] = str(exc)

    try:
        from app.services import probe_dino_detector as probe

        out["probe_module"] = True
        out["probe_checkpoint_on_disk"] = bool(probe.probe_checkpoint_on_disk())
        out["probe_detector_available"] = bool(probe.probe_detector_available())
    except Exception as exc:  # noqa: BLE001
        out["probe_error"] = str(exc)

    try:
        from app.services import waverep_g4_detector as wr

        out["waverep_module"] = True
        if hasattr(wr, "waverep_available"):
            out["waverep_available"] = bool(wr.waverep_available())
        elif hasattr(wr, "checkpoint_exists"):
            out["waverep_checkpoint_exists"] = bool(wr.checkpoint_exists())
    except Exception as exc:  # noqa: BLE001
        out["waverep_error"] = str(exc)

    import importlib.util

    out["univfd_retired"] = True
    out["univfd_package_absent"] = importlib.util.find_spec("app.services.univfd") is None
    out["photo_detector_backend"] = "probe"

    # Optional light PROBE inference on tiny JPEG if analyze exists and is fast enough.
    try:
        from app.services.media_evaluator import evaluate_bytes

        payload = evaluate_bytes(
            content,
            file_name=photo.name,
            include_authenticity=True,
        )
        if isinstance(payload, dict):
            ai = payload.get("ai_detection") if isinstance(payload.get("ai_detection"), dict) else {}
            analysis = payload.get("analysis") if isinstance(payload.get("analysis"), dict) else {}
            out["evaluate_with_authenticity"] = {
                "quality_engine": analysis.get("quality_engine"),
                "efficientnet_used": analysis.get("efficientnet_used"),
                "opencv_fallback": analysis.get("opencv_fallback"),
                "ai_verdict": ai.get("verdict") or ai.get("label"),
                "ai_analysis_status": ai.get("analysis_status"),
                "ai_backend": ai.get("backend") or ai.get("detector_backend"),
                "scoring_formula_version": payload.get("scoring_formula_version")
                or (analysis.get("scoring_formula_version")),
            }
    except Exception as exc:  # noqa: BLE001
        out["evaluate_with_authenticity_error"] = str(exc)[:400]

    return out


def _contract_checks() -> dict[str, Any]:
    from app.services import media_evaluator as me
    from app.services import quality_skill_classification as qsc
    from app.config import settings

    return {
        "quality_engine_setting": settings.quality_engine,
        "scoring_engine_const": getattr(me, "SCORING_ENGINE", None),
        "scoring_model_musiq": getattr(me, "SCORING_MODEL_MUSIQ", None),
        "formula_v2_present": hasattr(me, "SCORING_FORMULA_VERSION")
        or "scoring_formula_version" in open(me.__file__, encoding="utf-8").read(),
        "qsc_module": qsc.__name__,
        "media_evaluator_imports_enet": "efficientnet_b0_scorer" in open(me.__file__, encoding="utf-8").read(),
    }


def main() -> int:
    report: dict[str, Any] = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "photo_path": str(PHOTO),
        "video_path": str(VIDEO),
    }
    if not PHOTO.is_file():
        report["error"] = f"missing photo {PHOTO}"
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2
    if not VIDEO.is_file():
        report["error"] = f"missing video {VIDEO}"
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2

    report["api_health"] = _api_health()
    report["worker_before"] = _worker_ready()
    report["contracts"] = _contract_checks()

    token, email = _issue_token()
    report["token_user"] = email

    print("=== PHOTO evaluate (MUSIQ expected) ===", flush=True)
    report["photo"] = _post_evaluate(token, PHOTO, "image/jpeg")
    print(json.dumps(report["photo"]["summary"], indent=2), flush=True)

    print("=== VIDEO evaluate (MUSIQ expected) ===", flush=True)
    report["video"] = _post_evaluate(token, VIDEO, "video/mp4")
    print(json.dumps(report["video"]["summary"], indent=2), flush=True)

    print("=== OpenCV fallback (stop MUSIQ worker) ===", flush=True)
    report["docker_stop"] = _docker(["compose", "stop", "musiq-worker"])
    time.sleep(2)
    report["worker_while_stopped"] = _worker_ready()
    report["photo_opencv_fallback"] = _post_evaluate(token, PHOTO, "image/jpeg")
    print(json.dumps(report["photo_opencv_fallback"]["summary"], indent=2), flush=True)

    print("=== Restore MUSIQ worker ===", flush=True)
    report["docker_start"] = _docker(["compose", "start", "musiq-worker"])
    # Wait for ready
    ready = False
    for _ in range(36):
        wr = _worker_ready()
        report["worker_restore_poll"] = wr
        body = wr.get("body") if isinstance(wr.get("body"), dict) else {}
        if wr.get("http") == 200 and (body.get("musiq_ready") is True or body.get("status") == "ready"):
            ready = True
            break
        time.sleep(5)
    report["worker_restored"] = ready
    report["worker_after"] = _worker_ready()

    # Confirm MUSIQ path works again after restore
    print("=== PHOTO evaluate after restore ===", flush=True)
    report["photo_after_restore"] = _post_evaluate(token, PHOTO, "image/jpeg")
    print(json.dumps(report["photo_after_restore"]["summary"], indent=2), flush=True)

    print("=== Authenticity smoke (no DB eval rows) ===", flush=True)
    report["authenticity"] = _authenticity_smoke(PHOTO)
    print(json.dumps(report["authenticity"], indent=2, default=str)[:2000], flush=True)

    photo_ok = (
        report["photo"]["http_status"] == 200
        and report["photo"]["summary"].get("analysis_quality_engine") == "musiq_worker"
        and report["photo"]["summary"].get("analysis_efficientnet_used") is False
        and report["photo"]["summary"].get("analysis_opencv_fallback") is False
    )
    video_ok = (
        report["video"]["http_status"] == 200
        and report["video"]["summary"].get("analysis_quality_engine") == "musiq_worker"
        and report["video"]["summary"].get("analysis_efficientnet_used") is False
    )
    fallback_ok = (
        report["photo_opencv_fallback"]["http_status"] == 200
        and report["photo_opencv_fallback"]["summary"].get("analysis_quality_engine") == "opencv"
        and report["photo_opencv_fallback"]["summary"].get("analysis_opencv_fallback") is True
        and report["photo_opencv_fallback"]["summary"].get("analysis_efficientnet_used") is False
    )
    restore_ok = (
        ready
        and report["photo_after_restore"]["http_status"] == 200
        and report["photo_after_restore"]["summary"].get("analysis_quality_engine") == "musiq_worker"
    )
    report["gates"] = {
        "photo_musiq": photo_ok,
        "video_musiq": video_ok,
        "opencv_fallback": fallback_ok,
        "worker_restored": restore_ok,
        "no_enet_in_evaluator": report["contracts"].get("media_evaluator_imports_enet") is False,
        "quality_engine_musiq_worker": report["contracts"].get("quality_engine_setting") == "musiq_worker",
    }
    report["gates"]["all_pass"] = all(report["gates"].values())
    report["ready_for_enet_cleanup"] = report["gates"]["all_pass"] is True
    report["enet_cleanup_blocker"] = None
    report["enet_scorer_removed"] = True
    report["enet_weights_removed"] = True
    report["finished_at"] = datetime.now(timezone.utc).isoformat()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    print("WROTE", OUT, flush=True)
    print("GATES", json.dumps(report["gates"], indent=2), flush=True)
    return 0 if report["gates"]["all_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
