#!/usr/bin/env python3
"""Post-deploy smoke checks against a live MUSIQ worker.

Does not deploy anything. Exits non-zero if /ready or evaluate fails.
Never invents MUSIQ scores.

Usage:
  set MUSIQ_WORKER_URL=https://access-musiq-worker.fly.dev
  set MUSIQ_WORKER_TOKEN=...
  python musiq_worker/scripts/verify_remote_worker.py --image path/to.jpg
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
from pathlib import Path

import httpx


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base-url", default=os.environ.get("MUSIQ_WORKER_URL", "").rstrip("/"))
    ap.add_argument("--token", default=os.environ.get("MUSIQ_WORKER_TOKEN", ""))
    ap.add_argument("--image", type=Path, required=True)
    ap.add_argument("--timeout", type=float, default=120.0)
    args = ap.parse_args()

    if not args.base_url:
        print("MUSIQ_WORKER_URL / --base-url required", file=sys.stderr)
        return 2
    if not args.token:
        print("MUSIQ_WORKER_TOKEN / --token required", file=sys.stderr)
        return 2
    if not args.image.is_file():
        print(f"image not found: {args.image}", file=sys.stderr)
        return 2

    report: dict = {"base_url": args.base_url, "image": str(args.image)}
    with httpx.Client(timeout=args.timeout, follow_redirects=True) as client:
        t0 = time.perf_counter()
        health = client.get(f"{args.base_url}/health")
        report["health_status_code"] = health.status_code
        report["health_body"] = health.json() if health.headers.get("content-type", "").startswith("application/json") else health.text[:200]
        report["health_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)

        t1 = time.perf_counter()
        ready = client.get(f"{args.base_url}/ready")
        report["ready_status_code"] = ready.status_code
        try:
            report["ready_body"] = ready.json()
        except Exception:
            report["ready_body"] = ready.text[:300]
        report["ready_ms"] = round((time.perf_counter() - t1) * 1000.0, 3)
        if ready.status_code != 200:
            print(json.dumps(report, indent=2))
            print("FAIL: /ready not 200 — MUSIQ not loaded", file=sys.stderr)
            return 3

        # Expect 401 without token
        unauth = client.post(
            f"{args.base_url}/v1/evaluate",
            files={"file": (args.image.name, args.image.read_bytes(), "image/jpeg")},
            data={"media_type": "photo"},
        )
        report["unauth_status_code"] = unauth.status_code
        if unauth.status_code not in (401, 403):
            print(json.dumps(report, indent=2))
            print("FAIL: evaluate should reject missing bearer", file=sys.stderr)
            return 4

        t2 = time.perf_counter()
        content = args.image.read_bytes()
        auth = client.post(
            f"{args.base_url}/v1/evaluate",
            headers={"Authorization": f"Bearer {args.token}"},
            files={"file": (args.image.name, content, "image/jpeg")},
            data={"media_type": "photo"},
        )
        report["evaluate_http_ms"] = round((time.perf_counter() - t2) * 1000.0, 3)
        report["evaluate_status_code"] = auth.status_code
        if auth.status_code != 200:
            report["evaluate_body"] = auth.text[:500]
            print(json.dumps(report, indent=2))
            print("FAIL: authenticated evaluate", file=sys.stderr)
            return 5
        body = auth.json()
        musiq = body.get("musiq") or {}
        raw = musiq.get("musiq_opq_raw")
        report["evaluate_status"] = body.get("status")
        report["musiq_status"] = musiq.get("status")
        report["musiq_opq_raw"] = raw
        report["duration_ms"] = body.get("duration_ms")
        report["has_criteria_q"] = bool(body.get("criteria_q"))
        report["has_feedback"] = bool(body.get("experimental_feedback"))
        report["model_id"] = musiq.get("model_id")

        ok = (
            musiq.get("status") == "ok"
            and isinstance(raw, (int, float))
            and math.isfinite(float(raw))
            and report["has_criteria_q"]
            and report["has_feedback"]
        )
        print(json.dumps(report, indent=2))
        if not ok:
            print("FAIL: incomplete or non-finite MUSIQ result", file=sys.stderr)
            return 6
        print("PASS: live worker evaluate returned finite MUSIQ + classical + feedback")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
