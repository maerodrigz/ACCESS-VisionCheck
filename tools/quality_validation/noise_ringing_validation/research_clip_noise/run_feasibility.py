"""One-time CLIP noisiness controlled feasibility run.

Does not touch production, Flutter, EfficientNet, sandbox scoring, or locked NR ratings.
"""

from __future__ import annotations

import csv
import json
import sys
import time
import tracemalloc
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.stats import spearmanr

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from build_dev_set import SIGMAS, build_dev_set  # noqa: E402
from clip_noisiness import (  # noqa: E402
    METHOD_ID,
    MODEL_NAME,
    PRETRAINED,
    PROMPT_CLEAN,
    PROMPT_NOISY,
    ClipNoisinessEvaluator,
)


def _monotonic_increasing(values: list[float]) -> bool:
    return all(values[i] <= values[i + 1] + 1e-12 for i in range(len(values) - 1))


def _rss_mb() -> float | None:
    try:
        import resource  # Unix

        return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0
    except Exception:
        pass
    try:
        import ctypes
        from ctypes import wintypes

        class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
            _fields_ = [
                ("cb", wintypes.DWORD),
                ("PageFaultCount", wintypes.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t),
            ]

        counters = PROCESS_MEMORY_COUNTERS()
        counters.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
        handle = ctypes.windll.kernel32.GetCurrentProcess()
        if ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            return counters.WorkingSetSize / (1024.0 * 1024.0)
    except Exception:
        return None
    return None


def main() -> int:
    started = datetime.now(timezone.utc)
    out_dir = ROOT / "output" / f"clip_noise_feasibility_{started.strftime('%Y%m%dT%H%M%SZ')}"
    out_dir.mkdir(parents=True, exist_ok=True)
    dev_dir = ROOT / "dev_set"

    print("[1/4] Building synthetic development set (disjoint from NR/pilot)...")
    manifest = build_dev_set(dev_dir)

    print("[2/4] Loading OpenCLIP ViT-B/32 (openai)...")
    tracemalloc.start()
    t_load0 = time.perf_counter()
    mem0 = _rss_mb()
    evaluator = ClipNoisinessEvaluator(device="cpu")
    evaluator.load()
    t_load = time.perf_counter() - t_load0
    mem_after_load = _rss_mb()
    _, peak_traced = tracemalloc.get_traced_memory()

    print("[3/4] Scoring controlled AWGN ladder...")
    rows: list[dict] = []
    infer_ms: list[float] = []
    for item in manifest["images"]:
        path = dev_dir / item["path"]
        img = Image.open(path)
        t0 = time.perf_counter()
        result = evaluator.score_pil(img)
        dt = (time.perf_counter() - t0) * 1000.0
        infer_ms.append(dt)
        rows.append(
            {
                "image_id": item["image_id"],
                "source_id": item["source_id"],
                "sigma": item["sigma"],
                "raw_noisiness_p_noisy": round(result.noisiness, 6),
                "raw_noise_free_p": round(result.noise_free, 6),
                "infer_ms": round(dt, 2),
                "path": item["path"],
            }
        )
        print(
            f"  {item['image_id']}: noisiness={result.noisiness:.4f} "
            f"noise_free={result.noise_free:.4f} ({dt:.0f} ms)"
        )

    mem_end = _rss_mb()
    tracemalloc.stop()

    print("[4/4] Analyzing response vs sigma...")
    by_source: dict[str, list[dict]] = {}
    for r in rows:
        by_source.setdefault(r["source_id"], []).append(r)
    for lst in by_source.values():
        lst.sort(key=lambda x: x["sigma"])

    analysis: dict[str, dict] = {}
    for source_id, lst in by_source.items():
        sigmas = [float(r["sigma"]) for r in lst]
        noisiness = [float(r["raw_noisiness_p_noisy"]) for r in lst]
        rho, p = spearmanr(sigmas, noisiness)
        analysis[source_id] = {
            "spearman_rho_noisiness_vs_sigma": None if np.isnan(rho) else float(rho),
            "spearman_p": None if np.isnan(p) else float(p),
            "monotonic_nondecreasing_noisiness": _monotonic_increasing(noisiness),
            "delta_noisiness_sigma40_minus_0": float(noisiness[-1] - noisiness[0]),
            "noisiness_by_sigma": {str(int(s)): n for s, n in zip(sigmas, noisiness)},
        }

    flat = analysis.get("DEV-FLAT", {})
    flat_rho = flat.get("spearman_rho_noisiness_vs_sigma")
    flat_mono = bool(flat.get("monotonic_nondecreasing_noisiness"))
    # Pre-registered S1 from feasibility report: Spearman >= 0.80 on flat ladder.
    s1_pass = flat_rho is not None and flat_rho >= 0.80
    # Directional consistency: at least 2/3 sources have positive rho and positive delta.
    positive_sources = sum(
        1
        for a in analysis.values()
        if (a.get("spearman_rho_noisiness_vs_sigma") or 0) > 0
        and (a.get("delta_noisiness_sigma40_minus_0") or 0) > 0
    )
    direction_ok = positive_sources >= 2
    go = bool(s1_pass and direction_ok and flat_mono)

    # Write CSV
    csv_path = out_dir / "raw_noisiness_response.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "image_id",
                "source_id",
                "sigma",
                "raw_noisiness_p_noisy",
                "raw_noise_free_p",
                "infer_ms",
                "path",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    runtime = {
        "device": "cpu",
        "model_load_s": round(t_load, 3),
        "n_images": len(rows),
        "infer_ms_mean": round(float(np.mean(infer_ms)), 2),
        "infer_ms_median": round(float(np.median(infer_ms)), 2),
        "infer_ms_max": round(float(np.max(infer_ms)), 2),
        "rss_mb_before_load": mem0,
        "rss_mb_after_load": mem_after_load,
        "rss_mb_end": mem_end,
        "tracemalloc_peak_mb": round(peak_traced / (1024 * 1024), 2),
        "wall_s_total": round((datetime.now(timezone.utc) - started).total_seconds(), 2),
    }

    payload = {
        "generated_utc": started.isoformat(),
        "method_id": METHOD_ID,
        "model_name": MODEL_NAME,
        "pretrained": PRETRAINED,
        "prompts": [PROMPT_CLEAN, PROMPT_NOISY],
        "sigmas": list(SIGMAS),
        "dev_set": str(dev_dir),
        "disjoint_note": "Synthetic procedural RGB panels; never NR001-015 or frozen pilot photographs.",
        "analysis_by_source": analysis,
        "gates": {
            "S1_flat_spearman_ge_0_80": s1_pass,
            "flat_rho": flat_rho,
            "flat_monotonic": flat_mono,
            "directional_consistency_ge_2_of_3": direction_ok,
            "positive_sources": positive_sources,
        },
        "recommendation": "GO" if go else "NO-GO",
        "recommendation_meaning": (
            "Eligible for further independent evaluation only; not validated; not production-approved."
            if go
            else "Does not meet controlled-response gates; do not advance without a new approved plan."
        ),
        "runtime": runtime,
        "rows": rows,
    }
    (out_dir / "feasibility_payload.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

    report = _render_report(payload, csv_path)
    report_path = out_dir / "CLIP_NOISE_FEASIBILITY_REPORT.md"
    report_path.write_text(report, encoding="utf-8")
    # Stable pointer at package root
    (ROOT / "CLIP_NOISE_FEASIBILITY_REPORT.md").write_text(report, encoding="utf-8")

    print(f"\nOUTCOME: {payload['recommendation']}")
    print(f"Wrote {report_path}")
    return 0 if go else 2


def _render_report(payload: dict, csv_path: Path) -> str:
    a = payload["analysis_by_source"]
    rt = payload["runtime"]
    lines = [
        "# CLIP noisiness controlled feasibility report",
        "",
        f"Generated (UTC): {payload['generated_utc']}",
        f"Method: `{payload['method_id']}`",
        f"Model: OpenCLIP `{payload['model_name']}` pretrained=`{payload['pretrained']}`",
        f"Prompts (fixed): `{payload['prompts'][0]}` / `{payload['prompts'][1]}`",
        "",
        "## Scope honors",
        "",
        "- Research-only under `research_clip_noise/`",
        "- No production / Flutter / EfficientNet / sandbox / criteria changes",
        "- No NR001–NR015 or frozen-pilot photographs or human ratings",
        "- No 1–5 badge mapping; raw noisiness only",
        "- One model, one prompt pair, one controlled run",
        "",
        "## Development set",
        "",
        payload["disjoint_note"],
        "",
        f"Sources: {', '.join(a.keys())}. AWGN σ ∈ {payload['sigmas']}.",
        "",
        "## Raw noisiness response (P(noisy image))",
        "",
        "| Source | σ=0 | σ=5 | σ=10 | σ=20 | σ=40 | Spearman ρ | Monotone ↑ | Δ(40−0) |",
        "|--------|----:|----:|-----:|-----:|-----:|-----------:|:----------:|--------:|",
    ]
    for source_id, stats in a.items():
        by = stats["noisiness_by_sigma"]
        rho = stats["spearman_rho_noisiness_vs_sigma"]
        lines.append(
            "| {src} | {z:.4f} | {a:.4f} | {b:.4f} | {c:.4f} | {d:.4f} | {rho} | {mono} | {delta:.4f} |".format(
                src=source_id,
                z=by["0"],
                a=by["5"],
                b=by["10"],
                c=by["20"],
                d=by["40"],
                rho="n/a" if rho is None else f"{rho:.3f}",
                mono="yes" if stats["monotonic_nondecreasing_noisiness"] else "no",
                delta=stats["delta_noisiness_sigma40_minus_0"],
            )
        )

    g = payload["gates"]
    lines.extend(
        [
            "",
            f"Full table: `{csv_path.name}`",
            "",
            "## Gate evaluation",
            "",
            f"- S1 flat Spearman ≥ 0.80: **{'PASS' if g['S1_flat_spearman_ge_0_80'] else 'FAIL'}** (ρ={g['flat_rho']})",
            f"- Flat monotonic nondecreasing: **{'PASS' if g['flat_monotonic'] else 'FAIL'}**",
            f"- Directional consistency (≥2/3 sources positive ρ and Δ): **{'PASS' if g['directional_consistency_ge_2_of_3'] else 'FAIL'}** ({g['positive_sources']}/3)",
            "",
            "## Runtime and resources",
            "",
            f"- Device: `{rt['device']}`",
            f"- Model load: {rt['model_load_s']} s",
            f"- Inference mean/median/max: {rt['infer_ms_mean']} / {rt['infer_ms_median']} / {rt['infer_ms_max']} ms",
            f"- Images scored: {rt['n_images']}",
            f"- RSS before/after load/end (MB): {rt['rss_mb_before_load']} / {rt['rss_mb_after_load']} / {rt['rss_mb_end']}",
            f"- tracemalloc peak (MB): {rt['tracemalloc_peak_mb']}",
            f"- Wall time: {rt['wall_s_total']} s",
            "",
            "## Recommendation",
            "",
            f"**{payload['recommendation']}**",
            "",
            payload["recommendation_meaning"],
            "",
            "A GO does **not** authorize production deployment or ACCESS badge mapping.",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
