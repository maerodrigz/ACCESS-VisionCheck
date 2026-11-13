"""Build one anonymized shadow score record (classical + optional MUSIQ OPQ)."""

from __future__ import annotations

import hashlib
import hmac
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

SHADOW_ENGINE_VERSION = "hybrid_nr_iqa_shadow_v1"


def anonymize_media_id(media_id: int, *, anon_salt: str) -> str:
    """Stable anonymized media token. Not reversible without the salt."""
    material = (anon_salt or "access-quality-shadow").encode("utf-8")
    digest = hmac.new(material, f"media:{int(media_id)}".encode("utf-8"), hashlib.sha256).hexdigest()
    return digest[:24]


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
    record: dict[str, Any] = {
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
        "criteria_raw": None,
        "criteria_q": None,
        "criteria_badge_equal_bin": None,
        "color": None,
        "duration_ms_total": None,
        "duration_ms_classical": None,
        "duration_ms_musiq": None,
        "error": None,
        "soft_score_applied_to_musiq": False,
        "research_only": True,
        "production_payload_mutated": False,
        "experimental_feedback": None,
    }
    if not content:
        record["status"] = "unavailable"
        record["error"] = "no_image_bytes"
        record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return record

    try:
        t_c = time.perf_counter()
        bgr = decode_bgr_from_bytes(content)
        if bgr is None:
            record["status"] = "error"
            record["error"] = "image_decode_failed"
            record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
            return record
        classical = classical_quality_from_bgr(bgr)
        color = color_criteria_from_bgr(bgr)
        record["duration_ms_classical"] = round((time.perf_counter() - t_c) * 1000.0, 3)
        record["criteria_raw"] = classical.get("raw")
        record["criteria_q"] = classical.get("q")
        record["criteria_badge_equal_bin"] = classical.get("badge_equal_bin")
        record["color"] = color
        record["classical_map_version"] = classical.get("map_version", CLASSICAL_MAP_VERSION)
    except Exception as exc:  # noqa: BLE001
        record["status"] = "error"
        record["error"] = f"classical_failed: {exc}"
        record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
        return record

    if skip_musiq:
        record["musiq_status"] = "unavailable"
        record["error"] = record.get("error") or "musiq_skipped_by_caller"
    else:
        t_m = time.perf_counter()
        musiq = score_image_bytes_musiq(content, tfhub_cache_dir=tfhub_cache_dir)
        record["duration_ms_musiq"] = round((time.perf_counter() - t_m) * 1000.0, 3)
        record["musiq_status"] = musiq.get("status")
        record["musiq_opq_raw"] = musiq.get("musiq_opq_raw")
        record["musiq_scale"] = musiq.get("musiq_scale", MUSIQ_SCALE)
        record["musiq_model_id"] = musiq.get("model_id", MUSIQ_MODEL_ID)
        record["musiq_engine_handle"] = musiq.get("engine_handle")
        if musiq.get("status") == "unavailable":
            # Classical may still be ok; overall shadow status is partial.
            record["status"] = "partial"
            record["error"] = musiq.get("error")
        elif musiq.get("status") == "error":
            record["status"] = "partial"
            record["error"] = musiq.get("error")

    # Phase 3: research-only feedback from hybrid criteria (never production templates).
    record["experimental_feedback"] = generate_hybrid_feedback(
        criteria_q=record.get("criteria_q"),
        criteria_raw=record.get("criteria_raw"),
        color=record.get("color"),
        musiq_opq_raw=record.get("musiq_opq_raw"),
        musiq_status=record.get("musiq_status"),
    )

    record["duration_ms_total"] = round((time.perf_counter() - t0) * 1000.0, 3)
    return record
