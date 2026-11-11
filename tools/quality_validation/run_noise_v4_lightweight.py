#!/usr/bin/env python3
"""Lightweight Noise v4 controlled evaluation (no SPAQ / no pilot tuning)."""

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

from tools.quality_validation.experimental_noise_v3 import (  # noqa: E402
    estimate_noise_bgr as estimate_v3,
)
from tools.quality_validation.experimental_noise_v4_pca import (  # noqa: E402
    estimate_noise_bgr as estimate_v4,
)
from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_bgr as analyze_v2,
)
from tools.quality_validation.scoring_candidates import equal_bin_1_5  # noqa: E402

DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"


def _flat(level: int = 128, size: int = 256) -> np.ndarray:
    return np.full((size, size, 3), level, dtype=np.uint8)


def _awgn(img: np.ndarray, sigma: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return np.clip(img.astype(np.float64) + rng.normal(0, sigma, img.shape), 0, 255).astype(np.uint8)


def _chroma(img: np.ndarray, sigma: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
    yuv[:, :, 1] += rng.normal(0, sigma, yuv[:, :, 1].shape)
    yuv[:, :, 2] += rng.normal(0, sigma, yuv[:, :, 2].shape)
    return cv2.cvtColor(np.clip(yuv, 0, 255).astype(np.uint8), cv2.COLOR_YUV2BGR)


def _texture(seed: int = 7) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = cv2.GaussianBlur(rng.integers(40, 220, (256, 256), dtype=np.uint8), (0, 0), 2.5)
    u = cv2.GaussianBlur(rng.integers(90, 160, (256, 256), dtype=np.uint8), (0, 0), 4.0)
    v = cv2.GaussianBlur(rng.integers(90, 160, (256, 256), dtype=np.uint8), (0, 0), 4.0)
    return np.dstack([base, u, v])


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
        "v4_amount": float(v4["noise_amount"]),
        "v4_badge": equal_bin_1_5(float(v4["quality_cleanliness_0_1"])),
        "v4_wavelet": float(v4["wavelet_hh_mad_sigma"]),
        "v4_fallback": bool(v4["used_fallback"]),
        "v3_amount": float(v3["noise_amount"]),
        "v3_badge": equal_bin_1_5(float(v3["quality_cleanliness_0_1"])),
        "v2_amount": float(v2["raw"]["homogeneous_residual_std"]),
        "v2_badge": int(v2["criterion_scores"]["Noise"]),
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
    print("[START] Noise v4 lightweight controlled eval", flush=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = DEFAULT_OUT / f"noise_v4_lightweight_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)
    t_wall = time.perf_counter()

    awgn_rows = []
    for s in (0, 5, 10, 20, 40):
        print(f"[AWGN] sigma={s}", flush=True)
        awgn_rows.append({"sigma": s, **_score(_awgn(_flat(), float(s), seed=s))})

    chroma_rows = []
    for s in (0, 8, 16, 24):
        print(f"[CHROMA] sigma={s}", flush=True)
        chroma_rows.append({"chroma_sigma": s, **_score(_chroma(_flat(), float(s), seed=100 + s))})

    low_rows = []
    for s in (0, 6, 12, 18):
        print(f"[LOWLIGHT] sigma={s}", flush=True)
        low_rows.append({"sigma": s, **_score(_awgn(_flat(level=40), float(s), seed=200 + s))})

    print("[TEXTURE]", flush=True)
    tex = _score(_texture())
    heavy = awgn_rows[-2]  # sigma 20

    checks = [
        {
            "check": "awgn_monotone_v4",
            "result": "PASS" if _worsens([r["v4_amount"] for r in awgn_rows], [float(r["sigma"]) for r in awgn_rows]) else "FAIL",
        },
        {
            "check": "chroma_raises_v4",
            "result": "PASS" if chroma_rows[-1]["v4_amount"] > chroma_rows[0]["v4_amount"] + 0.5 else "FAIL",
        },
        {
            "check": "lowlight_monotone_v4",
            "result": "PASS" if _worsens([r["v4_amount"] for r in low_rows], [float(r["sigma"]) for r in low_rows]) else "FAIL",
        },
        {
            "check": "texture_not_false_strong_v4",
            "result": "PASS" if tex["v4_amount"] < heavy["v4_amount"] * 0.55 else "FAIL",
        },
        {
            "check": "wavelet_secondary_present",
            "result": "PASS" if all(r["v4_wavelet"] >= 0 for r in awgn_rows) else "FAIL",
        },
    ]
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    overall = "PASS" if n_pass == len(checks) else ("MIXED" if n_pass else "FAIL")
    timing = {
        "mean_ms_v4": float(np.mean([r["ms_v4"] for r in awgn_rows])),
        "mean_ms_v3": float(np.mean([r["ms_v3"] for r in awgn_rows])),
        "mean_ms_v2": float(np.mean([r["ms_v2"] for r in awgn_rows])),
    }
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "note": "Artifact-detection gates on controlled synthetics only. Not human rating accuracy.",
        "fitted_on_access_pilot": False,
        "fitted_on_spaq": False,
        "awgn_ladder": awgn_rows,
        "chroma_ladder": chroma_rows,
        "lowlight_ladder": low_rows,
        "texture": tex,
        "badge_hist_hint_awgn_v4": {str(b): sum(1 for r in awgn_rows if r["v4_badge"] == b) for b in range(1, 6)},
        "timing_ms": timing,
        "wall_seconds": round(time.perf_counter() - t_wall, 3),
        "pass_fail": {"checks": checks, "n_pass": n_pass, "n_fail": len(checks) - n_pass, "overall": overall},
        "recommendation": (
            "Noise v4 clears lightweight artifact gates; research-only. Await approval before SPAQ/pilot."
            if overall == "PASS"
            else "Noise v4 needs iteration before any broader evaluation."
        ),
    }
    (out_dir / "noise_v4_lightweight.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    lines = [
        "# Noise v4 lightweight evaluation",
        "",
        f"Overall: **{overall}** ({n_pass}/{len(checks)} PASS)",
        f"Wall seconds: {payload['wall_seconds']}",
        "",
        "Distinction: these gates measure **artifact detection** on synthetics, not ACCESS human rating accuracy.",
        "",
        "## AWGN ladder",
        "| sigma | v2 amt/badge | v3 amt/badge | v4 amt/badge | wavelet | ms_v4 |",
        "|---:|---:|---:|---:|---:|---:|",
    ]
    for r in awgn_rows:
        lines.append(
            f"| {r['sigma']} | {r['v2_amount']:.3f}/{r['v2_badge']} | {r['v3_amount']:.3f}/{r['v3_badge']} | "
            f"{r['v4_amount']:.3f}/{r['v4_badge']} | {r['v4_wavelet']:.3f} | {r['ms_v4']:.1f} |"
        )
    lines.extend(["", "## PASS/FAIL"])
    for c in checks:
        lines.append(f"- `{c['check']}`: **{c['result']}**")
    lines.extend(
        [
            "",
            f"## Runtime means (AWGN set): v2 {timing['mean_ms_v2']:.1f} ms, "
            f"v3 {timing['mean_ms_v3']:.1f} ms, v4 {timing['mean_ms_v4']:.1f} ms",
            "",
            "## Recommendation",
            payload["recommendation"],
            "",
        ]
    )
    (out_dir / "NOISE_V4_LIGHTWEIGHT_REPORT.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"status": "ok", "overall": overall, "output_dir": str(out_dir), **timing}, indent=2), flush=True)
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
