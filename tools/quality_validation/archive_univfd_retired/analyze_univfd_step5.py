"""
Step 5: UnivFD error and outlier analysis (reads Step 4 CSV only).

Usage:
  cd access_backend
  python scripts/analyze_univfd_step5.py
  python scripts/analyze_univfd_step5.py --step4-dir evaluation_results/step4/20260926_170227
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

try:
    from PIL import Image
except ImportError:
    Image = None  # type: ignore

from app.services.ai_authenticity_detector import (  # noqa: E402
    AI_GENERATED_THRESHOLD,
    SUSPICIOUS_THRESHOLD,
    detect_ai_generated,
    extract_exif_metadata,
)
from app.services.dedicated_ai_detector import dedicated_ai_probability  # noqa: E402

FUSION_DOCUMENTATION = {
    "neural_transform": {
        "if model_p >= 0.55": "signals['neural'] = clip((model_p - 0.5) * 2, 0, 1)",
        "if model_p <= 0.38": "signals['neural_authentic'] = clip((0.5 - model_p) * 2, 0, 1)",
        "else": "no neural or neural_authentic key",
    },
    "fuse_weights": {
        "frequency": 0.18,
        "noise_uniformity": 0.16,
        "texture_entropy": 0.12,
        "quality_paradox": 0.18,
        "skin_smoothness": 0.16,
        "neural": 0.28,
        "metadata_meta_score": 0.28,
        "filename": 0.30,
        "neural_authentic_subtract": 0.12,
    },
    "fuse_formula": (
        "acc = sum(signal[k]*weight[k] for present k) + meta_score*0.28 if meta_score>0 "
        "+ filename*0.30 if present - neural_authentic*0.12 if present; "
        "probability = clip(acc/total_w, 0, 0.98); if total_w<=0 return 0.12"
    ),
    "post_fusion_boosts": [
        "if quality_paradox>=0.48 and combined_meta>=0.32: prob += 0.16 (cap 0.98)",
        "if skin_smoothness>=0.55 and quality_paradox>=0.45: prob += 0.12 (cap 0.98)",
        "if noise_uniformity>=0.55 and quality_paradox>=0.55 and combined_meta>=0.32: prob += 0.10 (cap 0.98)",
    ],
    "combined_meta": "max(metadata_score, filename_score)",
    "verdict_thresholds": {
        "AI_GENERATED_THRESHOLD": AI_GENERATED_THRESHOLD,
        "SUSPICIOUS_THRESHOLD": SUSPICIOUS_THRESHOLD,
    },
}


def _latest_step4_dir(base: Path) -> Path:
    step4 = base / "evaluation_results" / "step4"
    runs = [p for p in step4.iterdir() if p.is_dir()]
    if not runs:
        raise SystemExit(f"No Step 4 runs under {step4}")
    return max(runs, key=lambda p: p.stat().st_mtime)


def _fnum(val: str | None) -> float | None:
    if val is None or val == "":
        return None
    try:
        return float(val)
    except ValueError:
        return None


def load_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        r
        for r in rows
        if r.get("dataset_group") == "main_benchmark"
        and r.get("ground_truth") in ("REAL", "AI")
        and not r.get("error")
    ]


def _percentiles(values: list[float], ps: list[int]) -> dict[str, float]:
    if not values:
        return {}
    s = sorted(values)
    n = len(s)
    out: dict[str, float] = {}
    for p in ps:
        if n == 1:
            out[f"P{p}"] = s[0]
            continue
        k = (p / 100.0) * (n - 1)
        lo = int(math.floor(k))
        hi = int(math.ceil(k))
        if lo == hi:
            out[f"P{p}"] = s[lo]
        else:
            out[f"P{p}"] = s[lo] + (s[hi] - s[lo]) * (k - lo)
    return out


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def rank_row(r: dict[str, str], rank: int) -> dict[str, Any]:
    return {
        "rank": rank,
        "filepath": r.get("filepath"),
        "source": r.get("source"),
        "category": r.get("category"),
        "ground_truth": r.get("ground_truth"),
        "raw_univfd_probability": _fnum(r.get("raw_univfd_probability")),
        "fused_probability": _fnum(r.get("fused_probability")),
        "final_verdict": r.get("final_verdict"),
        "filename_signal": _fnum(r.get("filename_signal")),
        "exif_signal": _fnum(r.get("exif_signal")),
        "opencv_signal": _fnum(r.get("opencv_signal")),
        "neural_signal": _fnum(r.get("neural_signal")),
        "fusion_delta": (_fnum(r.get("fused_probability")) or 0)
        - (_fnum(r.get("raw_univfd_probability")) or 0),
    }


def image_probe(path: Path) -> dict[str, Any]:
    info: dict[str, Any] = {"filepath": str(path), "exists": path.is_file()}
    if not path.is_file():
        return info
    info["file_size_bytes"] = path.stat().st_size
    info["format_ext"] = path.suffix.lower()
    if Image is None:
        info["note"] = "PIL unavailable"
        return info
    try:
        raw = path.read_bytes()
        with Image.open(BytesIO(raw)) as im:
            info["width"] = im.size[0]
            info["height"] = im.size[1]
            info["mode"] = im.mode
            info["pil_format"] = im.format
        info["sha256"] = hashlib.sha256(raw).hexdigest()
        info["exif_metadata"] = extract_exif_metadata(raw, path.name)
        info["has_exif"] = bool(info["exif_metadata"])
    except Exception as exc:
        info["probe_error"] = f"{type(exc).__name__}: {exc}"
    return info


def investigate_file(path: Path) -> dict[str, Any]:
    probe = image_probe(path)
    if not path.is_file():
        return probe
    content = path.read_bytes()
    live = detect_ai_generated(content, file_name=path.name)
    probe["live_detect"] = {
        "raw_univfd_probability": dedicated_ai_probability(content),
        "fused_probability": live.get("probability"),
        "verdict": live.get("verdict"),
        "signals": live.get("signals"),
        "exif_metadata": live.get("exif_metadata"),
    }
    return probe


def duplicate_hashes(rows: list[dict[str, str]]) -> dict[str, Any]:
    by_hash: dict[str, list[str]] = defaultdict(list)
    errors = 0
    for r in rows:
        fp = Path(r.get("filepath", ""))
        if not fp.is_file():
            continue
        try:
            h = hashlib.sha256(fp.read_bytes()).hexdigest()
            by_hash[h].append(str(fp))
        except OSError:
            errors += 1
    dups = {h: paths for h, paths in by_hash.items() if len(paths) > 1}
    cross_label: list[dict[str, Any]] = []
    path_to_gt = {r["filepath"]: r.get("ground_truth") for r in rows}
    for h, paths in dups.items():
        gts = {path_to_gt.get(p) for p in paths}
        if len(gts - {None}) > 1:
            cross_label.append({"sha256": h, "paths": paths, "ground_truths": sorted(gts)})
    return {
        "files_hashed": sum(len(v) for v in by_hash.values()),
        "unique_hashes": len(by_hash),
        "duplicate_groups": len(dups),
        "duplicate_file_count": sum(len(v) for v in dups.values()),
        "cross_ground_truth_duplicates": cross_label,
        "hash_errors": errors,
        "duplicate_examples": [
            {"sha256": h, "paths": paths[:5], "count": len(paths)} for h, paths in list(dups.items())[:20]
        ],
    }


def contact_sheet(
    entries: list[tuple[Path, str]],
    out_path: Path,
    *,
    thumb: int = 160,
    cols: int = 5,
) -> str | None:
    if Image is None or not entries:
        return "PIL unavailable or empty list"
    rows_n = (len(entries) + cols - 1) // cols
    pad = 4
    label_h = 36
    cell_w = thumb + pad * 2
    cell_h = thumb + label_h + pad * 2
    sheet = Image.new("RGB", (cols * cell_w, rows_n * cell_h), (240, 240, 240))
    from PIL import ImageDraw, ImageFont

    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None
    for idx, (fp, label) in enumerate(entries):
        row, col = divmod(idx, cols)
        x0 = col * cell_w + pad
        y0 = row * cell_h + pad
        try:
            with Image.open(fp) as im:
                im = im.convert("RGB")
                im.thumbnail((thumb, thumb))
                sheet.paste(im, (x0, y0))
        except Exception:
            draw.rectangle([x0, y0, x0 + thumb, y0 + thumb], outline=(200, 0, 0))
        draw.text((x0, y0 + thumb + 2), label[:80], fill=(0, 0, 0), font=font)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, quality=85)
    return None


def dist_stats(values: list[float]) -> dict[str, float | int]:
    if not values:
        return {"count": 0}
    return {
        "count": len(values),
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
        **_percentiles(values, [10, 25, 50, 75, 90]),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--step4-dir", type=Path, default=None)
    args = parser.parse_args()

    step4_dir = args.step4_dir or _latest_step4_dir(ROOT)
    csv_path = step4_dir / "univfd_step4_results.csv"
    if not csv_path.is_file():
        raise SystemExit(f"Missing {csv_path}")

    rows = load_csv(csv_path)
    main = main_rows(rows)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step5" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    real = [r for r in main if r["ground_truth"] == "REAL"]
    ai = [r for r in main if r["ground_truth"] == "AI"]

    def raw(r: dict[str, str]) -> float | None:
        return _fnum(r.get("raw_univfd_probability"))

    # --- Outlier tags ---
    outlier_rows: list[dict[str, Any]] = []
    for r in main:
        p = raw(r)
        if p is None:
            continue
        tags: list[str] = []
        if r["ground_truth"] == "REAL":
            if p >= 0.80:
                tags.append("HIGH_REAL_PROBABILITY_OUTLIER")
            if p >= 0.90:
                tags.append("HIGH_REAL_PROBABILITY_OUTLIER_0.90")
            if p >= 0.95:
                tags.append("HIGH_REAL_PROBABILITY_OUTLIER_0.95")
        if r["ground_truth"] == "AI":
            if p <= 0.20:
                tags.append("LOW_AI_PROBABILITY_OUTLIER")
            if p <= 0.10:
                tags.append("LOW_AI_PROBABILITY_OUTLIER_0.10")
            if p <= 0.05:
                tags.append("LOW_AI_PROBABILITY_OUTLIER_0.05")
        if 0.40 <= p <= 0.60:
            tags.append("BORDERLINE")
        if tags:
            outlier_rows.append({**r, "outlier_tags": ";".join(tags), "raw_p": p})

    write_csv(
        out_dir / "step5_outlier_analysis.csv",
        outlier_rows,
        list(outlier_rows[0].keys()) if outlier_rows else ["filepath"],
    )

    # --- Production errors ---
    prod_errors: list[dict[str, Any]] = []

    def add_error(r: dict[str, str], error_type: str) -> None:
        prod_errors.append({**r, "error_type": error_type})

    for r in main:
        v = r.get("final_verdict", "")
        gt = r["ground_truth"]
        if gt == "REAL" and v == "ai_generated":
            add_error(r, "STRICT_FALSE_POSITIVE")
        if gt == "AI" and v in ("authentic", "suspicious"):
            add_error(r, "STRICT_FALSE_NEGATIVE")
        if gt == "REAL" and v in ("suspicious", "ai_generated"):
            add_error(r, "FLAGGED_FALSE_POSITIVE")
        if gt == "AI" and v == "authentic":
            add_error(r, "FLAGGED_FALSE_NEGATIVE")

    write_csv(
        out_dir / "step5_production_errors.csv",
        prod_errors,
        list(main[0].keys()) + ["error_type"] if main else ["error_type"],
    )

    # --- Ranked lists ---
    rank_fields = [
        "rank",
        "filepath",
        "source",
        "category",
        "ground_truth",
        "raw_univfd_probability",
        "fused_probability",
        "final_verdict",
        "filename_signal",
        "exif_signal",
        "opencv_signal",
        "neural_signal",
        "fusion_delta",
    ]

    top_real_raw = sorted(real, key=lambda r: raw(r) or -1, reverse=True)[:20]
    top_ai_low = sorted(ai, key=lambda r: raw(r) if raw(r) is not None else 999)[:20]
    top_real_fused = sorted(real, key=lambda r: _fnum(r.get("fused_probability")) or -1, reverse=True)[:20]
    top_ai_fused_low = sorted(ai, key=lambda r: _fnum(r.get("fused_probability")) or 999)[:20]

    for r in main:
        rp, fp = raw(r), _fnum(r.get("fused_probability"))
        if rp is not None and fp is not None:
            r["_delta"] = fp - rp
        else:
            r["_delta"] = None

    top_delta = sorted(
        [r for r in main if r.get("_delta") is not None],
        key=lambda r: abs(r["_delta"]),
        reverse=True,
    )[:20]

    ranked = {
        "top20_real_by_raw": [rank_row(r, i + 1) for i, r in enumerate(top_real_raw)],
        "top20_ai_by_lowest_raw": [rank_row(r, i + 1) for i, r in enumerate(top_ai_low)],
        "top20_real_by_fused": [rank_row(r, i + 1) for i, r in enumerate(top_real_fused)],
        "top20_ai_by_lowest_fused": [rank_row(r, i + 1) for i, r in enumerate(top_ai_fused_low)],
        "top20_largest_fusion_delta": [rank_row(r, i + 1) for i, r in enumerate(top_delta)],
    }
    (out_dir / "step5_ranked_lists.json").write_text(json.dumps(ranked, indent=2), encoding="utf-8")

    # --- Source analysis ---
    source_stats: dict[str, Any] = {}
    for src in sorted({r["source"] for r in main}):
        sr = [r for r in main if r["source"] == src]
        probs = [raw(r) for r in sr if raw(r) is not None]
        fused = [_fnum(r.get("fused_probability")) for r in sr if _fnum(r.get("fused_probability")) is not None]
        source_stats[src] = {
            "count": len(sr),
            "AI": sum(1 for r in sr if r["ground_truth"] == "AI"),
            "REAL": sum(1 for r in sr if r["ground_truth"] == "REAL"),
            "raw_univfd": dist_stats([p for p in probs if p is not None]),
            "fused": dist_stats([p for p in fused if p is not None]),
            "verdicts": dict(
                zip(
                    ["authentic", "suspicious", "ai_generated"],
                    [
                        sum(1 for r in sr if r.get("final_verdict") == v)
                        for v in ("authentic", "suspicious", "ai_generated")
                    ],
                )
            ),
        }
    source_csv_rows: list[dict[str, Any]] = []
    for k, v in source_stats.items():
        source_csv_rows.append(
            {
                "source": k,
                "count": v["count"],
                "AI_count": v["AI"],
                "REAL_count": v["REAL"],
                "raw_mean": v["raw_univfd"].get("mean"),
                "raw_median": v["raw_univfd"].get("median"),
                "fused_mean": v["fused"].get("mean"),
                "verdict_authentic": v["verdicts"]["authentic"],
                "verdict_suspicious": v["verdicts"]["suspicious"],
                "verdict_ai_generated": v["verdicts"]["ai_generated"],
            }
        )
    write_csv(
        out_dir / "step5_source_analysis.csv",
        source_csv_rows,
        list(source_csv_rows[0].keys()) if source_csv_rows else ["source"],
    )

    # --- Self-generated detail ---
    self_gen: dict[str, list[dict[str, Any]]] = {}
    for gen in ("canva", "chatgpt", "google.gemini"):
        gr = [r for r in main if r.get("generator") == gen or r.get("source") == gen]
        self_gen[gen] = [
            {
                "filename": r.get("filename"),
                "filepath": r.get("filepath"),
                "raw": raw(r),
                "fused": _fnum(r.get("fused_probability")),
                "verdict": r.get("final_verdict"),
            }
            for r in gr
        ]

    # --- RhythmGhai categories ---
    cat_rows_out: list[dict[str, Any]] = []
    rhythm = [r for r in main if r.get("source") == "rhythmghai"]
    for cat in sorted({r.get("category") or "" for r in rhythm} - {""}):
        cr = [r for r in rhythm if (r.get("category") or "").lower() == cat.lower()]
        real_p = [raw(r) for r in cr if r["ground_truth"] == "REAL" and raw(r) is not None]
        ai_p = [raw(r) for r in cr if r["ground_truth"] == "AI" and raw(r) is not None]
        cat_rows_out.append(
            {
                "category": cat,
                "n": len(cr),
                "REAL_count": len(real_p),
                "AI_count": len(ai_p),
                "mean_REAL_raw": statistics.mean(real_p) if real_p else None,
                "mean_AI_raw": statistics.mean(ai_p) if ai_p else None,
                "median_REAL_raw": statistics.median(real_p) if real_p else None,
                "median_AI_raw": statistics.median(ai_p) if ai_p else None,
                "max_REAL_raw": max(real_p) if real_p else None,
                "min_AI_raw": min(ai_p) if ai_p else None,
            }
        )
    write_csv(
        out_dir / "step5_category_analysis.csv",
        cat_rows_out,
        list(cat_rows_out[0].keys()) if cat_rows_out else ["category"],
    )

    # --- Own photos ---
    own = [r for r in rows if r.get("dataset_group") == "own_photos_robustness" and not r.get("error")]
    own_sorted = sorted(own, key=lambda r: raw(r) or -1, reverse=True)
    own_probs = [raw(r) for r in own if raw(r) is not None]
    own_buckets = {
        ">=0.90": sum(1 for p in own_probs if p >= 0.90),
        "0.80-0.8999": sum(1 for p in own_probs if 0.80 <= p < 0.90),
        "0.60-0.7999": sum(1 for p in own_probs if 0.60 <= p < 0.80),
        "0.40-0.5999": sum(1 for p in own_probs if 0.40 <= p < 0.60),
        "<0.40": sum(1 for p in own_probs if p < 0.40),
    }
    own_analysis = {
        "count": len(own),
        "distribution": dist_stats([float(p) for p in own_probs]),
        "buckets": own_buckets,
        "main_REAL_benchmark_raw": dist_stats([float(raw(r)) for r in real if raw(r) is not None]),
        "images": [
            {
                "filename": r.get("filename"),
                "raw": raw(r),
                "fused": _fnum(r.get("fused_probability")),
                "verdict": r.get("final_verdict"),
            }
            for r in own_sorted
        ],
    }
    write_csv(
        out_dir / "step5_own_photos_analysis.csv",
        own_analysis["images"],
        ["filename", "raw", "fused", "verdict"],
    )

    # --- Distribution ---
    real_probs = [float(raw(r)) for r in real if raw(r) is not None]
    ai_probs = [float(raw(r)) for r in ai if raw(r) is not None]
    distribution = {
        "REAL": dist_stats(real_probs),
        "AI": dist_stats(ai_probs),
        "mean_difference_REAL_minus_AI": statistics.mean(real_probs) - statistics.mean(ai_probs)
        if real_probs and ai_probs
        else None,
        "median_difference_REAL_minus_AI": statistics.median(real_probs) - statistics.median(ai_probs)
        if real_probs and ai_probs
        else None,
    }

    # --- Image property correlation (probe main benchmark paths) ---
    props: list[dict[str, Any]] = []
    for r in main:
        fp = Path(r.get("filepath", ""))
        pr = image_probe(fp)
        pr["ground_truth"] = r.get("ground_truth")
        pr["raw_univfd_probability"] = raw(r)
        pr["source"] = r.get("source")
        props.append(pr)

    high_real = [p for p in props if p.get("ground_truth") == "REAL" and (p.get("raw_univfd_probability") or 0) >= 0.80]
    low_ai = [p for p in props if p.get("ground_truth") == "AI" and (p.get("raw_univfd_probability") or 1) <= 0.20]

    def median_prop(items: list[dict], key: str) -> float | None:
        vals = [float(x[key]) for x in items if x.get(key) is not None]
        return statistics.median(vals) if vals else None

    property_summary = {
        "all_main_n": len(props),
        "high_real_outliers_n": len(high_real),
        "low_ai_outliers_n": len(low_ai),
        "high_real_median_file_size_bytes": median_prop(high_real, "file_size_bytes"),
        "all_REAL_median_file_size_bytes": median_prop(
            [p for p in props if p.get("ground_truth") == "REAL"], "file_size_bytes"
        ),
        "high_real_median_width": median_prop(high_real, "width"),
        "high_real_exif_present_count": sum(1 for p in high_real if p.get("has_exif")),
        "high_real_total": len(high_real),
    }

    # --- 9.jpg investigation ---
    nine_path = Path(r"C:\Users\Dell\Desktop\subset_fake_real_data\real\9.jpg")
    nine_row = next((r for r in main if r.get("filename") == "9.jpg" and "fake-v2" not in r.get("filepath", "")), None)
    nine_investigation = {
        "expected_path": str(nine_path),
        "step4_row": nine_row,
        "probe_and_live": investigate_file(nine_path) if nine_path.is_file() else {"exists": False},
    }

    # --- Duplicates ---
    dup = duplicate_hashes(rows)

    # --- Contact sheets ---
    sheet_notes: dict[str, str] = {}
    sheet_specs = [
        ("step5_high_real_contact_sheet.jpg", [(Path(r["filepath"]), f"{r.get('filename')} r={raw(r):.3f} f={_fnum(r.get('fused_probability')):.3f} {r.get('final_verdict')}") for r in top_real_raw if Path(r["filepath"]).is_file()]),
        ("step5_low_ai_contact_sheet.jpg", [(Path(r["filepath"]), f"{r.get('filename')} r={raw(r):.3f} f={_fnum(r.get('fused_probability')):.3f} {r.get('final_verdict')}") for r in top_ai_low if Path(r["filepath"]).is_file()]),
        ("step5_high_fused_real_contact_sheet.jpg", [(Path(r["filepath"]), f"{r.get('filename')} r={raw(r):.3f} f={_fnum(r.get('fused_probability')):.3f} {r.get('final_verdict')}") for r in top_real_fused if Path(r["filepath"]).is_file()]),
        ("step5_low_fused_ai_contact_sheet.jpg", [(Path(r["filepath"]), f"{r.get('filename')} r={raw(r):.3f} f={_fnum(r.get('fused_probability')):.3f} {r.get('final_verdict')}") for r in top_ai_fused_low if Path(r["filepath"]).is_file()]),
    ]
    for fname, entries in sheet_specs:
        err = contact_sheet(entries, out_dir / fname)
        if err:
            sheet_notes[fname] = err

    # --- Error counts ---
    err_counts = defaultdict(int)
    for e in prod_errors:
        err_counts[e["error_type"]] += 1

    summary = {
        "step5_status": "COMPLETE",
        "input": {
            "step4_run_directory": str(step4_dir),
            "step4_csv": str(csv_path),
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        },
        "main_benchmark": {
            "REAL": len(real),
            "AI": len(ai),
            "excluded_uncertain_in_csv": sum(1 for r in rows if r.get("ground_truth") == "uncertain"),
        },
        "raw_univfd_outliers": {
            "HIGH_REAL_ge_0.80": sum(1 for r in real if (raw(r) or 0) >= 0.80),
            "HIGH_REAL_ge_0.90": sum(1 for r in real if (raw(r) or 0) >= 0.90),
            "HIGH_REAL_ge_0.95": sum(1 for r in real if (raw(r) or 0) >= 0.95),
            "LOW_AI_le_0.20": sum(1 for r in ai if (raw(r) or 1) <= 0.20),
            "LOW_AI_le_0.10": sum(1 for r in ai if (raw(r) or 1) <= 0.10),
            "LOW_AI_le_0.05": sum(1 for r in ai if (raw(r) or 1) <= 0.05),
            "BORDERLINE_0.40_to_0.60": sum(
                1 for r in main if raw(r) is not None and 0.40 <= raw(r) <= 0.60
            ),
        },
        "production_fusion_errors": dict(err_counts),
        "ranked_lists_file": str(out_dir / "step5_ranked_lists.json"),
        "own_photos": own_analysis,
        "self_generated_ai": {k: {"stats": source_stats.get(k, {}), "images": v} for k, v in self_gen.items()},
        "rhythmghai_categories": cat_rows_out,
        "distribution_comparison": distribution,
        "fusion_documentation": FUSION_DOCUMENTATION,
        "fusion_example_1618": next((r for r in main if r.get("filename") == "1618.jpg"), None),
        "image_property_summary": property_summary,
        "nine_jpg_investigation": nine_investigation,
        "duplicate_analysis": dup,
        "contact_sheet_notes": sheet_notes,
        "hypotheses_requiring_future_testing": [
            "HYPOTHESIS: High raw scores on some REAL phone photos correlate with missing EXIF or specific dimensions; verify with controlled capture metadata.",
            "HYPOTHESIS: Low raw scores on self-generated Canva/ChatGPT/Gemini images reflect domain gap vs UnivFD training data; needs larger per-generator sample.",
            "HYPOTHESIS: Large fusion deltas when raw is low but OpenCV/metadata scores are ~0.42–0.62 reflect heuristic-dominated fusion; verify by recomputing _fuse_probability from stored signals.",
        ],
    }
    (out_dir / "step5_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    # Text report
    lines = [
        "STEP 5 STATUS: COMPLETE",
        f"Step 4 input: {step4_dir}",
        f"Output: {out_dir}",
        "",
        f"MAIN BENCHMARK REAL={len(real)} AI={len(ai)}",
        f"Production errors: {dict(err_counts)}",
        f"High REAL raw >=0.80: {summary['raw_univfd_outliers']['HIGH_REAL_ge_0.80']}",
        f"Low AI raw <=0.20: {summary['raw_univfd_outliers']['LOW_AI_le_0.20']}",
        "",
        "Top 3 REAL by raw:",
    ]
    for i, r in enumerate(top_real_raw[:3], 1):
        lines.append(f"  {i}. {r.get('filename')} raw={raw(r):.4f} fused={_fnum(r.get('fused_probability'))} verdict={r.get('final_verdict')}")
    lines.append("Top 3 AI by lowest raw:")
    for i, r in enumerate(top_ai_low[:3], 1):
        lines.append(f"  {i}. {r.get('filename')} raw={raw(r):.6f} fused={_fnum(r.get('fused_probability'))} verdict={r.get('final_verdict')}")
    lines.append("")
    lines.append("PRODUCTION BEHAVIOR CHANGED: NO")
    (out_dir / "step5_report.txt").write_text("\n".join(lines), encoding="utf-8")

    print("\n".join(lines))


if __name__ == "__main__":
    main()
