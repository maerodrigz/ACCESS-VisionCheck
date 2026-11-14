"""Build one anonymized shadow score record (classical + optional MUSIQ OPQ).

When MUSIQ_WORKER_URL + token are configured and MUSIQ_WORKER_PREFER_REMOTE is true,
shadow prefers a single multipart call to the Docker/Linux worker (/v1/evaluate).
Worker failures never invent scores and never mutate production evaluation payloads.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from datetime import datetime, timezone
from typing import Any

from app.services.quality_shadow.classical import (
    CLASSICAL_MAP_VERSION,
    classical_quality_from_bgr,
    color_criteria_from_bgr,
    decode_bgr_from_bytes,
)
from app.services.quality_shadow.feedback_generator import generate_hybrid_feedback
from app.services.quality_shadow.musiq_opq import (
    MUSIQ_MODEL_ID,
    MUSIQ_SCALE,
    score_image_bytes_musiq,
)

logger = logging.getLogger(__name__)

SHADOW_ENGINE_VERSION = "hybrid_nr_iqa_shadow_v1"


def anonymize_media_id(media_id: int, *, anon_salt: str) -> str:
    """Stable anonymized media token. Not reversible without the salt."""
    material = (anon_salt or "access-quality-shadow").encode("utf-8")
    digest = hmac.new(material, f"media:{int(media_id)}".encode("utf-8"), hashlib.sha256).hexdigest()
    return digest[:24]


def _base_record(*, evaluation_id: int | None, media_id: int, anon_salt: str) -> dict[str, Any]:
    return {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "evaluation_id": evaluation_id,
        "media_anon_id": anonymize_media_id(media_id, anon_salt=anon_salt),
        "shadow_engine_version": SHADOW_ENGINE_VERSION,
        "classical_map_version": CLASSICAL_MAP_VERSION,
        "status": "ok",
        "musiq_status": "skipped",
        "musiq_opq_raw": None,
        "musiq_scale": MUSIQ_SCALE,
        "musiq_model_id": MUSIQ_MODEL_ID,
        "musiq_engine_handle": None,
        "musiq_source": None,
        "criteria_raw": None,
        "criteria_q": None,
        "criteria_badge_equal_bin": None,
        "color": None,
        "duration_ms_total": None,
        "duration_ms_classical": None,
        "duration_ms_musiq": None,
        "duration_ms_worker": None,
        "error": None,
        "soft_score_applied_to_musiq": False,
        "research_only": True,
        "production_payload_mutated": False,
        "experimental_feedback": None,
        "quality_engine_production": "enet",
    }


def _apply_local_classical(record: dict[str, Any], content: bytes, *, t0: float) -> bool:
    """Fill classical fields in-process. Returns False on hard failure."""
    try:
        t_c = time.perf_counter()
        bgr = decode_bgr_from_bytes(content)
        if bgr is None:
            record["status"] = "error"
            record["error"] = "image_decode_failed"
            record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
            return False
        classical = classical_quality_from_bgr(bgr)
        color = color_criteria_from_bgr(bgr)
        record["duration_ms_classical"] = round((time.perf_counter() - t_c) * 1000.0, 3)
        record["criteria_raw"] = classical.get("raw")
        record["criteria_q"] = classical.get("q")
        record["criteria_badge_equal_bin"] = classical.get("badge_equal_bin")
        record["color"] = color
        record["classical_map_version"] = classical.get("map_version", CLASSICAL_MAP_VERSION)
        return True
    except Exception as exc:  # noqa: BLE001
        record["status"] = "error"
        record["error"] = f"classical_failed: {exc}"
        record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return False


def _attach_feedback(record: dict[str, Any]) -> None:
    record["experimental_feedback"] = generate_hybrid_feedback(
        criteria_q=record.get("criteria_q"),
        criteria_raw=record.get("criteria_raw"),
        color=record.get("color") if isinstance(record.get("color"), dict) else None,
        musiq_opq_raw=record.get("musiq_opq_raw"),
        musiq_status=record.get("musiq_status"),
    )


def _worker_musiq_ok(worker: dict[str, Any]) -> bool:
    musiq = worker.get("musiq") if isinstance(worker.get("musiq"), dict) else {}
    raw = musiq.get("musiq_opq_raw")
    return musiq.get("status") == "ok" and isinstance(raw, (int, float))


def _apply_worker_success(record: dict[str, Any], worker: dict[str, Any]) -> None:
    musiq = worker.get("musiq") if isinstance(worker.get("musiq"), dict) else {}
    record["musiq_status"] = "ok"
    record["musiq_opq_raw"] = musiq.get("musiq_opq_raw")
    record["musiq_scale"] = musiq.get("musiq_scale") or MUSIQ_SCALE
    record["musiq_model_id"] = musiq.get("model_id") or MUSIQ_MODEL_ID
    record["musiq_engine_handle"] = musiq.get("engine_handle")
    record["musiq_source"] = "musiq_worker"
    record["duration_ms_worker"] = worker.get("duration_ms")
    record["duration_ms_musiq"] = worker.get("duration_ms")
    record["criteria_raw"] = worker.get("criteria_raw")
    record["criteria_q"] = worker.get("criteria_q")
    record["criteria_badge_equal_bin"] = worker.get("criteria_badge_equal_bin")
    record["color"] = worker.get("color")
    if worker.get("classical_map_version"):
        record["classical_map_version"] = worker.get("classical_map_version")
    if isinstance(worker.get("experimental_feedback"), dict):
        record["experimental_feedback"] = worker.get("experimental_feedback")
    w_status = str(worker.get("status") or "ok")
    record["status"] = "ok" if w_status == "ok" else "partial"
    if record["status"] == "partial":
        record["error"] = worker.get("error") or musiq.get("error")


def _apply_worker_failure(record: dict[str, Any], worker: dict[str, Any]) -> None:
    musiq = worker.get("musiq") if isinstance(worker.get("musiq"), dict) else {}
    record["musiq_source"] = "musiq_worker"
    record["musiq_status"] = musiq.get("status") or "unavailable"
    record["musiq_opq_raw"] = None
    record["musiq_scale"] = musiq.get("musiq_scale") or MUSIQ_SCALE
    record["musiq_model_id"] = musiq.get("model_id") or MUSIQ_MODEL_ID
    record["musiq_engine_handle"] = musiq.get("engine_handle")
    record["duration_ms_worker"] = worker.get("duration_ms")
    record["duration_ms_musiq"] = worker.get("duration_ms")
    record["error"] = musiq.get("error") or worker.get("error") or "worker_musiq_unavailable"
    record["status"] = "partial"


def _try_worker_shadow(content: bytes) -> dict[str, Any] | None:
    """Return worker payload when remote is configured; None when not configured."""
    from app.config import settings
    from app.services.musiq_worker_client import evaluate_bytes, musiq_worker_configured

    if not (settings.musiq_worker_prefer_remote and musiq_worker_configured()):
        return None
    try:
        return evaluate_bytes(content, media_type="photo", filename="shadow.jpg")
    except Exception as exc:  # noqa: BLE001
        logger.warning("quality shadow: worker client raised: %s", exc)
        return {
            "status": "unavailable",
            "musiq": {
                "status": "unavailable",
                "musiq_opq_raw": None,
                "musiq_scale": MUSIQ_SCALE,
                "model_id": MUSIQ_MODEL_ID,
                "engine_handle": None,
                "error": f"worker_client_error: {exc}",
            },
            "error": f"worker_client_error: {exc}",
            "duration_ms": None,
        }


def run_shadow_score(
    *,
    content: bytes,
    evaluation_id: int | None,
    media_id: int,
    anon_salt: str,
    tfhub_cache_dir: str | None = None,
    skip_musiq: bool = False,
) -> dict[str, Any]:
    """Score photo bytes for shadow logging. Never mutates production scores."""
    t0 = time.perf_counter()
    record = _base_record(evaluation_id=evaluation_id, media_id=media_id, anon_salt=anon_salt)
    if not content:
        record["status"] = "unavailable"
        record["error"] = "no_image_bytes"
        record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return record

    worker_attempted = False
    if not skip_musiq:
        worker = _try_worker_shadow(content)
        if worker is not None:
            worker_attempted = True
            if _worker_musiq_ok(worker):
                _apply_worker_success(record, worker)
                if record.get("criteria_q") is None:
                    _apply_local_classical(record, content, t0=t0)
                    if record.get("status") == "error" and record.get("musiq_opq_raw") is not None:
                        record["status"] = "partial"
                if record.get("experimental_feedback") is None:
                    _attach_feedback(record)
                record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
                record["production_payload_mutated"] = False
                return record
            # Worker configured but MUSIQ failed: local classical + record worker error.
            _apply_worker_failure(record, worker)
            logger.info(
                "quality shadow: worker MUSIQ unavailable (%s); classical continues locally",
                record.get("error"),
            )

    if not _apply_local_classical(record, content, t0=t0):
        return record

    if skip_musiq:
        record["musiq_status"] = "unavailable"
        record["musiq_source"] = "skipped"
        record["error"] = record.get("error") or "musiq_skipped_by_caller"
    elif worker_attempted:
        # Already filled musiq_* from worker failure; do not retry remote/local TF.
        if record.get("status") not in ("error",):
            record["status"] = "partial"
    else:
        t_m = time.perf_counter()
        musiq = score_image_bytes_musiq(content, tfhub_cache_dir=tfhub_cache_dir)
        record["duration_ms_musiq"] = round((time.perf_counter() - t_m) * 1000.0, 3)
        record["musiq_status"] = musiq.get("status")
        record["musiq_opq_raw"] = musiq.get("musiq_opq_raw")
        record["musiq_scale"] = musiq.get("musiq_scale", MUSIQ_SCALE)
        record["musiq_model_id"] = musiq.get("model_id", MUSIQ_MODEL_ID)
        record["musiq_engine_handle"] = musiq.get("engine_handle")
        record["musiq_source"] = musiq.get("source") or "local_tf_or_unavailable"
        if musiq.get("status") in ("unavailable", "error"):
            record["status"] = "partial"
            record["error"] = musiq.get("error")

    _attach_feedback(record)
    record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
    record["production_payload_mutated"] = False
    return record
