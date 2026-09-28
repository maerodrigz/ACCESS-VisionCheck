"""
Step 8A: controlled PROBE staging smoke (2 images, HTTP E2E).

Requires backend running with AI_DETECTOR_BACKEND=probe (process env, not .env edit required).

Usage:
  cd access_backend
  set AI_DETECTOR_BACKEND=probe   # Windows cmd
  python manage.py runserver --no-reload --port 3001
  # other terminal:
  python scripts/smoke_probe_step8a.py
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

REAL_IMAGE = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg")
AI_IMAGE = Path(
    r"C:\Users\Dell\Desktop\fresh_validation\ai\canva\Canva AI Image Sep 26, 2026, 8_03_36 PM_20260926_200502_0000.jpg"
)
EXPECTED_CKPT_SHA = "c8caa9bad54c029e4d22e1909c4673e46a239d8419a986e0ab461d423a450156"
CKPT = (
    ROOT
    / "experiments/probe/modelscope_cache/models/shuinishaojiu--PROBE-AIGI-Detection/snapshots/master/DINOv2_best_model_step_34999.pth"
)

API_BASE = os.environ.get("SMOKE_API_BASE", "http://127.0.0.1:3001/api")
LOGIN_EMAIL = os.environ.get("SMOKE_MEMBER_EMAIL", "member@access.edu")
LOGIN_PASSWORD = os.environ.get("SMOKE_MEMBER_PASSWORD", "member123")
POLL_INTERVAL = 3.0
POLL_MAX_SEC = 600.0


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def preflight() -> dict[str, Any]:
    from app.config import settings
    from app.services import probe_dino_detector as probe_det

    ckpt_ok = CKPT.is_file() and _sha256(CKPT) == EXPECTED_CKPT_SHA
    return {
        "checkpoint_path": str(CKPT),
        "checkpoint_exists": CKPT.is_file(),
        "sha256_match": ckpt_ok,
        "sha256": _sha256(CKPT) if CKPT.is_file() else None,
        "probe_max_long_edge": int(settings.probe_max_long_edge),
        "probe_low_risk_threshold": float(settings.probe_low_risk_threshold),
        "probe_high_risk_threshold": float(settings.probe_high_risk_threshold),
        "max_media_evaluation_workers": int(settings.max_media_evaluation_workers),
        "code_default_backend": "univfd",
        "process_env_backend": os.environ.get("AI_DETECTOR_BACKEND"),
        "real_image_exists": REAL_IMAGE.is_file(),
        "ai_image_exists": AI_IMAGE.is_file(),
        "probe_checkpoint_resolver": str(probe_det.checkpoint_path()),
    }


def verify_running_backend_probe() -> dict[str, Any]:
    """In-process check: only valid if smoke script shares probe env with server."""
    os.environ.setdefault("AI_DETECTOR_BACKEND", "probe")
    from importlib import reload

    import app.config as cfg_mod
    import app.services.dedicated_ai_detector as det_mod

    reload(cfg_mod)
    reload(det_mod)
    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend

    return {
        "settings_ai_detector_backend": settings.ai_detector_backend,
        "active_ai_detector_backend": active_ai_detector_backend(),
        "note": "Server must be started with AI_DETECTOR_BACKEND=probe separately; confirm via save-path probe fields.",
    }


def login(client: httpx.Client) -> str:
    r = client.post(f"{API_BASE}/auth/login", json={"email": LOGIN_EMAIL, "password": LOGIN_PASSWORD})
    r.raise_for_status()
    data = r.json()
    token = data.get("access_token") or data.get("token")
    if not token:
        raise RuntimeError(f"Login missing token: {data}")
    return token


def preview_test(client: httpx.Client, token: str, image_path: Path) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    content = image_path.read_bytes()
    t0 = time.perf_counter()
    with httpx.Client(timeout=httpx.Timeout(300.0, connect=30.0)) as long_client:
        long_client.headers.update(headers)
        r = long_client.post(
            f"{API_BASE}/media/evaluate",
            files={"file": (image_path.name, content, "image/jpeg")},
        )
    latency = time.perf_counter() - t0
    r.raise_for_status()
    body = r.json()
    ev = body.get("evaluation") or {}
    ai = ev.get("ai_detection") or {}
    return {
        "latency_sec": round(latency, 3),
        "http_status": r.status_code,
        "quality_ok": ev.get("overall_score") is not None,
        "analysis_status": ai.get("analysis_status"),
        "is_final": ai.get("is_final"),
        "verdict": ai.get("verdict"),
        "probability": ai.get("probability"),
        "raw_detector_probability": ai.get("raw_detector_probability"),
        "probe_invoked_heuristic": latency > 20.0,
    }


def deferred_preview_metadata(image_path: Path, client: httpx.Client, token: str) -> str:
    headers = {"Authorization": f"Bearer {token}"}
    content = image_path.read_bytes()
    r = client.post(
        f"{API_BASE}/media/evaluate",
        files={"file": (image_path.name, content, "image/jpeg")},
        headers=headers,
    )
    r.raise_for_status()
    return json.dumps(r.json().get("evaluation") or {})


def upload_and_wait(
    client: httpx.Client,
    token: str,
    image_path: Path,
    *,
    label: str,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    content = image_path.read_bytes()
    meta = deferred_preview_metadata(image_path, client, token)

    t0 = time.perf_counter()
    r = client.post(
        f"{API_BASE}/media/upload",
        files={"file": (f"probe_smoke_{label}_{image_path.name}", content, "image/jpeg")},
        data={"file_name": f"PROBE smoke {label}", "evaluation_metadata": meta},
        headers=headers,
        timeout=httpx.Timeout(120.0, connect=30.0),
    )
    upload_latency = time.perf_counter() - t0
    r.raise_for_status()
    upload = r.json()
    media_id = int(upload["id"])
    processing_status = upload.get("processing_status")

    poll_start = time.perf_counter()
    last = upload
    polls = 0
    while time.perf_counter() - poll_start < POLL_MAX_SEC:
        polls += 1
        time.sleep(POLL_INTERVAL)
        g = client.get(f"{API_BASE}/media/{media_id}", headers=headers)
        g.raise_for_status()
        last = g.json()
        if last.get("processing_status") == "completed" or last.get("overall_score") is not None:
            break

    processing_sec = time.perf_counter() - poll_start

    detail = _fetch_evaluation_detail(client, token, media_id)
    xp_before = _member_points(client, token)

    for _ in range(3):
        client.get(f"{API_BASE}/media/{media_id}", headers=headers)
        time.sleep(1.0)
    xp_after = _member_points(client, token)

    policy = _policy_check(detail)

    return {
        "known_label": label,
        "source_path": str(image_path),
        "media_id": media_id,
        "upload_response_latency_sec": round(upload_latency, 3),
        "initial_processing_status": processing_status,
        "initial_overall_score": upload.get("overall_score"),
        "polls": polls,
        "processing_latency_sec": round(processing_sec, 3),
        "final_media_get": last,
        "detail": detail,
        "xp_points_before": xp_before,
        "xp_points_after": xp_after,
        "xp_awarded_delta": (xp_after - xp_before) if xp_before is not None and xp_after is not None else None,
        "policy_consistency": policy,
    }


def _member_points(client: httpx.Client, token: str) -> int | None:
    try:
        r = client.get(f"{API_BASE}/rankings", headers={"Authorization": f"Bearer {token}"})
        if r.status_code != 200:
            return None
        rows = r.json()
        if not isinstance(rows, list):
            return None
        for row in rows:
            if row.get("email") == LOGIN_EMAIL or row.get("member_email") == LOGIN_EMAIL:
                return int(row.get("points") or row.get("total_points") or 0)
        uid_row = next((x for x in rows if x.get("name")), None)
        if uid_row:
            return int(uid_row.get("points") or 0)
    except Exception:
        return None
    return None


def _fetch_evaluation_detail(client: httpx.Client, token: str, media_id: int) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    evs = client.get(f"{API_BASE}/evaluations?mine=true", headers=headers)
    evs.raise_for_status()
    for row in evs.json():
        if int(row.get("media_id") or 0) == media_id:
            crit = row.get("criteria_json")
            parsed = json.loads(crit) if isinstance(crit, str) and crit.strip() else {}
            ai_json = parsed.get("ai_detection") if isinstance(parsed, dict) else {}
            return {
                "overall_score": row.get("overall_score"),
                "review_status": row.get("review_status"),
                "detection_result": row.get("detection_result"),
                "ai_probability": row.get("ai_probability"),
                "criteria_ai_detection": ai_json,
                "xp_eligible": parsed.get("xp_eligible"),
                "xp_pending": parsed.get("xp_pending"),
            }
    return {}


def _policy_check(detail: dict[str, Any]) -> dict[str, Any]:
    ai = detail.get("criteria_ai_detection") or {}
    p = ai.get("raw_detector_probability", ai.get("probability"))
    if p is None:
        p = detail.get("ai_probability")
    try:
        p = float(p)
    except (TypeError, ValueError):
        return {"error": "missing_probability"}

    if p < 0.30:
        expected_risk = "low"
    elif p < 0.45:
        expected_risk = "suspicious"
    else:
        expected_risk = "high"

    risk = ai.get("risk_level")
    rr = ai.get("requires_review")
    review = detail.get("review_status")
    det = detail.get("detection_result")

    checks = {
        "p": p,
        "expected_risk": expected_risk,
        "risk_level": risk,
        "risk_match": risk == expected_risk,
        "requires_review": rr,
        "review_status": review,
        "detection_result": det,
        "xp_eligible": detail.get("xp_eligible"),
        "xp_pending": detail.get("xp_pending"),
    }
    if expected_risk == "low":
        checks["review_expect"] = "automated_low_ai_risk"
        checks["review_ok"] = review == "automated_low_ai_risk"
        checks["requires_review_ok"] = rr is False
    elif expected_risk == "suspicious":
        checks["review_expect"] = "needs_further_review"
        checks["review_ok"] = review == "needs_further_review"
        checks["requires_review_ok"] = rr is True
    else:
        checks["review_expect"] = "pending_review"
        checks["review_ok"] = review == "pending_review"
        checks["requires_review_ok"] = rr is True
    return checks


def raw_probability_consistency(detail: dict[str, Any]) -> dict[str, Any]:
    ai = detail.get("criteria_ai_detection") or {}
    raw = ai.get("raw_detector_probability")
    prob = ai.get("probability")
    dbp = detail.get("ai_probability")
    vals = [v for v in (raw, prob, dbp) if v is not None]
    if len(vals) < 2:
        return {"ok": False, "reason": "insufficient values", "raw": raw, "prob": prob, "db": dbp}
    base = float(vals[0])
    ok = all(abs(float(v) - base) < 1e-4 for v in vals)
    return {"ok": ok, "raw_detector_probability": raw, "probability": prob, "db_ai_probability": dbp}


def main() -> int:
    pf = preflight()
    if not pf["sha256_match"] or not pf["real_image_exists"] or not pf["ai_image_exists"]:
        out = {"status": "BLOCKED", "preflight": pf}
        print(json.dumps(out, indent=2))
        return 2

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8a" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "status": "RUNNING",
        "timestamp_utc": stamp,
        "environment": "local",
        "preflight": pf,
        "baseline_note": "Code default AI_DETECTOR_BACKEND=univfd; server must run with probe env for smoke.",
        "backend_probe_check": verify_running_backend_probe(),
    }

    try:
        with httpx.Client(timeout=httpx.Timeout(30.0, connect=10.0)) as client:
            health = client.get(f"{API_BASE}/health")
            health.raise_for_status()
            token = login(client)
            report["preview"] = preview_test(client, token, REAL_IMAGE)
            report["real_image"] = upload_and_wait(client, token, REAL_IMAGE, label="REAL")
            report["ai_image"] = upload_and_wait(client, token, AI_IMAGE, label="AI")
            report["real_raw_consistency"] = raw_probability_consistency(report["real_image"]["detail"])
            report["ai_raw_consistency"] = raw_probability_consistency(report["ai_image"]["detail"])
            report["status"] = "COMPLETE"
    except Exception as exc:
        report["status"] = "BLOCKED"
        report["error"] = str(exc)

    out_path = out_dir / "step8a_smoke_report.json"
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"\nWrote {out_path}")
    return 0 if report["status"] == "COMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
