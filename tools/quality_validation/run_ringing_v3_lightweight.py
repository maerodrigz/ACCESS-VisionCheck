#!/usr/bin/env python3
"""Lightweight Ringing v2 vs v3 comparison (controlled only; no SPAQ).

Does not modify production, v2, Noise/Blocking v3, human CSVs, or prior outputs.
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

from tools.quality_validation.experimental_quality_engine_ringing_v3 import (  # noqa: E402
    analyze_bgr as analyze_v3,
)
from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_bgr as analyze_v2,
)

DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"


def _clean_step(size: int = 256) -> np.ndarray:
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, : size // 2] = 40
    img[:, size // 2 :] = 220
    return img


def _apply_unsharp(img: np.ndarray, amount: float, radius: float = 1.6) -> np.ndarray:
    blur = cv2.GaussianBlur(img, (0, 0), radius)
    out = cv2.addWeighted(img, 1.0 + amount, blur, -amount, 0)
    return np.clip(out, 0, 255).astype(np.uint8)


def _apply_sinc_ringing(img: np.ndarray, strength: int) -> np.ndarray:
    kernel = np.array(
        [0.03, -0.06, 0.12, -0.22, 1.26, -0.22, 0.12, -0.06, 0.03], dtype=np.float32
    )
    kernel /= kernel.sum()
    out = img.astype(np.float32)
    for _ in range(int(strength)):
        out = cv2.filter2D(out, -1, kernel.reshape(1, -1))
        out = cv2.filter2D(out, -1, kernel.reshape(-1, 1))
    return np.clip(out, 0, 255).astype(np.uint8)


def _clean_texture(seed: int = 11, size: int = 256) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.integers(50, 200, size=(size, size), dtype=np.uint8)
    base = cv2.GaussianBlur(base, (0, 0), 2.0)
    chroma = rng.integers(90, 170, size=(size, size, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


def score_pair(img: np.ndarray) -> dict[str, Any]:
    t1 = time.perf_counter()
    a = analyze_v2(img)
    ms_v2 = (time.perf_counter() - t1) * 1000.0
    t2 = time.perf_counter()
    b = analyze_v3(img)
    ms_v3 = (time.perf_counter() - t2) * 1000.0
    return {
        "v2_amount": float(a["raw"]["near_edge_oscillation"]),
        "v2_badge": int(a["criterion_scores"]["Ringing Artifacts"]),
        "v3_amount": float(b["raw"]["ringing_amount_v3"]),
        "v3_badge": int(b["criterion_scores"]["Ringing Artifacts"]),
        "ms_v2": round(ms_v2, 2),
        "ms_v3": round(ms_v3, 2),
    }


def generally_worsens(amounts: list[float], severities: list[float], max_dips: int = 1) -> bool:
    if amounts[-1] <= amounts[0]:
        return False
    n = len(amounts)
    mean_s = sum(severities) / n
    mean_a = sum(amounts) / n
    num = sum((severities[i] - mean_s) * (amounts[i] - mean_a) for i in range(n))
    den_s = sum((s - mean_s) ** 2 for s in severities) ** 0.5
    den_a = sum((a - mean_a) ** 2 for a in amounts) ** 0.5
    if den_s == 0 or den_a == 0:
        return False
    corr = num / (den_s * den_a)
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return corr > 0.5 and dips <= max_dips


def main() -> int:
    t0 = time.perf_counter()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = DEFAULT_OUT / f"ringing_v3_lightweight_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)

    base = _clean_step()
    sinc_rows = []
    for p in (0, 1, 2, 3):
        img = base if p == 0 else _apply_sinc_ringing(base, p)
        row = {"severity": p, **score_pair(img)}
        sinc_rows.append(row)

    unsharp_rows = []
    for amt in (0.0, 1.2, 2.4):
        img = base if amt == 0 else _apply_unsharp(base, amt)
        unsharp_rows.append({"amount": amt, **score_pair(img)})

    tex = score_pair(_clean_texture())
    heavy_amt = float(sinc_rows[-1]["v3_amount"])

    amounts = [float(r["v3_amount"]) for r in sinc_rows]
    badges = [int(r["v3_badge"]) for r in sinc_rows]
    checks = [
        {
            "check": "sinc_generally_worsens_v3",
            "result": "PASS" if generally_worsens(amounts, [float(r["severity"]) for r in sinc_rows]) else "FAIL",
            "detail": [(r["severity"], r["v3_amount"], r["v3_badge"]) for r in sinc_rows],
        },
        {
            "check": "clean_step_high_badge_v3",
            "result": "PASS" if sinc_rows[0]["v3_badge"] >= 4 and sinc_rows[0]["v3_amount"] < 1.5 else "FAIL",
            "detail": sinc_rows[0],
        },
        {
            "check": "strong_sinc_worse_than_clean_v3",
            "result": (
                "PASS"
                if sinc_rows[-1]["v3_amount"] > sinc_rows[0]["v3_amount"]
                and sinc_rows[-1]["v3_badge"] <= sinc_rows[0]["v3_badge"]
                and sinc_rows[-1]["v3_badge"] <= 3
                else "FAIL"
            ),
            "detail": {"clean": sinc_rows[0], "heavy": sinc_rows[-1]},
        },
        {
            "check": "unsharp_worse_than_clean_v3",
            "result": (
                "PASS"
                if unsharp_rows[-1]["v3_amount"] > unsharp_rows[0]["v3_amount"]
                and unsharp_rows[-1]["v3_badge"] <= unsharp_rows[0]["v3_badge"]
                else "FAIL"
            ),
            "detail": unsharp_rows,
        },
        {
            "check": "texture_not_false_strong_ringing_v3",
            "result": (
                "PASS"
                if tex["v3_amount"] < heavy_amt * 0.45 and tex["v3_badge"] >= 4
                else "FAIL"
            ),
            "detail": {"texture": tex, "heavy_sinc_amount": heavy_amt},
        },
    ]
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    n_fail = len(checks) - n_pass
    overall = "PASS" if n_fail == 0 else ("MIXED" if n_pass else "FAIL")
    mean_ms_v2 = float(np.mean([r["ms_v2"] for r in sinc_rows]))
    mean_ms_v3 = float(np.mean([r["ms_v3"] for r in sinc_rows]))
    wall_s = time.perf_counter() - t0

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "diagnosis_v2": (
            "v2 near-edge |d2| under-detects real halos on ACCESS photos (humans 3, "
            "machine 4–5) and is not specific to plateau overshoot / Gibbs ripples "
            "(ρ ≈ −0.40)."
        ),
        "sinc_ladder": sinc_rows,
        "unsharp_ladder": unsharp_rows,
        "texture": tex,
        "timing_ms": {
            "mean_ms_v2": mean_ms_v2,
            "mean_ms_v3": mean_ms_v3,
            "overhead_ms_mean": mean_ms_v3 - mean_ms_v2,
        },
        "wall_seconds": round(wall_s, 3),
        "pass_fail": {"checks": checks, "n_pass": n_pass, "n_fail": n_fail, "overall": overall},
        "recommendation": (
            "Ringing v3 clears lightweight controlled gates; keep research-only. "
            "Do not replace v2 or ship to production without approved larger eval."
            if overall == "PASS"
            else "Ringing v3 needs further iteration before any promotion discussion."
        ),
        "spaq_run": False,
        "production_modified": False,
        "v2_source_modified": False,
    }
    (out_dir / "ringing_v3_lightweight.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    lines = [
        "# Ringing v3 lightweight evaluation",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Overall: **{overall}** ({n_pass} PASS / {n_fail} FAIL)",
        f"Wall seconds: {payload['wall_seconds']}",
        "",
        "## Diagnosis (v2)",
        payload["diagnosis_v2"],
        "",
        "## Sinc / Gibbs ladder",
        "",
        "| passes | v2 amount | v2 badge | v3 amount | v3 badge |",
        "|---:|---:|---:|---:|---:|",
    ]
    for r in sinc_rows:
        lines.append(
            f"| {r['severity']} | {r['v2_amount']:.4f} | {r['v2_badge']} | "
            f"{r['v3_amount']:.4f} | {r['v3_badge']} |"
        )
    lines.extend(
        [
            "",
            "## Unsharp ladder",
            "",
            "| amount | v2 amount | v2 badge | v3 amount | v3 badge |",
            "|---:|---:|---:|---:|---:|",
        ]
    )
    for r in unsharp_rows:
        lines.append(
            f"| {r['amount']} | {r['v2_amount']:.4f} | {r['v2_badge']} | "
            f"{r['v3_amount']:.4f} | {r['v3_badge']} |"
        )
    lines.extend(
        [
            "",
            "## Clean texture",
            f"- v2 amount/badge: {tex['v2_amount']:.4f} / {tex['v2_badge']}",
            f"- v3 amount/badge: {tex['v3_amount']:.4f} / {tex['v3_badge']}",
            "",
            "## Runtime (mean over sinc ladder)",
            f"- v2: {mean_ms_v2:.1f} ms",
            f"- v3 engine: {mean_ms_v3:.1f} ms",
            f"- overhead: {mean_ms_v3 - mean_ms_v2:.1f} ms",
            "",
            "## PASS/FAIL",
        ]
    )
    for c in checks:
        lines.append(f"- `{c['check']}`: **{c['result']}**")
    lines.extend(["", "## Recommendation", payload["recommendation"], ""])
    (out_dir / "RINGING_V3_LIGHTWEIGHT_REPORT.md").write_text("\n".join(lines), encoding="utf-8")
    print(
        json.dumps(
            {
                "status": "ok",
                "output_dir": str(out_dir),
                "overall": overall,
                "wall_seconds": payload["wall_seconds"],
                "mean_ms_v2": mean_ms_v2,
                "mean_ms_v3": mean_ms_v3,
            },
            indent=2,
        )
    )
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
