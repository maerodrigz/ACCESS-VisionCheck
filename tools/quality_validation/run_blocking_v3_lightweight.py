#!/usr/bin/env python3
"""Lightweight Blocking v2 vs v3 comparison (controlled JPEG only; no SPAQ).

Does not modify production, v2/v3 Noise engines, human CSVs, or prior outputs.
"""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.experimental_quality_engine_blocking_v3 import (  # noqa: E402
    analyze_image_bytes as analyze_v3_bytes,
)
from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_image_bytes as analyze_v2_bytes,
)

DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"
JPEG_QUALITIES = (95, 75, 50, 25, 10)


def _smooth_gradient(size: int = 256) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    return np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )


def _clean_texture(seed: int = 7, size: int = 256) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.integers(40, 220, size=(size, size), dtype=np.uint8)
    base = cv2.GaussianBlur(base, (0, 0), 2.5)
    chroma = rng.integers(90, 160, size=(size, size, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


def jpeg_ladder(img: np.ndarray) -> tuple[list[dict[str, Any]], dict[str, float]]:
    rows: list[dict[str, Any]] = []
    times_v2: list[float] = []
    times_v3: list[float] = []
    for q in JPEG_QUALITIES:
        buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), int(q)])[1].tobytes()
        t1 = time.perf_counter()
        a = analyze_v2_bytes(buf)
        times_v2.append((time.perf_counter() - t1) * 1000.0)
        t2 = time.perf_counter()
        b = analyze_v3_bytes(buf)
        times_v3.append((time.perf_counter() - t2) * 1000.0)
        assert a is not None and b is not None
        rows.append(
            {
                "jpeg_quality": q,
                "v2_amount": float(a["raw"]["smooth_weighted_seam_delta"]),
                "v2_badge": int(a["criterion_scores"]["Blocking Artifacts"]),
                "v3_amount": float(b["raw"]["blocking_amount_v3"]),
                "v3_badge": int(b["criterion_scores"]["Blocking Artifacts"]),
                "ms_v2": round(times_v2[-1], 2),
                "ms_v3": round(times_v3[-1], 2),
            }
        )
    timing = {
        "mean_ms_v2": float(np.mean(times_v2)),
        "mean_ms_v3": float(np.mean(times_v3)),
        "overhead_ms_mean": float(np.mean(times_v3) - np.mean(times_v2)),
    }
    return rows, timing


def generally_worsens(rows: list[dict[str, Any]], amount_key: str, max_local_dips: int = 1) -> bool:
    amounts = [float(r[amount_key]) for r in rows]
    qualities = [int(r["jpeg_quality"]) for r in rows]
    if amounts[-1] <= amounts[0]:
        return False
    n = len(amounts)
    mean_q = sum(qualities) / n
    mean_a = sum(amounts) / n
    num = sum((qualities[i] - mean_q) * (amounts[i] - mean_a) for i in range(n))
    den_q = sum((q - mean_q) ** 2 for q in qualities) ** 0.5
    den_a = sum((a - mean_a) ** 2 for a in amounts) ** 0.5
    if den_q == 0 or den_a == 0:
        return False
    corr = num / (den_q * den_a)
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return corr < -0.5 and dips <= max_local_dips


def main() -> int:
    t0 = time.perf_counter()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = DEFAULT_OUT / f"blocking_v3_lightweight_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)

    grad_rows, grad_timing = jpeg_ladder(_smooth_gradient())
    tex = _clean_texture()
    tex_hq = cv2.imencode(".jpg", tex, [int(cv2.IMWRITE_JPEG_QUALITY), 95])[1].tobytes()
    tex_v2 = analyze_v2_bytes(tex_hq)
    tex_v3 = analyze_v3_bytes(tex_hq)
    assert tex_v2 is not None and tex_v3 is not None
    heavy_amt = float(grad_rows[-1]["v3_amount"])
    tex_amt = float(tex_v3["raw"]["blocking_amount_v3"])

    checks = [
        {
            "check": "jpeg_amounts_generally_worsen_v3",
            "result": "PASS" if generally_worsens(grad_rows, "v3_amount") else "FAIL",
            "detail": [(r["jpeg_quality"], r["v3_amount"], r["v3_badge"]) for r in grad_rows],
        },
        {
            "check": "q10_worse_than_q95_v3",
            "result": (
                "PASS"
                if grad_rows[-1]["v3_amount"] > grad_rows[0]["v3_amount"]
                and grad_rows[-1]["v3_badge"] <= grad_rows[0]["v3_badge"]
                and grad_rows[0]["v3_badge"] >= 4
                and grad_rows[-1]["v3_badge"] <= 2
                else "FAIL"
            ),
            "detail": {"q95": grad_rows[0], "q10": grad_rows[-1]},
        },
        {
            "check": "texture_not_false_strong_blocking_v3",
            "result": (
                "PASS"
                if tex_amt < heavy_amt * 0.45 and int(tex_v3["criterion_scores"]["Blocking Artifacts"]) >= 4
                else "FAIL"
            ),
            "detail": {
                "texture_amount": tex_amt,
                "texture_badge": int(tex_v3["criterion_scores"]["Blocking Artifacts"]),
                "q10_amount": heavy_amt,
                "v2_texture_amount": float(tex_v2["raw"]["smooth_weighted_seam_delta"]),
                "v2_texture_badge": int(tex_v2["criterion_scores"]["Blocking Artifacts"]),
            },
        },
        {
            "check": "v3_separates_q95_q10",
            "result": (
                "PASS"
                if (grad_rows[-1]["v3_amount"] - grad_rows[0]["v3_amount"]) > 0.5
                else "FAIL"
            ),
            "detail": grad_rows[-1]["v3_amount"] - grad_rows[0]["v3_amount"],
        },
        {
            "check": "v3_delta_competes_with_v2",
            "result": (
                "PASS"
                if (grad_rows[-1]["v3_amount"] - grad_rows[0]["v3_amount"])
                >= 0.5 * max(grad_rows[-1]["v2_amount"] - grad_rows[0]["v2_amount"], 1e-6)
                else "FAIL"
            ),
            "detail": {
                "v3_delta": grad_rows[-1]["v3_amount"] - grad_rows[0]["v3_amount"],
                "v2_delta": grad_rows[-1]["v2_amount"] - grad_rows[0]["v2_amount"],
            },
        },
    ]
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    n_fail = len(checks) - n_pass
    overall = "PASS" if n_fail == 0 else ("MIXED" if n_pass else "FAIL")
    wall_s = time.perf_counter() - t0

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "diagnosis_v2": (
            "v2 absolute smooth-weighted seam |Δ| confuses natural structure with JPEG "
            "blocking; ACCESS pilot humans mostly 4–5 while v2 under-scores clean photos "
            "(ρ ≈ −0.33)."
        ),
        "jpeg_ladder_smooth_gradient": grad_rows,
        "texture_hq": {
            "v2_amount": float(tex_v2["raw"]["smooth_weighted_seam_delta"]),
            "v2_badge": int(tex_v2["criterion_scores"]["Blocking Artifacts"]),
            "v3_amount": tex_amt,
            "v3_badge": int(tex_v3["criterion_scores"]["Blocking Artifacts"]),
        },
        "timing_ms": grad_timing,
        "wall_seconds": round(wall_s, 3),
        "pass_fail": {"checks": checks, "n_pass": n_pass, "n_fail": n_fail, "overall": overall},
        "recommendation": (
            "Blocking v3 clears lightweight JPEG/texture gates; keep research-only. "
            "Do not replace v2 or ship to production without SPAQ/pilot approval."
            if overall == "PASS"
            else "Blocking v3 needs further iteration before any promotion discussion."
        ),
        "spaq_run": False,
        "production_modified": False,
        "v2_source_modified": False,
    }
    (out_dir / "blocking_v3_lightweight.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    lines = [
        "# Blocking v3 lightweight evaluation",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Overall: **{overall}** ({n_pass} PASS / {n_fail} FAIL)",
        f"Wall seconds: {payload['wall_seconds']}",
        "",
        "## Diagnosis (v2)",
        payload["diagnosis_v2"],
        "",
        "## JPEG ladder (smooth gradient)",
        "",
        "| Q | v2 amount | v2 badge | v3 amount | v3 badge |",
        "|---:|---:|---:|---:|---:|",
    ]
    for r in grad_rows:
        lines.append(
            f"| {r['jpeg_quality']} | {r['v2_amount']:.4f} | {r['v2_badge']} | "
            f"{r['v3_amount']:.4f} | {r['v3_badge']} |"
        )
    lines.extend(
        [
            "",
            "## Clean texture (JPEG Q95)",
            f"- v2 amount/badge: {payload['texture_hq']['v2_amount']:.4f} / {payload['texture_hq']['v2_badge']}",
            f"- v3 amount/badge: {payload['texture_hq']['v3_amount']:.4f} / {payload['texture_hq']['v3_badge']}",
            "",
            "## Runtime (mean over ladder images)",
            f"- v2: {grad_timing['mean_ms_v2']:.1f} ms",
            f"- v3 engine: {grad_timing['mean_ms_v3']:.1f} ms",
            f"- overhead: {grad_timing['overhead_ms_mean']:.1f} ms",
            "",
            "## PASS/FAIL",
        ]
    )
    for c in checks:
        lines.append(f"- `{c['check']}`: **{c['result']}**")
    lines.extend(["", "## Recommendation", payload["recommendation"], ""])
    (out_dir / "BLOCKING_V3_LIGHTWEIGHT_REPORT.md").write_text("\n".join(lines), encoding="utf-8")
    print(
        json.dumps(
            {
                "status": "ok",
                "output_dir": str(out_dir),
                "overall": overall,
                "wall_seconds": payload["wall_seconds"],
                "mean_ms_v2": grad_timing["mean_ms_v2"],
                "mean_ms_v3": grad_timing["mean_ms_v3"],
            },
            indent=2,
        )
    )
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
