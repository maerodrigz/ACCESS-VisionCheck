#!/usr/bin/env python3
"""Compare experimental Noise v2 vs v3 (research-only).

Does not fit thresholds on SPAQ or ACCESS pilot. Does not modify production,
v2 source, human CSVs, or prior experiment folders.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_image_bytes as analyze_v2_bytes,
)
from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_bgr as analyze_v2_bgr,
)
from tools.quality_validation.experimental_quality_engine_v3 import (  # noqa: E402
    analyze_image_bytes as analyze_v3_bytes,
)
from tools.quality_validation.experimental_quality_engine_v3 import (  # noqa: E402
    analyze_bgr as analyze_v3_bgr,
)
from tools.quality_validation.metrics import pearson_spearman  # noqa: E402

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
SPAQ_IMAGES = SPAQ_ROOT / "images"
SPAQ_HUMAN = SPAQ_ROOT / "metadata" / "human_ratings_200.csv"
PILOT_CONSENSUS = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "human_consensus_by_image.csv"
)
PILOT_ORIGINALS = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "originals"
DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def _hist(values: list[int]) -> dict[str, int]:
    counts = Counter(int(v) for v in values)
    return {str(i): int(counts.get(i, 0)) for i in range(1, 6)}


def _corr(xs: list[float], ys: list[float]) -> dict[str, Any]:
    if len(xs) < 3:
        return {"n": len(xs), "spearman_r": None, "pearson_r": None}
    c = pearson_spearman(xs, ys)
    return {
        "n": len(xs),
        "spearman_r": c.get("spearman_r"),
        "spearman_p": c.get("spearman_p"),
        "pearson_r": c.get("pearson_r"),
        "pearson_p": c.get("pearson_p"),
    }


def load_csv_map(path: Path, key: str) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {(row.get(key) or "").strip(): row for row in csv.DictReader(handle) if row.get(key)}


def synthetic_suite() -> dict[str, Any]:
    import cv2

    rng = np.random.default_rng(0)
    flat = np.full((256, 256, 3), 120, dtype=np.uint8)
    yy, xx = np.mgrid[0:256, 0:256]
    tex = np.zeros((256, 256, 3), dtype=np.uint8)
    tex[:, :, 0] = (xx * 5) % 256
    tex[:, :, 1] = (yy * 5) % 256
    tex[:, :, 2] = ((xx + yy) * 3) % 256

    awgn_rows = []
    amounts_v2 = []
    amounts_v3 = []
    for sigma in (0, 5, 10, 20, 40):
        img = flat if sigma == 0 else np.clip(
            flat.astype(np.int16) + rng.normal(0, sigma, flat.shape).astype(np.int16),
            0,
            255,
        ).astype(np.uint8)
        a = analyze_v2_bgr(img)
        b = analyze_v3_bgr(img)
        amounts_v2.append(float(a["raw"]["homogeneous_residual_std"]))
        amounts_v3.append(float(b["raw"]["noise_amount_v3"]))
        awgn_rows.append(
            {
                "sigma": sigma,
                "v2_amount": amounts_v2[-1],
                "v2_badge": a["criterion_scores"]["Noise"],
                "v3_amount": amounts_v3[-1],
                "v3_badge": b["criterion_scores"]["Noise"],
            }
        )

    # Chroma ladder on a panel with a flat surround.
    panel = flat.copy()
    panel[64:192, 64:192] = 150
    chroma_rows = []
    for sigma in (0, 8, 16, 24):
        yuv = cv2.cvtColor(panel, cv2.COLOR_BGR2YUV).astype(np.int16)
        if sigma:
            yuv[:, :, 1] += rng.normal(0, sigma, yuv[:, :, 1].shape).astype(np.int16)
            yuv[:, :, 2] += rng.normal(0, sigma, yuv[:, :, 2].shape).astype(np.int16)
        img = cv2.cvtColor(np.clip(yuv, 0, 255).astype(np.uint8), cv2.COLOR_YUV2BGR)
        a = analyze_v2_bgr(img)
        b = analyze_v3_bgr(img)
        chroma_rows.append(
            {
                "chroma_sigma": sigma,
                "v2_amount": float(a["raw"]["homogeneous_residual_std"]),
                "v2_badge": a["criterion_scores"]["Noise"],
                "v3_amount": float(b["raw"]["noise_amount_v3"]),
                "v3_badge": b["criterion_scores"]["Noise"],
            }
        )

    # Low-light AWGN.
    dark = np.full((256, 256, 3), 40, dtype=np.uint8)
    lowlight_rows = []
    for sigma in (0, 6, 12, 18):
        img = dark if sigma == 0 else np.clip(
            dark.astype(np.int16) + rng.normal(0, sigma, dark.shape).astype(np.int16),
            0,
            255,
        ).astype(np.uint8)
        a = analyze_v2_bgr(img)
        b = analyze_v3_bgr(img)
        lowlight_rows.append(
            {
                "sigma": sigma,
                "v2_amount": float(a["raw"]["homogeneous_residual_std"]),
                "v2_badge": a["criterion_scores"]["Noise"],
                "v3_amount": float(b["raw"]["noise_amount_v3"]),
                "v3_badge": b["criterion_scores"]["Noise"],
            }
        )

    tex_v3 = float(analyze_v3_bgr(tex)["raw"]["noise_amount_v3"])
    awgn20_v3 = amounts_v3[3]
    return {
        "awgn_luma": awgn_rows,
        "awgn_monotone_v2": all(amounts_v2[i] <= amounts_v2[i + 1] for i in range(len(amounts_v2) - 1)),
        "awgn_monotone_v3": all(amounts_v3[i] <= amounts_v3[i + 1] for i in range(len(amounts_v3) - 1)),
        "chroma": chroma_rows,
        "chroma_v3_rises": chroma_rows[-1]["v3_amount"] > chroma_rows[0]["v3_amount"],
        "chroma_v2_delta": chroma_rows[-1]["v2_amount"] - chroma_rows[0]["v2_amount"],
        "chroma_v3_delta": chroma_rows[-1]["v3_amount"] - chroma_rows[0]["v3_amount"],
        "lowlight": lowlight_rows,
        "lowlight_monotone_v3": all(
            lowlight_rows[i]["v3_amount"] <= lowlight_rows[i + 1]["v3_amount"]
            for i in range(len(lowlight_rows) - 1)
        ),
        "texture_amount_v3": tex_v3,
        "awgn20_amount_v3": awgn20_v3,
        "texture_not_false_strong_noise": awgn20_v3 > tex_v3 * 3.0,
    }


def score_spaq(limit: int | None = None) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    humans = load_csv_map(SPAQ_HUMAN, "media_id")
    rows: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    times_v2: list[float] = []
    times_v3: list[float] = []
    media_ids = sorted(humans.keys())
    if limit is not None:
        media_ids = media_ids[:limit]
    for mid in media_ids:
        key = humans[mid].get("source_media_key") or ""
        path = SPAQ_IMAGES / key
        rec: dict[str, Any] = {
            "media_id": mid,
            "source_media_key": key,
            "attr_noisiness_raw": humans[mid].get("attr_noisiness_raw", ""),
            "mos_quality_raw": humans[mid].get("mos_quality_raw", ""),
        }
        if not path.is_file():
            rec["status"] = "missing"
            rows.append(rec)
            continue
        content = path.read_bytes()
        t1 = time.perf_counter()
        a = analyze_v2_bytes(content)
        times_v2.append((time.perf_counter() - t1) * 1000.0)
        t2 = time.perf_counter()
        b = analyze_v3_bytes(content)
        times_v3.append((time.perf_counter() - t2) * 1000.0)
        if a is None or b is None:
            rec["status"] = "failed"
            rows.append(rec)
            continue
        rec.update(
            {
                "status": "ok",
                "v2_noise_badge": a["criterion_scores"]["Noise"],
                "v2_noise_amount": a["raw"].get("homogeneous_residual_std"),
                "v3_noise_badge": b["criterion_scores"]["Noise"],
                "v3_noise_amount": b["raw"].get("noise_amount_v3"),
                "v3_luma_sigma": b["raw"].get("noise_luma_sigma_v3"),
                "v3_chroma_sigma": b["raw"].get("noise_chroma_sigma_v3"),
                "v3_n_flat_blocks": b["raw"].get("noise_n_flat_blocks_v3"),
                "ms_v2": round(times_v2[-1], 2),
                "ms_v3": round(times_v3[-1], 2),
            }
        )
        rows.append(rec)
    ok = [r for r in rows if r.get("status") == "ok"]
    # SPAQ noisiness: high = more noise. Cleanliness badge high = cleaner => invert attr.
    hv2: list[float] = []
    hv3: list[float] = []
    y2: list[float] = []
    y3: list[float] = []
    for r in ok:
        try:
            h = 100.0 - float(r["attr_noisiness_raw"])
            hv2.append(h)
            hv3.append(h)
            y2.append(float(r["v2_noise_badge"]))
            y3.append(float(r["v3_noise_badge"]))
        except (TypeError, ValueError):
            continue
    summary = {
        "n_ok": len(ok),
        "n_requested": len(media_ids),
        "wall_seconds": round(time.perf_counter() - t0, 3),
        "mean_ms_v2": float(np.mean(times_v2)) if times_v2 else None,
        "mean_ms_v3": float(np.mean(times_v3)) if times_v3 else None,
        "runtime_overhead_ms_mean": (
            float(np.mean(times_v3) - np.mean(times_v2)) if times_v2 and times_v3 else None
        ),
        "badge_hist_v2": _hist([int(r["v2_noise_badge"]) for r in ok]),
        "badge_hist_v3": _hist([int(r["v3_noise_badge"]) for r in ok]),
        "spaq_cleanliness_corr_v2": _corr(hv2, y2),
        "spaq_cleanliness_corr_v3": _corr(hv3, y3),
    }
    return rows, summary


def score_access_pilot() -> dict[str, Any]:
    if not PILOT_CONSENSUS.is_file():
        return {"available": False}
    consensus = load_csv_map(PILOT_CONSENSUS, "media_id")
    rows = []
    for mid in sorted(consensus.keys()):
        path = PILOT_ORIGINALS / f"{mid}.jpg"
        if not path.is_file():
            continue
        content = path.read_bytes()
        a = analyze_v2_bytes(content)
        b = analyze_v3_bytes(content)
        if a is None or b is None:
            continue
        hum = consensus[mid].get("noise_median", "")
        rows.append(
            {
                "media_id": mid,
                "human_noise_median": hum,
                "v2_noise_badge": a["criterion_scores"]["Noise"],
                "v2_noise_amount": a["raw"].get("homogeneous_residual_std"),
                "v3_noise_badge": b["criterion_scores"]["Noise"],
                "v3_noise_amount": b["raw"].get("noise_amount_v3"),
            }
        )
    hx: list[float] = []
    y2: list[float] = []
    y3: list[float] = []
    for r in rows:
        try:
            h = float(r["human_noise_median"])
            hx.append(h)
            y2.append(float(r["v2_noise_badge"]))
            y3.append(float(r["v3_noise_badge"]))
        except (TypeError, ValueError):
            continue
    return {
        "available": True,
        "role": "frozen_secondary_check_not_for_tuning",
        "n": len(rows),
        "corr_v2": _corr(hx, y2),
        "corr_v3": _corr(hx, y3),
        "per_image": rows,
        "disclaimer": "ACCESS pilot was not used to choose Noise v3 thresholds.",
    }


def pass_fail(synth: dict[str, Any], spaq: dict[str, Any], pilot: dict[str, Any]) -> dict[str, Any]:
    checks = []

    def add(name: str, ok: bool, detail: str) -> None:
        checks.append({"check": name, "result": "PASS" if ok else "FAIL", "detail": detail})

    add(
        "synthetic_awgn_monotone_v3",
        bool(synth["awgn_monotone_v3"]),
        f"v3 amounts={ [r['v3_amount'] for r in synth['awgn_luma']] }",
    )
    add(
        "synthetic_chroma_sensitivity_v3",
        bool(synth["chroma_v3_rises"]) and synth["chroma_v3_delta"] > synth["chroma_v2_delta"],
        f"v3_delta={synth['chroma_v3_delta']:.3f} v2_delta={synth['chroma_v2_delta']:.3f}",
    )
    add(
        "synthetic_texture_not_false_strong_noise",
        bool(synth["texture_not_false_strong_noise"]),
        f"texture={synth['texture_amount_v3']:.3f} awgn20={synth['awgn20_amount_v3']:.3f}",
    )
    add(
        "synthetic_lowlight_monotone_v3",
        bool(synth["lowlight_monotone_v3"]),
        f"lowlight={synth['lowlight']}",
    )
    s2 = spaq["spaq_cleanliness_corr_v2"].get("spearman_r")
    s3 = spaq["spaq_cleanliness_corr_v3"].get("spearman_r")
    add(
        "spaq_proxy_corr_nonnegative_v3",
        s3 is not None and s3 >= 0.0,
        f"v2_rho={s2} v3_rho={s3}",
    )
    add(
        "spaq_proxy_corr_improved_or_close_v3",
        s2 is not None and s3 is not None and s3 >= (s2 - 0.05),
        f"v2_rho={s2} v3_rho={s3}",
    )
    if pilot.get("available"):
        p2 = pilot["corr_v2"].get("spearman_r")
        p3 = pilot["corr_v3"].get("spearman_r")
        add(
            "access_pilot_corr_improved_descriptive",
            p2 is not None and p3 is not None and p3 > p2,
            f"v2_rho={p2} v3_rho={p3} (not for tuning)",
        )
        add(
            "access_pilot_corr_nonnegative_v3",
            p3 is not None and p3 >= 0.0,
            f"v3_rho={p3}",
        )
    n_pass = sum(1 for c in checks if c["result"] == "PASS")
    return {
        "checks": checks,
        "n_pass": n_pass,
        "n_fail": len(checks) - n_pass,
        "overall": "PASS" if n_pass == len(checks) else "MIXED" if n_pass else "FAIL",
    }


def write_report(path: Path, payload: dict[str, Any]) -> None:
    synth = payload["synthetic"]
    spaq = payload["spaq_summary"]
    pilot = payload["access_pilot"]
    verdict = payload["pass_fail"]
    lines = [
        "# Noise v3 evaluation report",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Output: `{payload['output_dir']}`",
        "",
        "## Safety",
        "",
        "- Production scoring unchanged.",
        "- `experimental_quality_engine_v2.py` unchanged.",
        "- Human CSVs and prior experiment outputs unchanged.",
        "- Thresholds not fitted on SPAQ or ACCESS pilot.",
        "",
        "## Diagnosis of v2 Noise",
        "",
        "- Luma-only residual under-detects chroma noise.",
        "- Homogeneous residual still admits texture/JPEG/sharpening leakage.",
        "- ACCESS pilot often shows machine badge 5 when humans rate ~3 (under-detection).",
        "",
        "## Synthetic results",
        "",
        f"- AWGN monotone v3: **{synth['awgn_monotone_v3']}**",
        f"- Chroma v3 delta: **{synth['chroma_v3_delta']:.3f}** (v2 delta {synth['chroma_v2_delta']:.3f})",
        f"- Texture vs AWGN20 guard: **{synth['texture_not_false_strong_noise']}**",
        f"- Low-light monotone v3: **{synth['lowlight_monotone_v3']}**",
        "",
        "### AWGN ladder",
        "",
        "| sigma | v2 amount | v2 badge | v3 amount | v3 badge |",
        "|---:|---:|---:|---:|---:|",
    ]
    for row in synth["awgn_luma"]:
        lines.append(
            f"| {row['sigma']} | {row['v2_amount']:.3f} | {row['v2_badge']} | {row['v3_amount']:.3f} | {row['v3_badge']} |"
        )
    lines.extend(
        [
            "",
            "## SPAQ-200",
            "",
            f"- n_ok: {spaq['n_ok']}",
            f"- mean ms/image v2: {spaq['mean_ms_v2']}",
            f"- mean ms/image v3: {spaq['mean_ms_v3']}",
            f"- runtime overhead (v3-v2) mean ms: {spaq['runtime_overhead_ms_mean']}",
            f"- badge hist v2: {spaq['badge_hist_v2']}",
            f"- badge hist v3: {spaq['badge_hist_v3']}",
            f"- SPAQ cleanliness Spearman v2: {spaq['spaq_cleanliness_corr_v2'].get('spearman_r')}",
            f"- SPAQ cleanliness Spearman v3: {spaq['spaq_cleanliness_corr_v3'].get('spearman_r')}",
            "",
            "## ACCESS pilot (frozen secondary; not for tuning)",
            "",
        ]
    )
    if pilot.get("available"):
        lines.append(pilot["disclaimer"])
        lines.append(
            f"- Spearman v2: {pilot['corr_v2'].get('spearman_r')} (n={pilot['corr_v2'].get('n')})"
        )
        lines.append(
            f"- Spearman v3: {pilot['corr_v3'].get('spearman_r')} (n={pilot['corr_v3'].get('n')})"
        )
    else:
        lines.append("- Not available.")
    lines.extend(["", "## PASS/FAIL", "", f"Overall: **{verdict['overall']}**", ""])
    for c in verdict["checks"]:
        lines.append(f"- `{c['check']}`: **{c['result']}** — {c['detail']}")
    lines.extend(
        [
            "",
            "## Recommendation",
            "",
            payload["recommendation"],
            "",
            "Do not integrate into production without approval.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--skip-pilot", action="store_true")
    args = parser.parse_args(argv)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.output_root / f"noise_v3_eval_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)

    synth = synthetic_suite()
    _write_csv(out_dir / "synthetic_awgn_ladder.csv", synth["awgn_luma"])
    _write_csv(out_dir / "synthetic_chroma_ladder.csv", synth["chroma"])
    _write_csv(out_dir / "synthetic_lowlight_ladder.csv", synth["lowlight"])

    spaq_rows, spaq_summary = score_spaq(limit=args.limit)
    _write_csv(out_dir / "spaq200_noise_v2_vs_v3.csv", spaq_rows)

    pilot = {"available": False, "skipped": True}
    if not args.skip_pilot:
        pilot = score_access_pilot()
        if pilot.get("available"):
            _write_csv(out_dir / "access_pilot_noise_v2_vs_v3.csv", pilot.get("per_image") or [])

    verdict = pass_fail(synth, spaq_summary, pilot if pilot.get("available") else {})
    s2 = spaq_summary["spaq_cleanliness_corr_v2"].get("spearman_r")
    s3 = spaq_summary["spaq_cleanliness_corr_v3"].get("spearman_r")
    p2 = (pilot.get("corr_v2") or {}).get("spearman_r") if pilot.get("available") else None
    p3 = (pilot.get("corr_v3") or {}).get("spearman_r") if pilot.get("available") else None

    if verdict["overall"] == "PASS" and (p3 is None or p3 >= 0):
        rec = (
            "Noise v3 passes synthetic and SPAQ-proxy gates. "
            "Still keep research-only until a disjoint ACCESS-rubric holdout confirms non-negative agreement."
        )
    elif s3 is not None and s2 is not None and s3 >= s2 and synth["awgn_monotone_v3"]:
        rec = (
            "Noise v3 improves synthetic chroma/AWGN behavior and maintains SPAQ-proxy usefulness, "
            "but ACCESS pilot agreement remains inconclusive or negative. Do not ship to production."
        )
    else:
        rec = (
            "Noise v3 does not yet clear enough gates for promotion. Keep v2 as fallback research baseline; "
            "iterate on flat-block / chroma estimation."
        )

    payload = {
        "generated_at": _now(),
        "output_dir": str(out_dir),
        "synthetic": synth,
        "spaq_summary": spaq_summary,
        "access_pilot": {k: v for k, v in pilot.items() if k != "per_image"},
        "pass_fail": verdict,
        "recommendation": rec,
        "spaq_rho": {"v2": s2, "v3": s3},
        "pilot_rho": {"v2": p2, "v3": p3},
        "production_modified": False,
        "v2_source_modified": False,
        "fitted_on_spaq": False,
        "fitted_on_access_pilot": False,
    }
    (out_dir / "noise_v3_eval.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    write_report(out_dir / "NOISE_V3_EVAL_REPORT.md", payload)
    print(
        json.dumps(
            {
                "status": "ok",
                "output_dir": str(out_dir),
                "overall": verdict["overall"],
                "spaq_rho_v2": s2,
                "spaq_rho_v3": s3,
                "pilot_rho_v2": p2,
                "pilot_rho_v3": p3,
                "recommendation": rec,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
