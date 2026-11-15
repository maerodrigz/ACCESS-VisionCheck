"""
Step 8B: PROBE video + DB-backed XP smoke (1 image + 1 video).

Requires backend with AI_DETECTOR_BACKEND=probe on port 3001.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

REAL_IMAGE = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\IMG_20230512_103539_795.jpg")
VIDEO = ROOT / "evaluation_results/step8b/assets/step8b_real_phone_smoke.mp4"
EXPECTED_CKPT_SHA = "c8caa9bad54c029e4d22e1909c4673e46a239d8419a986e0ab461d423a450156"
CKPT = (
    ROOT
    / "experiments/probe/modelscope_cache/models/shuinishaojiu--PROBE-AIGI-Detection/snapshots/master/DINOv2_best_model_step_34999.pth"
)

API_BASE = os.environ.get("SMOKE_API_BASE", "http://127.0.0.1:3001/api")
LOGIN_EMAIL = os.environ.get("SMOKE_MEMBER_EMAIL", "member@access.edu")
LOGIN_PASSWORD = os.environ.get("SMOKE_MEMBER_PASSWORD", "member123")
POLL_INTERVAL = 3.0
VIDEO_POLL_MAX_SEC = 900.0
IMAGE_POLL_MAX_SEC = 600.0


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def preflight() -> dict[str, Any]:
    from app.config import settings

    ckpt_ok = CKPT.is_file() and _sha256(CKPT) == EXPECTED_CKPT_SHA
    return {
        "checkpoint_exists": CKPT.is_file(),
        "sha256_match": ckpt_ok,
        "probe_max_long_edge": int(settings.probe_max_long_edge),
        "probe_low_risk_threshold": float(settings.probe_low_risk_threshold),
        "probe_high_risk_threshold": float(settings.probe_high_risk_threshold),
        "max_media_evaluation_workers": int(settings.max_media_evaluation_workers),
        "code_default_backend": "univfd",
        "real_image_exists": REAL_IMAGE.is_file(),
        "video_exists": VIDEO.is_file(),
    }


def member_total_points(user_id: int) -> int:
    from sqlalchemy import select

    from app.database import SessionLocal
    from app.models.member_ranking import MemberRanking

    db = SessionLocal()
    try:
        row = db.scalar(select(MemberRanking).where(MemberRanking.user_id == user_id))
        return int(row.total_points) if row else 0
    finally:
        db.close()


def db_media_counts(media_id: int) -> dict[str, int]:
    from sqlalchemy import func, select

    from app.database import SessionLocal
    from app.models.ai_detection_result import AiDetectionResult
    from app.models.media_evaluation import MediaEvaluation
    from app.models.notification import Notification

    db = SessionLocal()
    try:
        ev = db.scalar(
            select(func.count()).select_from(MediaEvaluation).where(MediaEvaluation.media_id == media_id)
        )
        ai = db.scalar(
            select(func.count()).select_from(AiDetectionResult).where(AiDetectionResult.media_id == media_id)
        )
        alerts = db.scalar(
            select(func.count())
            .select_from(Notification)
            .where(Notification.action_ref_id == media_id, Notification.category == "ai_detection")
        )
        return {
            "media_evaluations": int(ev or 0),
            "ai_detection_results": int(ai or 0),
            "admin_ai_alerts": int(alerts or 0),
        }
    finally:
        db.close()


def login(client: httpx.Client) -> tuple[str, int]:
    r = client.post(f"{API_BASE}/auth/login", json={"email": LOGIN_EMAIL, "password": LOGIN_PASSWORD})
    r.raise_for_status()
    data = r.json()
    token = data.get("access_token") or data.get("token")
    user = data.get("user") or {}
    user_id = int(user.get("id") or user.get("user_id") or 0)
    if not token or not user_id:
        raise RuntimeError(f"Login missing token/user id: {data}")
    return token, user_id


def expected_xp_award(detail: dict[str, Any]) -> int:
    from app.services.integrity_evaluation_policy import xp_award_points_from_payload

    crit = detail.get("criteria_json_parsed") or {}
    return xp_award_points_from_payload(crit)


def fetch_eval_detail(client: httpx.Client, token: str, media_id: int) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    r = client.get(f"{API_BASE}/evaluations?mine=true", headers=headers)
    r.raise_for_status()
    for row in r.json():
        if int(row.get("media_id") or 0) == media_id:
            crit_raw = row.get("criteria_json")
            parsed = json.loads(crit_raw) if isinstance(crit_raw, str) and crit_raw.strip() else {}
            ai = parsed.get("ai_detection") if isinstance(parsed, dict) else {}
            analysis = parsed.get("analysis") if isinstance(parsed, dict) else {}
            return {
                "overall_score": row.get("overall_score"),
                "review_status": row.get("review_status"),
                "detection_result": row.get("detection_result"),
                "ai_probability": row.get("ai_probability"),
                "criteria_json_parsed": parsed,
                "criteria_ai_detection": ai,
                "xp_eligible": parsed.get("xp_eligible"),
                "xp_pending": parsed.get("xp_pending"),
                "analysis": analysis,
            }
    return {}


def deferred_preview_metadata(client: httpx.Client, token: str, path: Path, *, video: bool) -> str:
    headers = {"Authorization": f"Bearer {token}"}
    content = path.read_bytes()
    mime = "video/mp4" if video else "image/jpeg"
    r = client.post(
        f"{API_BASE}/media/evaluate",
        files={"file": (path.name, content, mime)},
        headers=headers,
        timeout=httpx.Timeout(600.0, connect=30.0),
    )
    r.raise_for_status()
    return json.dumps(r.json().get("evaluation") or {})


def policy_check(detail: dict[str, Any]) -> dict[str, Any]:
    ai = detail.get("criteria_ai_detection") or {}
    p = ai.get("raw_detector_probability", ai.get("probability"))
    if p is None:
        p = detail.get("ai_probability")
    try:
        p = float(p)
    except (TypeError, ValueError):
        return {"error": "missing_probability"}

    if p < 0.30:
        band = "low"
    elif p < 0.45:
        band = "suspicious"
    else:
        band = "high"

    rr = ai.get("requires_review")
    review = detail.get("review_status")
    out = {
        "p": p,
        "expected_band": band,
        "risk_level": ai.get("risk_level"),
        "requires_review": rr,
        "review_status": review,
    }
    if band == "low":
        out["expect_review"] = "automated_low_ai_risk"
        out["policy_ok"] = (
            ai.get("risk_level") == "low"
            and rr is False
            and review == "automated_low_ai_risk"
        )
    elif band == "suspicious":
        out["expect_review"] = "needs_further_review"
        out["policy_ok"] = (
            ai.get("risk_level") == "suspicious"
            and rr is True
            and review == "needs_further_review"
        )
    else:
        out["expect_review"] = "pending_review"
        out["policy_ok"] = (
            ai.get("risk_level") == "high"
            and rr is True
            and review == "pending_review"
        )
    return out


def upload_and_poll(
    client: httpx.Client,
    token: str,
    path: Path,
    *,
    label: str,
    video: bool,
    max_sec: float,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    content = path.read_bytes()
    meta = deferred_preview_metadata(client, token, path, video=video)
    mime = "video/mp4" if video else "image/jpeg"

    t0 = time.perf_counter()
    r = client.post(
        f"{API_BASE}/media/upload",
        files={"file": (f"probe_smoke_{label}_{path.name}", content, mime)},
        data={"file_name": f"PROBE smoke {label}", "evaluation_metadata": meta},
        headers=headers,
        timeout=httpx.Timeout(120.0, connect=30.0),
    )
    upload_latency = time.perf_counter() - t0
    r.raise_for_status()
    upload = r.json()
    media_id = int(upload["id"])

    poll_start = time.perf_counter()
    last = upload
    polls = 0
    health_checks: list[dict[str, Any]] = []
    errors: list[str] = []

    while time.perf_counter() - poll_start < max_sec:
        polls += 1
        if polls % 5 == 0:
            try:
                ht0 = time.perf_counter()
                h = client.get(f"{API_BASE}/health", timeout=10.0)
                health_checks.append(
                    {
                        "poll": polls,
                        "status": h.status_code,
                        "latency_sec": round(time.perf_counter() - ht0, 3),
                    }
                )
            except Exception as exc:
                errors.append(f"health poll {polls}: {exc}")

        time.sleep(POLL_INTERVAL)
        g = client.get(f"{API_BASE}/media/{media_id}", headers=headers)
        g.raise_for_status()
        last = g.json()
        if last.get("processing_status") == "completed" or last.get("overall_score") is not None:
            break

    processing_sec = time.perf_counter() - poll_start
    detail = fetch_eval_detail(client, token, media_id)
    counts = db_media_counts(media_id)
    admin_alert = counts["admin_ai_alerts"] > 0

    return {
        "media_id": media_id,
        "upload_response_latency_sec": round(upload_latency, 3),
        "initial_processing_status": upload.get("processing_status"),
        "polls": polls,
        "processing_latency_sec": round(processing_sec, 3),
        "final_media_get": last,
        "detail": detail,
        "db_counts": counts,
        "admin_alert": admin_alert,
        "health_checks_during_poll": health_checks,
        "errors_during_poll": errors,
        "policy": policy_check(detail),
    }


def video_probe_diagnostics(detail: dict[str, Any]) -> dict[str, Any]:
    ai = detail.get("criteria_ai_detection") or {}
    analysis = detail.get("analysis") or {}
    return {
        "quality_frames_analyzed": analysis.get("frames_analyzed"),
        "authenticity_frames_scanned": ai.get("frames_scanned"),
        "raw_frame_probabilities_exposed": ai.get("frame_probabilities") or ai.get("per_frame_probabilities"),
        "final_raw_probability": ai.get("raw_detector_probability", ai.get("probability")),
        "detector_backend": ai.get("detector_backend"),
    }


def ffprobe_video(path: Path) -> dict[str, Any]:
    ffprobe = os.environ.get("FFPROBE_PATH", "ffprobe")
    cmd = [
        ffprobe,
        "-v",
        "error",
        "-show_entries",
        "format=duration,size:stream=width,height",
        "-of",
        "json",
        str(path),
    ]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=False)
        if out.returncode == 0 and out.stdout.strip():
            data = json.loads(out.stdout)
            fmt = data.get("format") or {}
            streams = data.get("streams") or [{}]
            st = streams[0] if streams else {}
            return {
                "duration_sec": float(fmt.get("duration") or 0),
                "file_size_bytes": int(fmt.get("size") or path.stat().st_size),
                "width": st.get("width"),
                "height": st.get("height"),
            }
    except Exception:
        pass
    st = path.stat()
    return {"duration_sec": None, "file_size_bytes": st.st_size, "width": None, "height": None}


def preview_video(client: httpx.Client, token: str, path: Path) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    content = path.read_bytes()
    t0 = time.perf_counter()
    r = client.post(
        f"{API_BASE}/media/evaluate",
        files={"file": (path.name, content, "video/mp4")},
        headers=headers,
        timeout=httpx.Timeout(600.0, connect=30.0),
    )
    latency = time.perf_counter() - t0
    r.raise_for_status()
    body = r.json()
    ev = body.get("evaluation") or {}
    ai = ev.get("ai_detection") or {}
    analysis = ev.get("analysis") or {}
    return {
        "latency_sec": round(latency, 3),
        "quality_success": ev.get("overall_score") is not None,
        "analysis_status": ai.get("analysis_status"),
        "is_final": ai.get("is_final"),
        "verdict": ai.get("verdict"),
        "probability": ai.get("probability"),
        "raw_detector_probability": ai.get("raw_detector_probability"),
        "frames_analyzed": analysis.get("frames_analyzed"),
        "probe_invoked_heuristic": latency > 25.0 and ai.get("analysis_status") != "deferred",
    }


def idempotency_refresh(
    client: httpx.Client,
    token: str,
    user_id: int,
    media_id: int,
    *,
    rounds: int = 5,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {token}"}
    xp_start = member_total_points(user_id)
    counts_start = db_media_counts(media_id)
    for _ in range(rounds):
        client.get(f"{API_BASE}/media/{media_id}", headers=headers)
        time.sleep(0.5)
    xp_end = member_total_points(user_id)
    counts_end = db_media_counts(media_id)
    return {
        "xp_start": xp_start,
        "xp_end": xp_end,
        "xp_duplicate_delta": xp_end - xp_start,
        "counts_start": counts_start,
        "counts_end": counts_end,
        "counts_unchanged": counts_start == counts_end,
    }


def main() -> int:
    pf = preflight()
    if not pf["sha256_match"] or not REAL_IMAGE.is_file() or not VIDEO.is_file():
        print(json.dumps({"status": "BLOCKED", "preflight": pf}, indent=2))
        return 2

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8b" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "status": "RUNNING",
        "timestamp_utc": stamp,
        "preflight": pf,
        "video_asset": {
            "path": str(VIDEO),
            "known_label": "REAL (derived from phone photo slideshow, 5s smoke clip)",
            "ffprobe": ffprobe_video(VIDEO),
        },
    }

    try:
        with httpx.Client(timeout=httpx.Timeout(60.0, connect=15.0)) as client:
            client.get(f"{API_BASE}/health").raise_for_status()
            token, user_id = login(client)
            report["user_id"] = user_id

            xp_before_image = member_total_points(user_id)
            report["xp_image"] = {"XP_BEFORE": xp_before_image}

            img_result = upload_and_poll(
                client,
                token,
                REAL_IMAGE,
                label="REAL_XP",
                video=False,
                max_sec=IMAGE_POLL_MAX_SEC,
            )
            xp_after_image = member_total_points(user_id)
            detail = img_result["detail"]
            expected = expected_xp_award(detail)
            xp_delta = xp_after_image - xp_before_image
            refresh = idempotency_refresh(client, token, user_id, img_result["media_id"])

            report["xp_image"].update(
                {
                    "media_id": img_result["media_id"],
                    "raw_probe_p_fake": (detail.get("criteria_ai_detection") or {}).get("raw_detector_probability"),
                    "risk_level": (detail.get("criteria_ai_detection") or {}).get("risk_level"),
                    "xp_eligible": detail.get("xp_eligible"),
                    "xp_pending": detail.get("xp_pending"),
                    "expected_award": expected,
                    "XP_AFTER": xp_after_image,
                    "XP_DELTA": xp_delta,
                    "match": xp_delta == expected if detail.get("xp_eligible") else xp_delta == 0,
                    "duplicate_refresh": refresh,
                }
            )

            report["video_preview"] = preview_video(client, token, VIDEO)

            xp_before_video = member_total_points(user_id)
            vid_result = upload_and_poll(
                client,
                token,
                VIDEO,
                label="VIDEO",
                video=True,
                max_sec=VIDEO_POLL_MAX_SEC,
            )
            xp_after_video = member_total_points(user_id)
            vdetail = vid_result["detail"]
            vexp = expected_xp_award(vdetail)
            vdelta = xp_after_video - xp_before_video
            vid_refresh = idempotency_refresh(client, token, user_id, vid_result["media_id"])

            diag = video_probe_diagnostics(vdetail)
            ai = vdetail.get("criteria_ai_detection") or {}
            report["video_save"] = {
                **{k: vid_result[k] for k in ("media_id", "upload_response_latency_sec", "processing_latency_sec", "admin_alert", "policy")},
                "quality_frames": diag.get("quality_frames_analyzed"),
                "authenticity_frames": diag.get("authenticity_frames_scanned"),
                "raw_frame_probabilities": diag.get("raw_frame_probabilities_exposed"),
                "final_raw_probability": diag.get("final_raw_probability"),
                "risk_level": ai.get("risk_level"),
                "requires_review": ai.get("requires_review"),
                "review_status": vdetail.get("review_status"),
                "XP_eligible": vdetail.get("xp_eligible"),
                "XP_pending": vdetail.get("xp_pending"),
                "expected_xp_award": vexp,
                "XP_BEFORE": xp_before_video,
                "XP_AFTER": xp_after_video,
                "XP_awarded_delta": vdelta,
                "overall_quality_score": vdetail.get("overall_score"),
                "detector_backend": diag.get("detector_backend"),
                "health_checks": vid_result.get("health_checks_during_poll"),
                "errors": vid_result.get("errors_during_poll"),
                "idempotency": vid_refresh,
                "db_counts": vid_result.get("db_counts"),
            }
            report["status"] = "COMPLETE"
    except Exception as exc:
        report["status"] = "BLOCKED"
        report["error"] = str(exc)

    out_path = out_dir / "step8b_smoke_report.json"
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"\nWrote {out_path}")
    return 0 if report["status"] == "COMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
