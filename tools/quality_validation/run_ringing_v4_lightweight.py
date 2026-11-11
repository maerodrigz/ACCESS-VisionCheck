#!/usr/bin/env python3
"""Lightweight Ringing v4 controlled evaluation (no SPAQ / no pilot tuning)."""

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

from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_bgr as analyze_v2,
)
from tools.quality_validation.experimental_ringing_v3 import (  # noqa: E402
    estimate_ringing_bgr as estimate_v3,
)
from tools.quality_validation.experimental_ringing_v4_halo import (  # noqa: E402
    estimate_ringing_bgr as estimate_v4,
)
from tools.quality_validation.scoring_candidates import equal_bin_1_5  # noqa: E402

DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"


def _clean_step(size: int = 256) -> np.ndarray:
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, : size // 2] = 40
    img[:, size // 2 :] = 220
    return img


def _unsharp(img: np.ndarray, amount: float) -> np.ndarray:
    blur = cv2.GaussianBlur(img, (0, 0), 1.6)
    return np.clip(cv2.addWeighted(img, 1.0 + amount, blur, -amount, 0), 0, 255).astype(np.uint8)


def _sinc(img: np.ndarray, strength: int) -> np.ndarray:
    kernel = np.array(
        [0.03, -0.06, 0.12, -0.22, 1.26, -0.22, 0.12, -0.06, 0.03], dtype=np.float32
    )
    kernel /= kernel.sum()
    out = img.astype(np.float32)
    for _ in range(int(strength)):
        out = cv2.filter2D(out, -1, kernel.reshape(1, -1))
        out = cv2.filter2D(out, -1, kernel.reshape(-1, 1))
    return np.clip(out, 0, 255).astype(np.uint8)


def _texture(seed: int = 11) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = cv2.GaussianBlur(rng.integers(50, 200, (256, 256), dtype=np.uint8), (0, 0), 2.0)
    chroma = rng.integers(90, 170, (256, 256, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


def _jpeg_grad(quality: int = 15) -> np.ndarray:
    yy, xx = np.mgrid[0:256, 0:256]
    grad = np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )
    buf = cv2.imencode(".jpg", grad, [int(cv2.IMWRITE_JPEG_QUALITY), int(quality)])[1]
    return cv2.imdecode(buf, cv2.IMREAD_COLOR)


def _score(img: np.ndarray) -> dict[str, Any]:
    t0 = time.perf_counter()
    v4 = estimate_v4(img)
    ms4 = (time.perf_counter() - t0) * 1000.0
    t1 = time.perf_counter()
    v3 = estimate_v3(img)
    ms3 = (time.perf_counter() - t1) * 1000.0
    t2 = time.perf_counter()
    v2 = analyze_v2(img)
    ms2 = (time.perf_counter() - t2) * 1000.0
    return {
        "v4_amount": float(v4["ringing_amount"]),
        "v4_badge": equal_bin_1_5(float(v4["quality_cleanliness_0_1"])),
        "v4_reliable": bool(v4["reliable_edge_profile"]),
        "v4_limitation": v4.get("limitation"),
        "v4_n_bipolar": int(v4.get("n_with_bipolar_lobes") or 0),
        "v3_amount": float(v3["ringing_amount"]),
        "v3_badge": equal_bin_1_5(float(v3["quality_cleanliness_0_1"])),
        "v2_amount": float(v2["raw"]["near_edge_oscillation"]),
        "v2_badge": int(v2["criterion_scores"]["Ringing Artifacts"]),
        "ms_v4": round(ms4, 2),
        "ms_v3": round(ms3, 2),
        "ms_v2": round(ms2, 2),
    }


def _worsens(amounts: list[float], sevs: list[float], max_dips: int = 1) -> bool:
    if amounts[-1] <= amounts[0]:
        return False
    n = len(amounts)
    ms, ma = sum(sevs) / n, sum(amounts) / n
    num = sum((sevs[i] - ms) * (amounts[i] - ma) for i in range(n))
    dens = sum((s - ms) ** 2 for s in sevs) ** 0.5
    dena = sum((a - ma) ** 2 for a in amounts) ** 0.5
    if dens == 0 or dena == 0:
        return False
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return num / (dens * dena) > 0.5 and dips <= max_dips


def main() -> int:
    print("[START] Ringing v4 lightweight controlled eval", flush=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = DEFAULT_OUT / f"ringing_v4_lightweight_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)
    t_wall = time.perf_counter()
    base = _clean_step()

    sinc_rows = []
    for s in (0, 1, 2, 3):
        print(f"[SINC] strength={s}", flush=True)
        img = base if s == 0 else _sinc(base, s)
        sinc_rows.append({"severity": s, **_score(img)})

    unsharp_rows = []
    for a in (0.0, 1.2, 2.4):
        print(f"[UNSHARP] amount={a}", flush=True)
        img = base if a == 0 else _unsharp(base, a)
        unsharp_rows.append({"amount": a, **_score(img)})

    print("[TEXTURE]", flush=True)
    tex = _score(_texture())
    print("[JPEG]", flush=True)
    jpeg = _score(_jpeg_grad(15))
    print("[FLAT limitation]", flush=True)
    flat = _score(np.full((64, 64, 3), 128, dtype=np.uint8))

    checks = [
        {
            "check": "clean_step_high_badge_v4",
            "result": "PASS" if sinc_rows[0]["v4_badge"] >= 4 and sinc_rows[0]["v4_amount"] < 2.0 else "FAIL",
        },
        {
            "check": "sinc_generally_worsens_v4",
            "result": "PASS"
            if _worsens([r["v4_amount"] for r in sinc_rows], [float(r["severity"]) for r in sinc_rows])
            else "FAIL",
        },
        {
            "check": "unsharp_generally_worsens_v4",
            "result": "PASS"
            if _worsens([r["v4_amount"] for r in unsharp_rows], [float(r["amount"]) for r in unsharp_rows])
            else "FAIL",
        },
        {
            "check": "texture_not_false_strong_v4",
            "result": "PASS"
            if tex["v4_amount"] < sinc_rows[2]["v4_amount"] * 0.45 + 1e-6 and tex["v4_badge"] >= 4
            else "FAIL",
        },
        {
            "check": "jpeg_not_strong_ringing_v4",
            "result": "PASS"
            if jpeg["v4_amount"] < unsharp_rows[-1]["v4_amount"] * 0.75 + 0.5 and jpeg["v4_badge"] >= 3
            else "FAIL",
        },
        {
            "check": "limitation_reported_without_edges",
            "result": "PASS" if flat["v4_reliable"] is False and flat["v4_limitation"] else "FAIL",
        },
    ]
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    overall = "PASS" if n_pass == len(checks) else ("MIXED" if n_pass else "FAIL")
    timing = {
        "mean_ms_v4": float(np.mean([r["ms_v4"] for r in sinc_rows])),
        "mean_ms_v3": float(np.mean([r["ms_v3"] for r in sinc_rows])),
        "mean_ms_v2": float(np.mean([r["ms_v2"] for r in sinc_rows])),
    }
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "note": "Artifact-detection gates on controlled synthetics only. Not human rating accuracy.",
        "fitted_on_access_pilot": False,
        "fitted_on_spaq": False,
        "sinc_ladder": sinc_rows,
        "unsharp_ladder": unsharp_rows,
        "texture": tex,
        "jpeg": jpeg,
        "flat_limitation": flat,
        "timing_ms": timing,
        "wall_seconds": round(time.perf_counter() - t_wall, 3),
        "pass_fail": {"checks": checks, "n_pass": n_pass, "n_fail": len(checks) - n_pass, "overall": overall},
        "recommendation": (
            "Ringing v4 clears lightweight artifact gates; research-only. Await approval before SPAQ/pilot."
            if overall == "PASS"
            else "Ringing v4 needs iteration before any broader evaluation."
        ),
    }
    (out_dir / "ringing_v4_lightweight.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    lines = [
        "# Ringing v4 lightweight evaluation",
        "",
        f"Overall: **{overall}** ({n_pass}/{len(checks)} PASS)",
        f"Wall seconds: {payload['wall_seconds']}",
        "",
        "Distinction: these gates measure **artifact detection** on synthetics, not ACCESS human rating accuracy.",
        "",
        "## Sinc ladder",
        "| sev | v2 amt/badge | v3 amt/badge | v4 amt/badge | bipolar | ms_v4 |",
        "|---:|---:|---:|---:|---:|---:|",
    ]
    for r in sinc_rows:
        lines.append(
            f"| {r['severity']} | {r['v2_amount']:.3f}/{r['v2_badge']} | {r['v3_amount']:.3f}/{r['v3_badge']} | "
            f"{r['v4_amount']:.3f}/{r['v4_badge']} | {r['v4_n_bipolar']} | {r['ms_v4']:.1f} |"
        )
    lines.extend(["", "## Unsharp ladder", "| amt | v2 | v3 | v4 |", "|---:|---:|---:|---:|"])
    for r in unsharp_rows:
        lines.append(
            f"| {r['amount']} | {r['v2_amount']:.3f}/{r['v2_badge']} | {r['v3_amount']:.3f}/{r['v3_badge']} | "
            f"{r['v4_amount']:.3f}/{r['v4_badge']} |"
        )
    lines.extend(["", "## PASS/FAIL"])
    for c in checks:
        lines.append(f"- `{c['check']}`: **{c['result']}**")
    lines.extend(
        [
            "",
            f"## Runtime means (sinc set): v2 {timing['mean_ms_v2']:.1f} ms, "
            f"v3 {timing['mean_ms_v3']:.1f} ms, v4 {timing['mean_ms_v4']:.1f} ms",
            "",
            "## Recommendation",
            payload["recommendation"],
            "",
        ]
    )
    (out_dir / "RINGING_V4_LIGHTWEIGHT_REPORT.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"status": "ok", "overall": overall, "output_dir": str(out_dir), **timing}, indent=2), flush=True)
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
