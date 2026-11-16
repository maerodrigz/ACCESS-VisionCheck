#!/usr/bin/env python3
"""Extract combined/joined CSVs from a Cursor browser CDP JSON dump.

Does not modify original locked ratings or machine_output files.
Usage:
  python _extract_phase6b_from_browser_log.py PATH_TO_cdp-response.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT_COMBINED = ROOT / "phase6b_locked_ratings.csv"
OUT_JOINED = ROOT / "phase6b_statistical_analysis" / "joined_human_opencv_musiq.csv"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: _extract_phase6b_from_browser_log.py <cdp-json>", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    raw = json.loads(src.read_text(encoding="utf-8"))
    payload = json.loads(raw["result"]["value"])
    combined = payload["combined"]
    joined = payload["joined"]
    if not combined.startswith("evaluator_id,media_id,status,"):
        raise SystemExit("combined header mismatch")
    if not joined.startswith("media_id,R2_sharpness,"):
        raise SystemExit("joined header mismatch")
    if combined.count("\n") < 200:
        raise SystemExit(f"combined row count too low: {combined.count(chr(10))}")
    if joined.count("\n") < 100:
        raise SystemExit(f"joined row count too low: {joined.count(chr(10))}")
    OUT_COMBINED.write_text(combined, encoding="utf-8", newline="\n")
    OUT_JOINED.parent.mkdir(parents=True, exist_ok=True)
    OUT_JOINED.write_text(joined, encoding="utf-8", newline="\n")
    print(f"wrote {OUT_COMBINED} ({OUT_COMBINED.stat().st_size} bytes)")
    print(f"wrote {OUT_JOINED} ({OUT_JOINED.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
