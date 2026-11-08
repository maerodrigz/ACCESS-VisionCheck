#!/usr/bin/env python3
"""Phase 12A/12B SPAQ-200 benchmark. A priori metrics only. No label fitting."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
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

from tools.quality_validation.classical_quality_metrics import analyze_image_bytes as classical_analyze  # noqa: E402
from tools.quality_validation.engines import ENGINE_OPENCV, analyze_image_metrics  # noqa: E402
from tools.quality_validation.metrics import correlation_bootstrap  # noqa: E402

SPAQ_CSV = (
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "run_001" / "spaq_200_machine_scores.csv"
)
IMAGES = _TOOLKIT / "workspace" / "datasets" / "spaq" / "images"
DEFAULT_OUT = _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "phase12_run_001"
OFFICIAL_PY = _TOOLKIT / ".venv_musiq_official" / "Scripts" / "python.exe"
SEED = 20261107

# Frozen before scoring. expected_sign is vs the human series as listed (not remapped).
# human noisiness is amount (high = more noise). SPAQ sharpness/brightness/contrast high = more of that quality.
DECLARED_PAIRS: tuple[dict[str, Any], ...] = (
    {"human": "attr_sharpness_raw", "machine": "enet_raw_sharpness", "family": "sharpness", "kind": "baseline_raw", "expected_sign": "+", "note": "ENET sharpness head; high=sharper"},
    {"human": "attr_sharpness_raw", "machine": "criterion_Sharpness", "family": "sharpness", "kind": "baseline_badge", "expected_sign": "+", "note": "ENET member badge"},
    {"human": "attr_sharpness_raw", "machine": "opencv_sharpness", "family": "sharpness", "kind": "candidate", "expected_sign": "+", "note": "production OpenCV Laplacian/420"},
    {"human": "attr_sharpness_raw", "machine": "classic_sharpness_laplacian_var", "family": "sharpness", "kind": "candidate", "expected_sign": "+", "note": "Laplacian variance (detail energy)"},
    {"human": "attr_sharpness_raw", "machine": "classic_sharpness_tenengrad", "family": "sharpness", "kind": "candidate", "expected_sign": "+", "note": "Tenengrad"},
    {"human": "attr_noisiness_raw", "machine": "enet_raw_noise", "family": "noise_amount", "kind": "baseline_raw", "expected_sign": "+", "note": "both amount; high=more noise"},
    {"human": "attr_noisiness_raw", "machine": "criterion_Noise", "family": "noise_amount", "kind": "baseline_badge", "expected_sign": "-", "note": "badge is cleanliness; expect negative vs noisiness"},
    {"human": "attr_noisiness_raw", "machine": "opencv_noise", "family": "noise_amount", "kind": "candidate", "expected_sign": "+", "note": "OpenCV residual std/36"},
    {"human": "attr_noisiness_raw", "machine": "classic_noise_immerkaer", "family": "noise_amount", "kind": "candidate", "expected_sign": "+", "note": "Immerkaer sigma"},
    {"human": "attr_noisiness_raw", "machine": "classic_noise_residual_std", "family": "noise_amount", "kind": "candidate", "expected_sign": "+", "note": "Gaussian residual std"},
    {"human": "attr_brightness_raw", "machine": "enet_raw_brightness", "family": "brightness", "kind": "baseline_raw", "expected_sign": "?", "note": "raw luma-like; not 'better exposure'"},
    {"human": "attr_brightness_raw", "machine": "criterion_Brightness", "family": "brightness", "kind": "baseline_badge", "expected_sign": "+", "note": "triangle then badge"},
    {"human": "attr_brightness_raw", "machine": "opencv_brightness", "family": "brightness", "kind": "candidate", "expected_sign": "?", "note": "mean luma /255 (characteristic)"},
    {"human": "attr_brightness_raw", "machine": "classic_brightness_mean", "family": "brightness", "kind": "candidate", "expected_sign": "?", "note": "mean luma /255"},
    {"human": "attr_brightness_raw", "machine": "classic_exposure_triangle_048", "family": "brightness", "kind": "candidate", "expected_sign": "+", "note": "mid-gray triangle (quality-like)"},
    {"human": "attr_brightness_raw", "machine": "classic_exposure_clip_frac", "family": "brightness", "kind": "candidate", "expected_sign": "-", "note": "clip fraction; high=worse"},
    {"human": "attr_contrast_raw", "machine": "enet_raw_contrast", "family": "contrast", "kind": "baseline_raw", "expected_sign": "+", "note": "ENET contrast head"},
    {"human": "attr_contrast_raw", "machine": "criterion_Contrast", "family": "contrast", "kind": "baseline_badge", "expected_sign": "+", "note": "ENET badge"},
    {"human": "attr_contrast_raw", "machine": "opencv_contrast", "family": "contrast", "kind": "candidate", "expected_sign": "+", "note": "OpenCV RMS/72"},
    {"human": "attr_contrast_raw", "machine": "classic_contrast_rms", "family": "contrast", "kind": "candidate", "expected_sign": "+", "note": "RMS/72"},
    {"human": "attr_contrast_raw", "machine": "classic_contrast_michelson", "family": "contrast", "kind": "candidate", "expected_sign": "+", "note": "Michelson"},
    {"human": "mos_quality_raw", "machine": "overall_score", "family": "overall", "kind": "baseline_badge", "expected_sign": "+", "note": "mean of seven badges"},
    {"human": "mos_quality_raw", "machine": "enet_raw_mean_seven", "family": "overall", "kind": "baseline_raw", "expected_sign": "?", "note": "unweighted raw-head mean; mixed polarities"},
    {"human": "mos_quality_raw", "machine": "musiq_raw", "family": "overall", "kind": "candidate", "expected_sign": "+", "note": "official MUSIQ PaQ-2-PiQ; overall only"},
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def fnum(row: dict[str, Any], key: str) -> float | None:
    v = row.get(key)
    if v is None or str(v).strip() == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def corr(hs: list[float], ms: list[float]) -> dict[str, Any]:
    boot = correlation_bootstrap(ms, hs, seed=SEED, n_boot=400)
    return {
        "n": len(hs),
        "pearson_r": boot.get("pearson_r"),
        "pearson_p": boot.get("pearson_p"),
        "pearson_ci_low": boot.get("pearson_ci_low"),
        "pearson_ci_high": boot.get("pearson_ci_high"),
        "spearman_r": boot.get("spearman_r"),
        "spearman_p": boot.get("spearman_p"),
        "spearman_ci_low": boot.get("spearman_ci_low"),
        "spearman_ci_high": boot.get("spearman_ci_high"),
        "note": boot.get("note"),
        "machine_n_unique": len(set(ms)),
        "machine_std": float(np.std(ms, ddof=1)) if len(ms) > 1 else 0.0,
    }


def dist(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    arr = np.asarray(values, float)
    return {
        "n": int(arr.size),
        "min": float(arr.min()),
        "max": float(arr.max()),
        "mean": float(arr.mean()),
        "std": float(arr.std(ddof=1)) if arr.size > 1 else 0.0,
        "n_unique": int(len(set(round(v, 6) for v in values))),
    }


def sign_ok(expected: str, r: float | None) -> bool | None:
    if expected == "?" or r is None:
        return None
    if expected == "+":
        return r > 0
    if expected == "-":
        return r < 0
    return None


def run_12a(rows: list[dict[str, str]]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    out: list[dict[str, Any]] = []
    times: list[float] = []
    fails = 0
    t0 = time.perf_counter()
    for i, rec in enumerate(rows, start=1):
        key = rec["source_media_key"]
        path = IMAGES / key
        print(f"[12A {i}/{len(rows)}] {key}", flush=True)
        merged: dict[str, Any] = {
            "source_media_key": key,
            "mos_quality_raw": rec.get("mos_quality_raw"),
            "attr_sharpness_raw": rec.get("attr_sharpness_raw"),
            "attr_noisiness_raw": rec.get("attr_noisiness_raw"),
            "attr_brightness_raw": rec.get("attr_brightness_raw"),
            "attr_contrast_raw": rec.get("attr_contrast_raw"),
            "overall_score": rec.get("overall_score"),
            "criterion_Sharpness": rec.get("criterion_Sharpness"),
            "criterion_Blur": rec.get("criterion_Blur"),
            "criterion_Noise": rec.get("criterion_Noise"),
            "criterion_Brightness": rec.get("criterion_Brightness"),
            "criterion_Contrast": rec.get("criterion_Contrast"),
            "criterion_Blocking_Artifacts": rec.get("criterion_Blocking_Artifacts"),
            "criterion_Ringing_Artifacts": rec.get("criterion_Ringing_Artifacts"),
            "enet_raw_sharpness": rec.get("raw_sharpness"),
            "enet_raw_blur": rec.get("raw_blur"),
            "enet_raw_noise": rec.get("raw_noise"),
            "enet_raw_brightness": rec.get("raw_brightness"),
            "enet_raw_contrast": rec.get("raw_contrast"),
            "enet_raw_blocking_artifacts": rec.get("raw_blocking_artifacts"),
            "enet_raw_ringing_artifacts": rec.get("raw_ringing_artifacts"),
            "enet_raw_mean_seven": rec.get("raw_mean_seven"),
            "opencv_status": "ok",
            "classic_status": "ok",
        }
        if not path.is_file():
            merged["opencv_status"] = "missing_file"
            merged["classic_status"] = "missing_file"
            fails += 1
            out.append(merged)
            continue
        content = path.read_bytes()
        started = time.perf_counter()
        ocv, oerr = analyze_image_metrics(content, ENGINE_OPENCV)
        classic = classical_analyze(content)
        times.append((time.perf_counter() - started) * 1000.0)
        if ocv is None:
            merged["opencv_status"] = oerr or "failed"
            fails += 1
        else:
            for k in ("sharpness", "blur", "noise", "brightness", "contrast", "blocking_artifacts", "ringing_artifacts"):
                merged[f"opencv_{k}"] = ocv.get(k)
        if classic is None:
            merged["classic_status"] = "failed"
            fails += 1
        else:
            for k, v in classic.items():
                merged[f"classic_{k}"] = v
        merged["opencv_classic_ms"] = times[-1]
        out.append(merged)
    summary = {
        "n": len(out),
        "n_fail_flags": fails,
        "elapsed_s": time.perf_counter() - t0,
        "ms_per_image_mean": float(np.mean(times)) if times else None,
        "ms_per_image_median": float(np.median(times)) if times else None,
    }
    return out, summary


def merge_musiq(rows: list[dict[str, Any]], musiq_csv: Path) -> dict[str, Any]:
    if not musiq_csv.is_file():
        return {"status": "missing", "n_ok": 0}
    by_key = {}
    with musiq_csv.open(newline="", encoding="utf-8") as handle:
        for rec in csv.DictReader(handle):
            by_key[rec["source_media_key"]] = rec
    n_ok = 0
    for rec in rows:
        m = by_key.get(rec["source_media_key"], {})
        rec["musiq_raw"] = m.get("musiq_raw", "")
        rec["musiq_status"] = m.get("musiq_status", "missing")
        rec["musiq_error"] = m.get("musiq_error", "")
        rec["musiq_ms"] = m.get("musiq_ms", "")
        rec["musiq_encoding"] = m.get("musiq_encoding", "")
        if rec["musiq_status"] == "ok":
            n_ok += 1
    meta = {}
    meta_path = musiq_csv.with_suffix(".meta.json")
    if meta_path.is_file():
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    return {"status": "ok", "n_ok": n_ok, "n": len(rows), **meta}


def evaluate(rows: list[dict[str, Any]]) -> dict[str, Any]:
    results = []
    by_family: dict[str, list[dict[str, Any]]] = {}
    for spec in DECLARED_PAIRS:
        hs: list[float] = []
        ms: list[float] = []
        for rec in rows:
            h = fnum(rec, spec["human"])
            m = fnum(rec, spec["machine"])
            if h is None or m is None:
                continue
            hs.append(h)
            ms.append(m)
        pack = corr(hs, ms) if hs else {"n": 0, "spearman_r": None, "pearson_r": None}
        signed = sign_ok(spec["expected_sign"], pack.get("spearman_r"))
        row = {**spec, **pack, "sign_matches_declaration": signed}
        results.append(row)
        by_family.setdefault(spec["family"], []).append(row)

    outperform = []
    for family, items in by_family.items():
        raw_b = next((x for x in items if x["kind"] == "baseline_raw"), None)
        badge_b = next((x for x in items if x["kind"] == "baseline_badge"), None)
        for cand in items:
            if cand["kind"] != "candidate":
                continue
            r = cand.get("spearman_r")
            verdict = {
                "family": family,
                "candidate": cand["machine"],
                "candidate_spearman": r,
                "expected_sign": cand["expected_sign"],
                "sign_ok": cand["sign_matches_declaration"],
                "beats_enet_raw": None,
                "beats_enet_badge": None,
            }
            if r is not None and cand["sign_matches_declaration"] is True:
                if raw_b and raw_b.get("spearman_r") is not None:
                    verdict["beats_enet_raw"] = abs(r) > abs(float(raw_b["spearman_r"]))
                if badge_b and badge_b.get("spearman_r") is not None:
                    verdict["beats_enet_badge"] = abs(r) > abs(float(badge_b["spearman_r"]))
            elif r is not None and cand["expected_sign"] == "?":
                verdict["beats_enet_raw"] = "not_judged_ambiguous_construct"
            outperform.append(verdict)

    unlabeled = {}
    for name, col in (
        ("blur_opencv", "opencv_blur"),
        ("blur_classic_inv_lap", "classic_blur_inv_laplacian"),
        ("blocking_opencv", "opencv_blocking_artifacts"),
        ("blocking_classic_ratio", "classic_blocking_boundary_ratio"),
        ("ringing_opencv", "opencv_ringing_artifacts"),
        ("ringing_classic", "classic_ringing_edge_lap"),
        ("enet_blur", "enet_raw_blur"),
        ("enet_blocking", "enet_raw_blocking_artifacts"),
        ("enet_ringing", "enet_raw_ringing_artifacts"),
    ):
        vals = [v for v in (fnum(r, col) for r in rows) if v is not None]
        unlabeled[name] = {"human_labels": False, "correlation_computed": False, **dist(vals)}

    return {"pairs": results, "outperform": outperform, "unlabeled_distributions": unlabeled}


def fmt(v: Any) -> str:
    if v is None:
        return "n/a"
    if isinstance(v, float):
        return f"{v:.3f}"
    return str(v)


def write_report(payload: dict[str, Any], path: Path) -> None:
    ev = payload["evaluation"]
    a12 = payload["phase12a"]
    b12 = payload["phase12b"]
    lines = [
        "# Phase 12 SPAQ-200 predictor benchmark",
        "",
        f"**Generated:** {payload['generated_at']}",
        "**Status:** research only. SPAQ-200 locked. No thresholds fitted. Production untouched. Phase 10/11 files not rewritten.",
        "",
        "Directions were declared in `DECLARED_PAIRS` before scoring. `?` means the machine series is a physical characteristic, not a quality judgment.",
        "",
        "## Runtime",
        "",
        f"- 12A OpenCV + classical: n={a12['n']}, mean {fmt(a12['ms_per_image_mean'])} ms/img, wall {fmt(a12['elapsed_s'])} s, fail flags={a12['n_fail_flags']}",
        f"- 12B official MUSIQ: n_ok={b12.get('n_ok')} / {b12.get('n')}, wall {fmt(b12.get('elapsed_s'))} s, handle `{b12.get('handle', '')}`",
        "",
        "## 12A/12B correlations vs SPAQ (locked test)",
        "",
        "| Family | Machine | Kind | Exp. sign | n | Spearman (95% CI) | Pearson | Sign OK |",
        "|--------|---------|------|-----------|---|----|---------|---------|",
    ]
    for p in ev["pairs"]:
        lines.append(
            f"| {p['family']} | `{p['machine']}` | {p['kind']} | {p['expected_sign']} | {p.get('n')} | "
            f"{fmt(p.get('spearman_r'))} ({fmt(p.get('spearman_ci_low'))}, {fmt(p.get('spearman_ci_high'))}) | "
            f"{fmt(p.get('pearson_r'))} | {p.get('sign_matches_declaration')} |"
        )
    lines += [
        "",
        "## Who outperforms ENET (predeclared rule)",
        "",
        "A candidate **outperforms** only if Spearman has the declared sign and **|r| is larger** than the ENET raw and/or badge baseline on the same human field. Ambiguous (`?`) constructs are not judged as wins.",
        "",
        "| Family | Candidate | Spearman | Beats ENET raw? | Beats ENET badge? | Sign OK |",
        "|--------|-----------|----------|-----------------|-------------------|---------|",
    ]
    for v in ev["outperform"]:
        lines.append(
            f"| {v['family']} | `{v['candidate']}` | {fmt(v['candidate_spearman'])} | "
            f"{v['beats_enet_raw']} | {v['beats_enet_badge']} | {v['sign_ok']} |"
        )
    lines += [
        "",
        "## Unlabeled criteria (no human accuracy claim)",
        "",
    ]
    for name, d in ev["unlabeled_distributions"].items():
        lines.append(
            f"- `{name}`: n={d.get('n')} min={fmt(d.get('min'))} max={fmt(d.get('max'))} "
            f"mean={fmt(d.get('mean'))} unique={d.get('n_unique')}"
        )
    lines += [
        "",
        "## Licensing (12B)",
        "",
        json.dumps(b12.get("license_findings") or payload.get("musiq_license") or {}, indent=2),
        "",
        "## Recommendations (evidence only)",
        "",
        payload["recommendation_text"],
        "",
        "No production changes were made. No further phase was started.",
        "",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def recommendation(ev: dict[str, Any], b12: dict[str, Any]) -> str:
    wins_raw = [v for v in ev["outperform"] if v.get("beats_enet_raw") is True]
    wins_badge = [v for v in ev["outperform"] if v.get("beats_enet_badge") is True]
    musiq = next((p for p in ev["pairs"] if p["machine"] == "musiq_raw"), None)
    overall_badge = next((p for p in ev["pairs"] if p["machine"] == "overall_score"), None)
    bits = [
        f"Candidates beating ENET **raw** under the predeclared rule: "
        f"{', '.join('`'+v['candidate']+'`' for v in wins_raw) or 'none'}.",
        f"Candidates beating ENET **badge**: "
        f"{', '.join('`'+v['candidate']+'`' for v in wins_badge) or 'none'}.",
    ]
    if musiq and overall_badge:
        bits.append(
            f"Overall: MUSIQ Spearman {fmt(musiq.get('spearman_r'))} vs ENET overall badge "
            f"{fmt(overall_badge.get('spearman_r'))} (n={musiq.get('n')}, MUSIQ ok={b12.get('n_ok')}). "
            "MUSIQ remains a **separate MOS channel**, not a replacement for the seven badges. "
            "Do not fit 1-5 on this test set. pyiqa stays out of production; TF Hub Apache card vs GCS npz NOTICE still applies."
        )
    bits.append(
        "Sharpness/Blur remain one Laplacian axis in OpenCV (`blur = 1 - sharpness`). "
        "Do not claim independent human validation of Blur, Blocking, or Ringing."
    )
    if not wins_raw and not wins_badge:
        bits.append(
            "If no classical candidate beats ENET on the declared proxies, the practical next step is still a dedicated overall model (MUSIQ research path) plus new labels for Blur/Blocking/Ringing, not a `_soft_score` tweak."
        )
    return " ".join(bits)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--skip-musiq", action="store_true")
    parser.add_argument("--musiq-python", type=Path, default=OFFICIAL_PY)
    args = parser.parse_args()
    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    with SPAQ_CSV.open(newline="", encoding="utf-8-sig") as handle:
        base_rows = list(csv.DictReader(handle))
    scored, a12 = run_12a(base_rows)

    musiq_csv = out_dir / "musiq_raw.csv"
    b12: dict[str, Any]
    if args.skip_musiq:
        b12 = {"status": "skipped", "n_ok": 0, "n": len(scored)}
    else:
        cmd = [
            str(args.musiq_python),
            str(_TOOLKIT / "phase12_musiq_spaq.py"),
            "--output",
            str(musiq_csv),
        ]
        print("Running 12B:", " ".join(cmd), flush=True)
        proc = subprocess.run(cmd, cwd=str(_TOOLKIT))
        if proc.returncode != 0:
            b12 = {"status": "musiq_subprocess_failed", "returncode": proc.returncode, "n_ok": 0, "n": len(scored)}
        else:
            b12 = merge_musiq(scored, musiq_csv)

    ev = evaluate(scored)
    rec_text = recommendation(ev, b12)
    fieldnames: list[str] = []
    for rec in scored:
        for k in rec:
            if k not in fieldnames:
                fieldnames.append(k)
    with (out_dir / "phase12_per_image.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(scored)
    payload = {
        "generated_at": _now(),
        "locked_test_set": True,
        "fitted_on_spaq200": False,
        "production_untouched": True,
        "phase10_11_preserved": True,
        "seed": SEED,
        "declared_pairs": list(DECLARED_PAIRS),
        "phase12a": a12,
        "phase12b": b12,
        "evaluation": ev,
        "recommendation_text": rec_text,
        "musiq_license": (b12.get("license_findings") if isinstance(b12, dict) else None),
    }
    (out_dir / "phase12_metrics.json").write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(payload, out_dir / "PHASE12_BENCHMARK_REPORT.md")
    write_report(payload, _TOOLKIT / "PHASE12_BENCHMARK_REPORT.md")
    print(json.dumps({"a12_s": a12["elapsed_s"], "b12": b12.get("status"), "out": str(out_dir)}, indent=2))
    return 0 if b12.get("status") in {"ok", "skipped"} or b12.get("n_ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
