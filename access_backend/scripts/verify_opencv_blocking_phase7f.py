#!/usr/bin/env python3
"""Phase 7F: parity + before/after benchmark for vectorized blocking artifacts.

Does not modify .env, research datasets, Flutter, authenticity, or DB.
Keeps loop reference for rollback.

Usage:
  cd /d C:\\Users\\Dell\\Desktop\\access_mobile\\access_backend
  python scripts\\verify_opencv_blocking_phase7f.py
"""

from __future__ import annotations

import json
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

OUT_DIR = ROOT / "phase7f_opencv_blocking_optimization"
IMAGE_DIR = Path(r"C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos")
N_IMAGES = 10
ABS_TOL = 1e-12
REL_SOFT = 0.0  # raw metrics must match within ABS_TOL


def _ms(fn) -> tuple[Any, float]:
    t0 = time.perf_counter()
    out = fn()
    return out, (time.perf_counter() - t0) * 1000.0


def _soft_blocking_score(blocking_metric: float) -> int:
    """Mirror media_evaluator Blocking Artifacts mapping (1 - metric then soft bins)."""
    metric = 1.0 - float(blocking_metric)
    boosted = max(0.0, min(1.0, metric * 0.5 + 0.42))
    if boosted >= 0.80:
        return 5
    if boosted >= 0.64:
        return 4
    if boosted >= 0.46:
        return 3
    if boosted >= 0.28:
        return 2
    return 1


def main() -> int:
    from app.services import opencv_quality as oq
    from app.services.media_evaluator import _photo_criteria
    from app.services.color_quality_criteria import analyze_color_criteria_bytes

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    images = sorted(
        [p for p in IMAGE_DIR.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"}],
        key=lambda p: p.name.lower(),
    )[:N_IMAGES]

    report: dict[str, Any] = {
        "phase": "7F",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "n_images": len(images),
        "abs_tol": ABS_TOL,
        "use_vectorized_flag_before": bool(oq.USE_VECTORIZED_BLOCKING),
        "rollback_symbol": "_blocking_artifacts_loop_reference",
        "images": [],
        "parity_failures": [],
        "benchmark": {},
        "activated": False,
    }

    loop_times: list[float] = []
    vec_times: list[float] = []
    full_loop_times: list[float] = []
    full_vec_times: list[float] = []

    # Warmup
    if images:
        content0 = images[0].read_bytes()
        bgr0 = oq.decode_image(content0)
        if bgr0 is not None:
            import cv2

            g0 = cv2.cvtColor(bgr0, cv2.COLOR_BGR2GRAY)
            _ = oq._blocking_artifacts_loop_reference(g0)
            _ = oq._blocking_artifacts_vectorized(g0)

    all_ok = True
    for path in images:
        content = path.read_bytes()
        bgr = oq.decode_image(content)
        if bgr is None:
            report["parity_failures"].append({"image": path.name, "error": "decode_failed"})
            all_ok = False
            continue
        import cv2

        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

        loop_val, loop_ms = _ms(lambda: oq._blocking_artifacts_loop_reference(gray))
        vec_val, vec_ms = _ms(lambda: oq._blocking_artifacts_vectorized(gray))
        loop_times.append(loop_ms)
        vec_times.append(vec_ms)

        # Full analyze with forced implementations
        def analyze_with(blocking_fn):
            orig = oq._blocking_artifacts
            oq._blocking_artifacts = blocking_fn
            try:
                return oq.analyze_bgr(bgr)
            finally:
                oq._blocking_artifacts = orig

        ref_metrics, full_loop_ms = _ms(lambda: analyze_with(oq._blocking_artifacts_loop_reference))
        opt_metrics, full_vec_ms = _ms(lambda: analyze_with(oq._blocking_artifacts_vectorized))
        full_loop_times.append(full_loop_ms)
        full_vec_times.append(full_vec_ms)

        metric_deltas = {
            k: abs(float(opt_metrics[k]) - float(ref_metrics[k]))
            for k in (
                "sharpness",
                "blur",
                "noise",
                "brightness",
                "contrast",
                "blocking_artifacts",
                "ringing_artifacts",
            )
        }
        blocking_diff = abs(float(vec_val) - float(loop_val))
        score_ref = _soft_blocking_score(loop_val)
        score_opt = _soft_blocking_score(vec_val)

        # Full photo criteria (color from same bytes) for overall-ish parity on shared heads
        color = analyze_color_criteria_bytes(content)
        crit_ref = _photo_criteria(ref_metrics, color_balance=color[0], color_saturation=color[1])
        crit_opt = _photo_criteria(opt_metrics, color_balance=color[0], color_saturation=color[1])
        by_ref = {c["name"]: c["score"] for c in crit_ref}
        by_opt = {c["name"]: c["score"] for c in crit_opt}
        criteria_match = by_ref == by_opt

        row = {
            "image": path.name,
            "shape": [int(gray.shape[0]), int(gray.shape[1])],
            "blocking_loop": loop_val,
            "blocking_vectorized": vec_val,
            "blocking_abs_diff": blocking_diff,
            "blocking_1_5_loop": score_ref,
            "blocking_1_5_vectorized": score_opt,
            "criteria_scores_match": criteria_match,
            "criteria_ref": by_ref,
            "criteria_opt": by_opt,
            "metric_abs_deltas": metric_deltas,
            "loop_ms": loop_ms,
            "vectorized_ms": vec_ms,
            "full_analyze_loop_ms": full_loop_ms,
            "full_analyze_vectorized_ms": full_vec_ms,
        }
        report["images"].append(row)

        if blocking_diff > ABS_TOL or score_ref != score_opt or not criteria_match:
            all_ok = False
            report["parity_failures"].append(row)
            print("PARITY_FAIL", path.name, blocking_diff, score_ref, score_opt, criteria_match)

    # Gate: only recommend activation when parity passes. Source flag stays False until
    # this script rewrites it (or an operator flips it after reviewing the report).
    flag_path = ROOT / "app" / "services" / "opencv_quality.py"
    src = flag_path.read_text(encoding="utf-8")
    if all_ok:
        if "USE_VECTORIZED_BLOCKING = False" in src:
            flag_path.write_text(
                src.replace(
                    "USE_VECTORIZED_BLOCKING = False",
                    "USE_VECTORIZED_BLOCKING = True",
                    1,
                ),
                encoding="utf-8",
            )
        oq.USE_VECTORIZED_BLOCKING = True
        report["activated"] = True
        report["activation_note"] = (
            "Parity passed; set USE_VECTORIZED_BLOCKING=True in opencv_quality.py."
        )
    else:
        if "USE_VECTORIZED_BLOCKING = True" in src:
            flag_path.write_text(
                src.replace(
                    "USE_VECTORIZED_BLOCKING = True",
                    "USE_VECTORIZED_BLOCKING = False",
                    1,
                ),
                encoding="utf-8",
            )
        oq.USE_VECTORIZED_BLOCKING = False
        report["activated"] = False
        report["activation_note"] = (
            "Parity failed; USE_VECTORIZED_BLOCKING left/forced False (loop reference)."
        )
    report["use_vectorized_flag_after"] = bool(oq.USE_VECTORIZED_BLOCKING)

    def summary(vals: list[float]) -> dict[str, float]:
        if not vals:
            return {}
        return {
            "n": len(vals),
            "mean_ms": float(statistics.fmean(vals)),
            "median_ms": float(statistics.median(vals)),
            "min_ms": float(min(vals)),
            "max_ms": float(max(vals)),
        }

    report["benchmark"] = {
        "blocking_loop": summary(loop_times),
        "blocking_vectorized": summary(vec_times),
        "full_analyze_with_loop_blocking": summary(full_loop_times),
        "full_analyze_with_vectorized_blocking": summary(full_vec_times),
        "blocking_speedup_mean": (
            float(statistics.fmean(loop_times) / statistics.fmean(vec_times))
            if loop_times and vec_times and statistics.fmean(vec_times) > 0
            else None
        ),
        "full_analyze_speedup_mean": (
            float(statistics.fmean(full_loop_times) / statistics.fmean(full_vec_times))
            if full_loop_times and full_vec_times and statistics.fmean(full_vec_times) > 0
            else None
        ),
        "phase7e_blocking_baseline_mean_ms": 4453.13,
        "phase7e_full_opencv_baseline_mean_ms": 4859.07,
    }
    report["parity_passed"] = all_ok
    report["finished_at"] = datetime.now(timezone.utc).isoformat()

    raw = OUT_DIR / "parity_benchmark.json"
    md = OUT_DIR / "PHASE7F_REPORT.md"
    raw.write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    _write_md(md, report)
    print(json.dumps({"parity_passed": all_ok, "activated": report["activated"], "benchmark": report["benchmark"]}, indent=2))
    print("wrote", raw)
    print("wrote", md)
    return 0 if all_ok else 2


def _write_md(path: Path, report: dict[str, Any]) -> None:
    b = report.get("benchmark") or {}
    lines = [
        "# Phase 7F — OpenCV blocking vectorization",
        "",
        f"- Parity passed: **{report.get('parity_passed')}**",
        f"- Optimized path activated: **{report.get('activated')}**",
        f"- Images: **{report.get('n_images')}**",
        f"- Abs tolerance: `{report.get('abs_tol')}`",
        "",
        "## Benchmark (measured)",
        "",
        f"- Blocking loop mean: **{(b.get('blocking_loop') or {}).get('mean_ms')}** ms",
        f"- Blocking vectorized mean: **{(b.get('blocking_vectorized') or {}).get('mean_ms')}** ms",
        f"- Blocking speedup: **{b.get('blocking_speedup_mean')}** x",
        f"- Full analyze (loop blocking) mean: **{(b.get('full_analyze_with_loop_blocking') or {}).get('mean_ms')}** ms",
        f"- Full analyze (vectorized blocking) mean: **{(b.get('full_analyze_with_vectorized_blocking') or {}).get('mean_ms')}** ms",
        f"- Full analyze speedup: **{b.get('full_analyze_speedup_mean')}** x",
        "",
        f"- Phase 7E blocking baseline mean: {b.get('phase7e_blocking_baseline_mean_ms')} ms",
        f"- Phase 7E full OpenCV baseline mean: {b.get('phase7e_full_opencv_baseline_mean_ms')} ms",
        "",
        "## Notes",
        "",
        "- No production resize/downsample.",
        "- Loop reference retained as `_blocking_artifacts_loop_reference`.",
        "- MUSIQ worker, authenticity, Flutter, XP, DB, `.env` untouched.",
        "",
    ]
    if report.get("parity_failures"):
        lines.append("## Parity failures")
        lines.append("")
        lines.append(f"- Count: {len(report['parity_failures'])}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
