#!/usr/bin/env python3
"""Phase 12B: official TF Hub MUSIQ PaQ-2-PiQ on locked SPAQ-200.

Run with tools/quality_validation/.venv_musiq_official. No 1-5 map fitted on SPAQ.
No production imports.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from official_musiq_engine_verification import (  # noqa: E402
    LICENSE_FINDINGS,
    load_official_predict_fn,
)
from official_musiq_livec_validation import score_file  # noqa: E402

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
ENET_CSV = SPAQ_ROOT / "output" / "run_001" / "spaq_200_machine_scores.csv"
DEFAULT_OUT = SPAQ_ROOT / "output" / "phase12_run_001"
PHASE5_CACHE = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "official_musiq_engine_verification"
    / "cache"
    / "tfhub"
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", type=Path, default=SPAQ_ROOT / "images")
    parser.add_argument("--enet-csv", type=Path, default=ENET_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--tfhub-cache", type=Path, default=PHASE5_CACHE)
    args = parser.parse_args()
    os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
    os.environ["TFHUB_CACHE_DIR"] = str(args.tfhub_cache.resolve())

    with args.enet_csv.open(newline="", encoding="utf-8-sig") as handle:
        enet_rows = list(csv.DictReader(handle))
    t_load = time.perf_counter()
    predict_fn, handle = load_official_predict_fn()
    load_s = time.perf_counter() - t_load

    out_rows: list[dict[str, Any]] = []
    times: list[float] = []
    failures: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    for i, rec in enumerate(enet_rows, start=1):
        key = rec["source_media_key"]
        path = args.images / key
        print(f"[12B {i}/200] {key}", flush=True)
        row = {
            "media_id": rec.get("media_id"),
            "source_media_key": key,
            "mos_quality_raw": rec.get("mos_quality_raw"),
            "overall_score": rec.get("overall_score"),
        }
        if not path.is_file():
            row.update({"musiq_status": "missing_file", "musiq_raw": "", "encoding": ""})
            failures.append({"key": key, "error": "missing_file"})
            out_rows.append(row)
            continue
        t1 = time.perf_counter()
        try:
            score, encoding = score_file(predict_fn, path)
            ms = (time.perf_counter() - t1) * 1000.0
            times.append(ms)
            row.update(
                {
                    "musiq_status": "ok",
                    "musiq_raw": score,
                    "encoding": encoding,
                    "elapsed_ms": ms,
                    "error": "",
                }
            )
        except Exception as exc:
            ms = (time.perf_counter() - t1) * 1000.0
            row.update(
                {
                    "musiq_status": "failed",
                    "musiq_raw": "",
                    "encoding": "",
                    "elapsed_ms": ms,
                    "error": str(exc),
                }
            )
            failures.append({"key": key, "error": str(exc)})
        out_rows.append(row)

    wall = time.perf_counter() - t0
    args.output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.output_dir / "phase12b_musiq_scores.csv"
    fields = [
        "media_id",
        "source_media_key",
        "mos_quality_raw",
        "overall_score",
        "musiq_status",
        "musiq_raw",
        "encoding",
        "elapsed_ms",
        "error",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as handle_out:
        writer = csv.DictWriter(handle_out, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(out_rows)
    payload = {
        "generated_at": _now(),
        "phase": "12B",
        "handle": handle,
        "n": len(out_rows),
        "n_ok": sum(1 for r in out_rows if r.get("musiq_status") == "ok"),
        "failures": failures,
        "load_s": load_s,
        "wall_s": wall,
        "ms_mean": (sum(times) / len(times)) if times else None,
        "ms_first": times[0] if times else None,
        "fitted_1_5_on_spaq": False,
        "license": LICENSE_FINDINGS,
        "tfhub_cache": str(args.tfhub_cache),
        "production_untouched": True,
    }
    (args.output_dir / "phase12b_metrics.json").write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    print(json.dumps({"n_ok": payload["n_ok"], "ms_mean": payload["ms_mean"], "handle": handle}, indent=2))
    return 0 if payload["n_ok"] == 200 else 1


if __name__ == "__main__":
    raise SystemExit(main())
