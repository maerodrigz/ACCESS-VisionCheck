"""HTTPS client for the remote MUSIQ + OpenCV worker.

Default production quality engine remains EfficientNet-B0 (`QUALITY_ENGINE=enet`).
This client is for:
  - optional quality-shadow remote MUSIQ when MUSIQ_WORKER_URL is set
  - explicit test-mode calls that never mutate production evaluation payloads

Never invents MUSIQ scores on timeout/offline; returns status unavailable/error.
"""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

CLIENT_VERSION = "musiq_worker_client_v1"


def musiq_worker_configured() -> bool:
    url = (settings.musiq_worker_url or "").strip()
    token = (settings.musiq_worker_token or "").strip()
    return bool(url and token)


def quality_engine() -> str:
    return (settings.quality_engine or "enet").strip().lower() or "enet"


def production_uses_enet() -> bool:
    """True unless an explicit future cutover is configured.

    Even when QUALITY_ENGINE=musiq_worker, this release keeps EfficientNet as the
    active production scorer. The worker is callable for test/shadow only.
    """
    return True


def _base_url() -> str:
    return (settings.musiq_worker_url or "").strip().rstrip("/")


def _headers() -> dict[str, str]:
    token = (settings.musiq_worker_token or "").strip()
    return {"Authorization": f"Bearer {token}"}


def _timeout() -> httpx.Timeout:
    sec = float(settings.musiq_worker_timeout_sec or 60.0)
    return httpx.Timeout(sec, connect=min(15.0, sec))


def _unavailable(reason: str, *, media_type: str = "photo") -> dict[str, Any]:
    return {
        "status": "unavailable",
        "media_type": media_type,
        "musiq": {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "tfhub:google/musiq/paq2piq/1",
            "model_version": "paq2piq/1",
            "engine_handle": None,
            "error": reason,
        },
        "criteria_raw": None,
        "criteria_q": None,
        "criteria_badge_equal_bin": None,
        "color": None,
        "experimental_feedback": None,
        "frames_analyzed": 0,
        "duration_ms": None,
        "error": reason,
        "client": CLIENT_VERSION,
        "production_payload_mutated": False,
    }


def health_check() -> dict[str, Any]:
    if not _base_url():
        return {"ok": False, "error": "MUSIQ_WORKER_URL empty"}
    try:
        with httpx.Client(timeout=_timeout(), verify=settings.musiq_worker_tls_verify) as client:
            resp = client.get(f"{_base_url()}/health")
            resp.raise_for_status()
            data = resp.json()
            return {"ok": True, "body": data}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)}


def readiness_check() -> dict[str, Any]:
    if not _base_url():
        return {"ok": False, "ready": False, "error": "MUSIQ_WORKER_URL empty"}
    try:
        with httpx.Client(timeout=_timeout(), verify=settings.musiq_worker_tls_verify) as client:
            resp = client.get(f"{_base_url()}/ready")
            if resp.status_code == 503:
                return {"ok": False, "ready": False, "body": resp.json()}
            resp.raise_for_status()
            return {"ok": True, "ready": True, "body": resp.json()}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "ready": False, "error": str(exc)}


def evaluate_bytes(
    content: bytes,
    *,
    media_type: str = "photo",
    filename: str = "upload.jpg",
    file_ext: str = "",
) -> dict[str, Any]:
    """POST image/video bytes to the worker. Safe on timeout/offline."""
    media_type_norm = (media_type or "photo").strip().lower()
    if media_type_norm == "image":
        media_type_norm = "photo"
    if not musiq_worker_configured():
        return _unavailable("musiq_worker_not_configured", media_type=media_type_norm)
    if not content:
        return _unavailable("empty_body", media_type=media_type_norm)

    files = {"file": (filename, content, "application/octet-stream")}
    data = {"media_type": media_type_norm, "file_ext": file_ext or ""}
    try:
        with httpx.Client(timeout=_timeout(), verify=settings.musiq_worker_tls_verify) as client:
            resp = client.post(
                f"{_base_url()}/v1/evaluate",
                headers=_headers(),
                files=files,
                data=data,
            )
            if resp.status_code >= 400:
                detail = resp.text[:500]
                return _unavailable(
                    f"worker_http_{resp.status_code}: {detail}",
                    media_type=media_type_norm,
                )
            body = resp.json()
            if not isinstance(body, dict):
                return _unavailable("worker_invalid_json", media_type=media_type_norm)
            body["client"] = CLIENT_VERSION
            body["production_payload_mutated"] = False
            return body
    except httpx.TimeoutException:
        logger.warning("musiq worker timeout url=%s", _base_url())
        return _unavailable("worker_timeout", media_type=media_type_norm)
    except httpx.HTTPError as exc:
        logger.warning("musiq worker offline/error: %s", exc)
        return _unavailable(f"worker_offline: {exc}", media_type=media_type_norm)
    except Exception as exc:  # noqa: BLE001
        logger.warning("musiq worker client failure: %s", exc)
        return _unavailable(f"worker_client_error: {exc}", media_type=media_type_norm)


def musiq_opq_from_worker_result(result: dict[str, Any]) -> dict[str, Any]:
    """Map worker payload to the thin musiq_opq shape used by quality_shadow."""
    musiq = result.get("musiq") if isinstance(result.get("musiq"), dict) else {}
    status = musiq.get("status") or result.get("status") or "unavailable"
    return {
        "status": status if status in ("ok", "unavailable", "error") else "error",
        "musiq_opq_raw": musiq.get("musiq_opq_raw"),
        "musiq_scale": musiq.get("musiq_scale") or "approx_0_100_mos_like",
        "model_id": musiq.get("model_id") or "tfhub:google/musiq/paq2piq/1",
        "engine_handle": musiq.get("engine_handle"),
        "error": musiq.get("error") or result.get("error"),
        "source": "musiq_worker",
    }
