#!/usr/bin/env python3
"""Research-only 1-5 mapping candidates on Phase 8 controlled-distortion CSVs.

Does not import production scoring to *write* scores; copies _soft_score math for
the baseline. Does not fit percentiles on the evaluation set. Does not invent humans.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.quality_validation.metrics import pearson_spearman  # noqa: E402

PHASE8_CSV = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "controlled_distortion"
    / "output"
    / "run_001"
    / "raw_predictions.csv"
)
DEFAULT_OUTPUT = (
    _TOOLKIT / "workspace" / "datasets" / "controlled_distortion" / "output" / "run_scoring_candidates_001"
)

FAMILY_PRIMARY = {
    "gaussian_blur": "blur",
    "awgn": "noise",
    "underexposure": "exposure",
    "overexposure": "exposure",
    "low_contrast": "contrast",
    "high_contrast": "contrast",
    "jpeg": "blocking",
    "ringing": "ringing",
}

# A priori scales from production OpenCV / trainer knobs (not fitted on these 370 files).
LAP_SCALE = 420.0
NOISE_SIGMA_SCALE = 35.0
RING_LAP_SCALE = 40.0
BLOCK_RATIO_REF = 1.0  # natural images ~1; >1 means extra 8x8 boundary energy


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def production_soft_score(metric: float) -> int:
    boosted = clip01(metric * 0.5 + 0.42)
    if boosted >= 0.80:
        return 5
    if boosted >= 0.64:
        return 4
    if boosted >= 0.46:
        return 3
    if boosted >= 0.28:
        return 2
    return 1


def production_brightness_q(mean_luma: float) -> float:
    return clip01(1.0 - abs(mean_luma - 0.48) * 2.2)


def equal_bin_1_5(q: float) -> int:
    """Monotone bins that can emit 1 and 5. q in [0,1], higher=better.

    [0, 0.2) -> 1, [0.2, 0.4) -> 2, ..., [0.8, 1.0] -> 5.
    """
    x = clip01(q)
    if x >= 1.0:
        return 5
    return 1 + int(x * 5.0)


def linear_continuous_1_5(q: float) -> float:
    return 1.0 + 4.0 * clip01(q)


def linear_round_1_5(q: float) -> int:
    return int(max(1, min(5, round(linear_continuous_1_5(q)))))


def fnum(row: dict[str, str], key: str) -> float | None:
    v = row.get(key, "")
    if v is None or v == "":
        return None
    return float(v)


def enet_quality_signals(row: dict[str, str]) -> dict[str, float | None]:
    """Higher = better. Defect heads are inverted. Directions are explicit."""
    sharp = fnum(row, "enet_raw_sharpness")
    blur_amt = fnum(row, "enet_raw_blur")
    noise_amt = fnum(row, "enet_raw_noise")
    bright = fnum(row, "enet_raw_brightness")
    contrast = fnum(row, "enet_raw_contrast")
    block_amt = fnum(row, "enet_raw_blocking_artifacts")
    ring_amt = fnum(row, "enet_raw_ringing_artifacts")
    return {
        "sharpness": sharp,
        "blur": None if blur_amt is None else clip01(1.0 - blur_amt),
        "noise": None if noise_amt is None else clip01(1.0 - min(noise_amt, 0.85)),
        "exposure": None if bright is None else production_brightness_q(bright),
        "contrast": None if contrast is None else clip01(min(contrast, 1.0)),
        "blocking": None if block_amt is None else clip01(1.0 - block_amt),
        "ringing": None if ring_amt is None else clip01(1.0 - ring_amt),
        # extras for interference / duplication
        "blur_amount": blur_amt,
        "noise_amount": noise_amt,
        "brightness_mean": bright,
    }


def opencv_quality_signals(row: dict[str, str]) -> dict[str, float | None]:
    sharp = fnum(row, "opencv_raw_sharpness")
    blur_amt = fnum(row, "opencv_raw_blur")
    noise_amt = fnum(row, "opencv_raw_noise")
    bright = fnum(row, "opencv_raw_brightness")
    contrast = fnum(row, "opencv_raw_contrast")
    block_amt = fnum(row, "opencv_raw_blocking_artifacts")
    ring_amt = fnum(row, "opencv_raw_ringing_artifacts")
    return {
        "sharpness": sharp,
        "blur": None if blur_amt is None else clip01(1.0 - blur_amt),
        "noise": None if noise_amt is None else clip01(1.0 - min(noise_amt, 0.85)),
        "exposure": None if bright is None else production_brightness_q(bright),
        "contrast": None if contrast is None else clip01(min(contrast, 1.0)),
        "blocking": None if block_amt is None else clip01(1.0 - block_amt),
        "ringing": None if ring_amt is None else clip01(1.0 - ring_amt),
    }


def classical_quality_signals(row: dict[str, str]) -> dict[str, float | None]:
    """A priori maps. Not percentile-fitted on this CSV."""
    lap = fnum(row, "classic_sharpness_laplacian_var")
    immer = fnum(row, "classic_noise_immerkaer")
    luma = fnum(row, "classic_brightness_mean")
    clipf = fnum(row, "classic_exposure_clip_frac")
    rms = fnum(row, "classic_contrast_rms")
    bound = fnum(row, "classic_blocking_boundary_ratio")
    ring = fnum(row, "classic_ringing_edge_lap")
    sharpness = None if lap is None else clip01(lap / LAP_SCALE)
    # Same Laplacian quality axis as sharpness (high = more detail / less blur).
    # Kept to *measure* duplication, not as a second product channel.
    blur = sharpness
    noise = None if immer is None else clip01(1.0 - immer / NOISE_SIGMA_SCALE)
    triangle = None if luma is None else production_brightness_q(luma)
    exposure = None
    if triangle is not None:
        exposure = clip01(triangle * (1.0 - (0.0 if clipf is None else clip01(clipf))))
    contrast = None
    if rms is not None:
        rms_q = clip01(rms)  # production scale 72
        contrast = clip01(rms_q * (1.0 - (0.0 if clipf is None else clip01(clipf))))
    blocking = None
    if bound is not None:
        blocking = clip01(1.0 / (1.0 + max(0.0, bound - BLOCK_RATIO_REF)))
    ringing = None if ring is None else clip01(1.0 - ring / RING_LAP_SCALE)
    return {
        "sharpness": sharpness,
        "blur": blur,
        "noise": noise,
        "exposure": exposure,
        "contrast": contrast,
        "blocking": blocking,
        "ringing": ringing,
        "focus_detail": sharpness,  # recommended single channel instead of sharpness+blur
    }


MAPPINGS: dict[str, Callable[[float], float]] = {
    "baseline_soft_int": lambda q: float(production_soft_score(q)),
    "equal_bin_int": lambda q: float(equal_bin_1_5(q)),
    "linear_round_int": lambda q: float(linear_round_1_5(q)),
    "linear_continuous": linear_continuous_1_5,
}

SOURCES = {
    "enet": enet_quality_signals,
    "opencv": opencv_quality_signals,
    "classical": classical_quality_signals,
}

CRITERIA = ("sharpness", "blur", "noise", "exposure", "contrast", "blocking", "ringing")


def apply_all(row: dict[str, str]) -> dict[str, Any]:
    out: dict[str, Any] = {
        "media_id": row["media_id"],
        "source_media_key": row["source_media_key"],
        "family": row["family"],
        "severity": float(row["severity"]),
        "is_original": int(row["is_original"]),
    }
    for src_name, fn in SOURCES.items():
        sigs = fn(row)
        for crit in CRITERIA:
            q = sigs.get(crit)
            out[f"{src_name}_q_{crit}"] = q
            if q is None:
                for map_name in MAPPINGS:
                    out[f"{src_name}_{map_name}_{crit}"] = None
                continue
            for map_name, mapper in MAPPINGS.items():
                out[f"{src_name}_{map_name}_{crit}"] = mapper(float(q))
        if src_name == "classical":
            out["classical_q_focus_detail"] = sigs.get("focus_detail")
    return out


def histogram(values: list[float], integer: bool) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    if integer:
        c = Counter(int(v) for v in values)
        return {"n": len(values), "counts": {str(k): c.get(k, 0) for k in range(1, 6)}, "min": min(values), "max": max(values)}
    return {
        "n": len(values),
        "min": min(values),
        "max": max(values),
        "mean": sum(values) / len(values),
        "n_at_1": sum(1 for v in values if v <= 1.0001),
        "n_at_5": sum(1 for v in values if v >= 4.999),
    }


def median(xs: list[float]) -> float | None:
    if not xs:
        return None
    xs = sorted(xs)
    return xs[len(xs) // 2]


def per_image_spearman(rows: list[dict[str, Any]], col: str, family: str) -> list[float]:
    originals = {r["media_id"]: r for r in rows if r["is_original"]}
    by: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for r in rows:
        if r["family"] == family:
            by[r["media_id"]].append(r)
    out: list[float] = []
    for mid, ladder in by.items():
        orig = originals.get(mid)
        series = ([orig] if orig else []) + sorted(ladder, key=lambda x: float(x["severity"]))
        sev = [0.0 if r["is_original"] else float(r["severity"]) for r in series]
        ys: list[float] = []
        ok = True
        for r in series:
            v = r.get(col)
            if v is None:
                ok = False
                break
            ys.append(float(v))
        if not ok or len(ys) < 3:
            continue
        corr = pearson_spearman(sev, ys)
        if corr.get("spearman_r") is not None:
            out.append(float(corr["spearman_r"]))
    return out


def saturation_rate(rows: list[dict[str, Any]], col: str, family: str) -> float | None:
    """Fraction of originals whose ladder integers (incl original) are constant."""
    originals = {r["media_id"]: r for r in rows if r["is_original"]}
    by: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for r in rows:
        if r["family"] == family:
            by[r["media_id"]].append(r)
    flags: list[int] = []
    for mid, ladder in by.items():
        orig = originals.get(mid)
        series = ([orig] if orig else []) + ladder
        ys = [r.get(col) for r in series]
        if any(v is None for v in ys):
            continue
        flags.append(int(len({round(float(v), 6) for v in ys}) == 1))
    if not flags:
        return None
    return sum(flags) / len(flags)


def sensitivity(rows: list[dict[str, Any]], col: str, family: str) -> dict[str, float | None]:
    originals = {r["media_id"]: r for r in rows if r["is_original"]}
    by: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for r in rows:
        if r["family"] == family:
            by[r["media_id"]].append(r)
    small: list[float] = []
    large: list[float] = []
    for mid, ladder in by.items():
        orig = originals.get(mid)
        if orig is None or orig.get(col) is None:
            continue
        y0 = float(orig[col])
        ordered = sorted(ladder, key=lambda x: float(x["severity"]))
        if not ordered:
            continue
        if ordered[0].get(col) is not None:
            small.append(float(ordered[0][col]) - y0)
        if ordered[-1].get(col) is not None:
            large.append(float(ordered[-1][col]) - y0)
    return {"median_delta_smallest_step": median(small), "median_delta_largest_step": median(large), "n": len(large)}


def interference(rows: list[dict[str, Any]], family: str, col: str) -> float | None:
    xs = per_image_spearman(rows, col, family)
    return median(xs)


def run(csv_path: Path, output_dir: Path) -> dict[str, Any]:
    with csv_path.open(newline="", encoding="utf-8") as fh:
        raw_rows = list(csv.DictReader(fh))
    scored = [apply_all(r) for r in raw_rows]
    output_dir.mkdir(parents=True, exist_ok=True)

    dist: dict[str, Any] = {}
    for src in SOURCES:
        for map_name, mapper in MAPPINGS.items():
            integer = map_name != "linear_continuous"
            for crit in CRITERIA:
                col = f"{src}_{map_name}_{crit}"
                vals = [float(r[col]) for r in scored if r.get(col) is not None]
                dist[col] = histogram(vals, integer=integer)

    mono: list[dict[str, Any]] = []
    sat: dict[str, Any] = {}
    sens: dict[str, Any] = {}
    for family in FAMILY_PRIMARY:
        for src in SOURCES:
            for map_name in MAPPINGS:
                crit = FAMILY_PRIMARY[family]
                col = f"{src}_{map_name}_{crit}"
                rs = per_image_spearman(scored, col, family)
                rec = {
                    "family": family,
                    "source": src,
                    "mapping": map_name,
                    "criterion": crit,
                    "n_defined": len(rs),
                    "median_spearman_vs_severity": median(rs),
                    "min_spearman": min(rs) if rs else None,
                    "max_spearman": max(rs) if rs else None,
                }
                mono.append(rec)
                if map_name != "linear_continuous":
                    sat[f"{family}|{col}"] = saturation_rate(scored, col, family)
                sens[f"{family}|{col}"] = sensitivity(scored, col, family)

    # Duplication: sharpness vs blur quality under gaussian_blur + originals
    dup: dict[str, Any] = {}
    pool = [r for r in scored if r["is_original"] or r["family"] == "gaussian_blur"]
    for src in SOURCES:
        for map_name in ("baseline_soft_int", "equal_bin_int", "linear_continuous"):
            a = [float(r[f"{src}_{map_name}_sharpness"]) for r in pool if r.get(f"{src}_{map_name}_sharpness") is not None]
            b = [float(r[f"{src}_{map_name}_blur"]) for r in pool if r.get(f"{src}_{map_name}_blur") is not None]
            n = min(len(a), len(b))
            dup[f"{src}_{map_name}"] = pearson_spearman(a[:n], b[:n])

    inter = {
        "awgn_vs_enet_equal_bin_sharpness": interference(scored, "awgn", "enet_equal_bin_int_sharpness"),
        "awgn_vs_classical_equal_bin_sharpness": interference(scored, "awgn", "classical_equal_bin_int_sharpness"),
        "awgn_vs_classical_equal_bin_noise": interference(scored, "awgn", "classical_equal_bin_int_noise"),
        "blur_vs_enet_equal_bin_noise": interference(scored, "gaussian_blur", "enet_equal_bin_int_noise"),
        "ringing_vs_enet_equal_bin_sharpness": interference(scored, "ringing", "enet_equal_bin_int_sharpness"),
    }

    payload = {
        "generated_at": _now_iso(),
        "source_csv": str(csv_path),
        "n_rows": len(scored),
        "mappings": list(MAPPINGS),
        "a_priori_scales": {
            "LAP_SCALE": LAP_SCALE,
            "NOISE_SIGMA_SCALE": NOISE_SIGMA_SCALE,
            "RING_LAP_SCALE": RING_LAP_SCALE,
            "BLOCK_RATIO_REF": BLOCK_RATIO_REF,
            "note": "From production OpenCV/trainer knobs, not fitted on this CSV.",
        },
        "distributions": dist,
        "monotonicity": mono,
        "saturation_fraction_constant_ladder": sat,
        "sensitivity": sens,
        "sharpness_blur_duplication": dup,
        "interference": inter,
        "disclaimer": "Knob sensitivity only. Not human criterion accuracy. Production unmodified.",
    }

    fieldnames: list[str] = []
    for r in scored:
        for k in r:
            if k not in fieldnames:
                fieldnames.append(k)
    with (output_dir / "candidate_scores.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(scored)
    with (output_dir / "monotonicity.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(mono[0].keys()) if mono else [])
        w.writeheader()
        w.writerows(mono)
    (output_dir / "metrics.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    return payload


def fmt(v: Any, d: int = 3) -> str:
    if v is None:
        return "N/A"
    if isinstance(v, float):
        if math.isnan(v):
            return "N/A"
        return f"{v:.{d}f}"
    return str(v)


def write_report(path: Path, p: dict[str, Any]) -> None:
    dist = p["distributions"]
    lines = [
        "# Technical scoring candidates (Phase 9)",
        "",
        "**Status: complete.** Research mappings on the Phase 8 370-file CSV. Production scoring was not changed. No human ratings were invented. MUSIQ was not used as criterion evidence.",
        "",
        f"Generated: {p['generated_at']}",
        f"Input: `{p['source_csv']}`",
        f"n = {p['n_rows']}",
        "",
        "Mappings (a priori, not percentile-fitted):",
        "",
        "- `baseline_soft_int`: production `_soft_score` (1 unreachable).",
        "- `equal_bin_int`: q in [0,1] → 1..5 equal-width bins (can emit 1 and 5).",
        "- `linear_round_int`: round(1+4q), clipped to 1..5.",
        "- `linear_continuous`: 1+4q (float).",
        "",
        "Sources: `enet` (inverted defect heads), `opencv` (same direction rules), `classical` (Laplacian/Immerkaer/exposure×clip/RMS×clip/boundary ratio/edge Laplacian) with documented scales "
        f"{p['a_priori_scales']}.",
        "",
        "## 1. Can the map produce 1 and 5? (all 370 files, EfficientNet quality)",
        "",
        "| Map | Criterion | n@1 | n@2 | n@3 | n@4 | n@5 |",
        "|-----|-----------|----:|----:|----:|----:|----:|",
    ]
    for crit in CRITERIA:
        for map_name in ("baseline_soft_int", "equal_bin_int", "linear_round_int"):
            h = dist.get(f"enet_{map_name}_{crit}", {})
            c = h.get("counts") or {}
            lines.append(
                f"| {map_name} | {crit} | {c.get('1', 0)} | {c.get('2', 0)} | {c.get('3', 0)} | {c.get('4', 0)} | {c.get('5', 0)} |"
            )
    lines += [
        "",
        "## 2. Severity ranking (median Spearman, quality vs severity; expect negative)",
        "",
        "| Family | Criterion | ENET baseline | ENET equal-bin | ENET continuous | Classical equal-bin |",
        "|--------|-----------|--------------:|---------------:|----------------:|--------------------:|",
    ]
    by = {(m["family"], m["source"], m["mapping"]): m for m in p["monotonicity"]}
    for family, crit in FAMILY_PRIMARY.items():
        def g(src: str, mp: str) -> str:
            rec = by.get((family, src, mp), {})
            return f"{fmt(rec.get('median_spearman_vs_severity'))} (n={rec.get('n_defined', 0)})"

        lines.append(
            f"| {family} | {crit} | {g('enet', 'baseline_soft_int')} | {g('enet', 'equal_bin_int')} | {g('enet', 'linear_continuous')} | {g('classical', 'equal_bin_int')} |"
        )
    lines += [
        "",
        "n = originals with defined Spearman (non-constant series).",
        "",
        "## 3. Saturation (fraction of images whose ladder is constant)",
        "",
        "See `metrics.json` key `saturation_fraction_constant_ladder`.",
        "",
        "## 4. Sharpness vs Blur duplication (originals + Gaussian ladder)",
        "",
    ]
    for k, v in p["sharpness_blur_duplication"].items():
        lines.append(f"- `{k}`: Pearson {fmt(v.get('pearson_r'))}, Spearman {fmt(v.get('spearman_r'))}, n={v.get('n')}")
    lines += [
        "",
        "## 5. Interference (median Spearman of a *non-primary* score vs that family's severity)",
        "",
    ]
    for k, v in p["interference"].items():
        lines.append(f"- `{k}`: {fmt(v)}")
    lines += [
        "",
        "## 6. Nonredundant technical summary (proposal only)",
        "",
        "Do **not** change production `overall_score` / XP. If a later phase adds fields, prefer:",
        "",
        "1. Overall perceptual quality: MUSIQ OPQ (separate track).",
        "2. Focus/detail: **one** Laplacian (or ENET sharpness) channel. Drop Blur from any mean, or replace Blur with a future motion/defocus detector that is not `1-sharpness`.",
        "3. Noise: Immerkaer (or ENET noise amount inverted) with a texture caveat.",
        "4. Exposure: triangle **times** clip-fraction penalty.",
        "5. Contrast: RMS **times** clip penalty (so harsh gain is not rewarded).",
        "6. Blocking: 8×8 boundary ratio, not flat-patch fraction.",
        "7. Ringing: edge-Laplacian energy.",
        "",
        "## 7. What deserves real-world / human validation next",
        "",
        "See the protocol section in this file. Knob Spearman is not ACCESS accuracy.",
        "",
        "## 8. Production",
        "",
        "Unchanged.",
        "",
        "Stopped for review.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=PHASE8_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    if not args.csv.is_file():
        print(f"STOP: missing Phase 8 CSV {args.csv}", file=sys.stderr)
        return 2
    payload = run(args.csv.resolve(), args.output_dir.resolve())
    write_report(args.output_dir / "TECHNICAL_SCORING_CANDIDATES_AUTO.md", payload)
    print(json.dumps({"n": payload["n_rows"], "out": str(args.output_dir)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
