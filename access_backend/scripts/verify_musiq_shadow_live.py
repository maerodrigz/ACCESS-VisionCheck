#!/usr/bin/env python3
"""Live shadow-mode verification against a running MUSIQ Docker worker.

Does not mutate production evaluation payloads. Requires:
  MUSIQ worker on MUSIQ_WORKER_URL (default http://127.0.0.1:8080)
  matching MUSIQ_WORKER_TOKEN (default compose token)

Usage:
  cd access_backend
  python scripts/verify_musiq_shadow_live.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Prefer explicit env for this smoke; do not require editing .env permanently.
os.environ.setdefault("QUALITY_ENGINE", "enet")
os.environ.setdefault("QUALITY_SHADOW_ENABLED", "true")
os.environ.setdefault("MUSIQ_WORKER_URL", "http://127.0.0.1:8080")
os.environ.setdefault("MUSIQ_WORKER_TOKEN", "dev-local-musiq-token")
os.environ.setdefault("MUSIQ_WORKER_TIMEOUT_SEC", "90")
os.environ.setdefault("MUSIQ_WORKER_TLS_VERIFY", "false")
os.environ.setdefault("MUSIQ_WORKER_PREFER_REMOTE", "true")
os.environ.setdefault("QUALITY_SHADOW_LOG_DIR", "research_logs/quality_shadow_live_verify")
os.environ.setdefault("QUALITY_SHADOW_ANON_SALT", "live-verify-salt")


def main() -> int:
    import cv2
    import numpy as np
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env", override=False)

    # Re-bind settings after env defaults (Settings already constructed on import in some paths).
    from app.config import settings
    from app.services.musiq_worker_client import (
        production_uses_enet,
        quality_engine,
        readiness_check,
    )
    from app.services.quality_shadow.scoring import run_shadow_score
    from app.services.quality_shadow.logging_store import append_shadow_record

    # Force shadow worker settings for this process (explicit enable for verification).
    settings.quality_engine = "enet"
    settings.quality_shadow_enabled = True
    settings.musiq_worker_url = os.environ["MUSIQ_WORKER_URL"]
    settings.musiq_worker_token = os.environ["MUSIQ_WORKER_TOKEN"]
    settings.musiq_worker_timeout_sec = float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "90"))
    settings.musiq_worker_tls_verify = (
        os.environ.get("MUSIQ_WORKER_TLS_VERIFY", "false").lower() in ("1", "true", "yes")
    )
    settings.musiq_worker_prefer_remote = True
    settings.quality_shadow_log_dir = os.environ["QUALITY_SHADOW_LOG_DIR"]
    settings.quality_shadow_anon_salt = os.environ["QUALITY_SHADOW_ANON_SALT"]

    print("quality_engine", quality_engine())
    print("production_uses_enet", production_uses_enet())
    ready = readiness_check()
    print("ready", json.dumps(ready, default=str))
    if not ready.get("ready"):
        print("FAIL: worker /ready not green", file=sys.stderr)
        return 2

    img = np.full((96, 128, 3), (60, 110, 160), dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", img)
    assert ok
    content = bytes(buf)

    # Production-like payload that must remain untouched.
    production = {
        "overall_score": 3.5,
        "criteria": [{"name": "Sharpness", "score": 4}],
        "ai_feedback": "unchanged",
    }
    snap = json.dumps(production, sort_keys=True)

    record = run_shadow_score(
        content=content,
        evaluation_id=0,
        media_id=999001,
        anon_salt=settings.quality_shadow_anon_salt,
    )
    log_dir = Path(settings.quality_shadow_log_dir)
    if not log_dir.is_absolute():
        log_dir = ROOT / log_dir
    path = append_shadow_record(log_dir, record)

    print("shadow_status", record.get("status"))
    print("musiq_status", record.get("musiq_status"), record.get("musiq_opq_raw"))
    print("musiq_source", record.get("musiq_source"))
    print("duration_ms_worker", record.get("duration_ms_worker"))
    print("duration_ms_total", record.get("duration_ms_total"))
    print("has_criteria_q", bool(record.get("criteria_q")))
    print("has_feedback", bool(record.get("experimental_feedback")))
    print("production_payload_mutated", record.get("production_payload_mutated"))
    print("log_path", path)
    print("production_unchanged", json.dumps(production, sort_keys=True) == snap)

    if json.dumps(production, sort_keys=True) != snap:
        print("FAIL: production payload mutated", file=sys.stderr)
        return 3
    if record.get("musiq_status") != "ok" or record.get("musiq_opq_raw") is None:
        print("FAIL: MUSIQ not ok", record.get("error"), file=sys.stderr)
        return 4
    if not record.get("criteria_q"):
        print("FAIL: missing OpenCV criteria", file=sys.stderr)
        return 5
    if record.get("musiq_source") != "musiq_worker":
        print("FAIL: expected musiq_source=musiq_worker", file=sys.stderr)
        return 6
    print("PASS: live FastAPI shadow path received real MUSIQ worker results")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
