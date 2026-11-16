#!/usr/bin/env python3
"""Read-only WaveRep G4 checks for Linux/Kamatera (no DB, no uploads).

Usage:
  cd access_backend
  python scripts/waverep_linux_verify.py
  python scripts/waverep_linux_verify.py --benchmark path/to/sample.mp4
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))


def main() -> int:
    parser = argparse.ArgumentParser(description="WaveRep G4 Linux verification (read-only)")
    parser.add_argument(
        "--benchmark",
        type=Path,
        help="Optional local .mp4/.mov file for one offline analyze() timing (no API/DB)",
    )
    args = parser.parse_args()

    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend
    from app.services.waverep_g4_detector import (
        _detector_init_error,
        _resolve_detector_instance,
        is_waverep_video_detection_enabled,
        waverep_runtime_status,
    )

    print("=== WaveRep Linux verify (read-only) ===")
    print(f"WAVEREP_ENABLED (settings): {settings.waverep_enabled}")
    print(f"AI_DETECTOR_BACKEND (photos): {active_ai_detector_backend()}")
    print(f"is_waverep_video_detection_enabled(): {is_waverep_video_detection_enabled()}")
    print(json.dumps(waverep_runtime_status(), indent=2))

    t0 = time.perf_counter()
    detector = _resolve_detector_instance()
    init_s = time.perf_counter() - t0
    print(f"init_seconds: {round(init_s, 2)}")
    print(f"detector_initialized: {detector is not None}")
    if _detector_init_error:
        print(f"init_error: {_detector_init_error}")
        return 1

    if args.benchmark:
        path = args.benchmark.expanduser().resolve()
        if not path.is_file():
            print(f"benchmark file missing: {path}", file=sys.stderr)
            return 1
        content = path.read_bytes()
        suffix = path.suffix or ".mp4"
        from app.services.waverep_g4_detector import detect_ai_generated_video

        t1 = time.perf_counter()
        payload = detect_ai_generated_video(content, video_ext=suffix, file_name=path.name)
        bench_s = time.perf_counter() - t1
        print(f"benchmark_seconds: {round(bench_s, 2)}")
        print(
            json.dumps(
                {
                    "detector_backend": payload.get("detector_backend"),
                    "waverep_analysis_unavailable": payload.get("waverep_analysis_unavailable"),
                    "risk_level": payload.get("risk_level"),
                    "probability": payload.get("probability"),
                    "waverep_frames_analyzed": payload.get("waverep_frames_analyzed"),
                },
                indent=2,
            )
        )
        if payload.get("waverep_analysis_unavailable"):
            return 1

    print("OK: WaveRep detector loaded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
