#!/usr/bin/env python3
"""Research-only SPAQ-200 vs ACCESS technical scorer.

Primary scores are production integer 1-5 badges from evaluate_production_quality.
SPAQ human values stay on the published 0-100 scale. No 1-5 remapping, no MAE,
no retraining. Authenticity/DB stay patched closed.

Pass --infer to score. Default writes the comparison plan only.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from unittest.mock import patch

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.engines import (  # noqa: E402
    ENGINE_EFFICIENTNET,
    ENGINE_OPENCV,
    analyze_image_metrics,
    engine_availability,
)
from tools.quality_validation.metrics import correlation_bootstrap, pearson_spearman  # noqa: E402
from tools.quality_validation.real_world_evaluate import evaluate_production_quality  # noqa: E402
from tools.quality_validation.real_world_schema import PHOTO_CRITERIA  # noqa: E402
from tools.quality_validation.scale_mapping import parse_optional_float  # noqa: E402

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
DEFAULT_OUT = SPAQ_ROOT / "output" / "run_001"
SEED = 20261107
RAW_KEYS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)

# SPAQ stays 0-100. Invert noisiness only (100 - raw) so higher = cleaner, matching ACCESS Noise.
COMPARISON_PLAN = (
    {
        "key": "overall_mos",
        "human_field": "mos_quality_raw",
        "human_transform": "identity",
        "machine_field": "overall_score",
        "access": "overall_score",
        "comparability": "related_proxy",
        "note": "SPAQ MOS vs mean of seven integer badges after _soft_score. Not a MOS-trained overall head.",
    },
    {
        "key": "noise",
        "human_field": "attr_noisiness_raw",
        "human_transform": "invert_100_minus",
        "machine_field": "criterion_Noise",
        "access": "Noise",
        "comparability": "directly_comparable_after_invert",
        "note": "SPAQ noisiness high = more noise. ACCESS Noise high = cleaner. Primary uses 100 - noisiness.",
    },
    {
        "key": "sharpness",
        "human_field": "attr_sharpness_raw",
        "human_transform": "identity",
        "machine_field": "criterion_Sharpness",
        "access": "Sharpness",
        "comparability": "related_proxy",
        "note": "SPAQ sharpness vs ACCESS Sharpness badge. Not a Blur validation.",
    },
    {
        "key": "brightness",
        "human_field": "attr_brightness_raw",
        "human_transform": "identity",
        "machine_field": "criterion_Brightness",
        "access": "Brightness",
        "comparability": "related_proxy",
        "note": "Related exposure/brightness opinions, not identical rater instructions.",
    },
    {
        "key": "contrast",
        "human_field": "attr_contrast_raw",
        "human_transform": "identity",
        "machine_field": "criterion_Contrast",
        "access": "Contrast",
        "comparability": "related_proxy",
        "note": "Related contrast opinions, not identical constructs.",
    },
)

RAW_PAIRS = (
    {
        "key": "raw_overall_proxy",
        "human_field": "mos_quality_raw",
        "human_transform": "identity",
        "machine_field": "raw_mean_seven",
        "note": "Mean of seven raw 0-1 heads vs SPAQ MOS. Secondary only.",
    },
    {
        "key": "raw_noise_amount",
        "human_field": "attr_noisiness_raw",
        "human_transform": "identity",
        "machine_field": "raw_noise",
        "note": "Both series are noise amount (high = more noise). No invert.",
    },
    {
        "key": "raw_sharpness",
        "human_field": "attr_sharpness_raw",
        "human_transform": "identity",
        "machine_field": "raw_sharpness",
        "note": "Raw sharpness head 0-1 vs SPAQ sharpness 0-100.",
    },
    {
        "key": "raw_brightness",
        "human_field": "attr_brightness_raw",
        "human_transform": "identity",
        "machine_field": "raw_brightness",
        "note": "Raw brightness head vs SPAQ brightness. Polarity of the head is production-defined.",
    },
    {
        "key": "raw_contrast",
        "human_field": "attr_contrast_raw",
        "human_transform": "identity",
        "machine_field": "raw_contrast",
        "note": "Raw contrast head vs SPAQ contrast.",
    },
)

NOT_LABELED = ("Blur", "Blocking Artifacts", "Ringing Artifacts")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_merged(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def transform_human(kind: str, raw: float | None) -> float | None:
    if raw is None:
        return None
    if kind == "identity":
        return float(raw)
    if kind == "invert_100_minus":
        return 100.0 - float(raw)
    raise ValueError(f"Unknown transform {kind}")


def comparison_plan_payload() -> dict[str, Any]:
    return {
        "scorer": (
            "evaluate_production_quality: media_evaluator.evaluate_bytes, authenticity off, "
            "AI/DB fail-closed. Integer badges after _soft_score. EfficientNet then OpenCV fallback."
        ),
        "human_scale": "SPAQ 0-100 raw. No 1-5 remapping. Noisiness inverted as 100-raw for the Noise pair.",
        "mae_used": False,
        "pairs": list(COMPARISON_PLAN),
        "raw_head_pairs": list(RAW_PAIRS),
        "not_human_validated": list(NOT_LABELED),
        "seed": SEED,
    }


def _engine_id(production_name: str) -> str | None:
    name = (production_name or "").lower()
    if "opencv" in name:
        return ENGINE_OPENCV
    if "efficientnet" in name:
        return ENGINE_EFFICIENTNET
    return None


def score_one(content: bytes, file_name: str) -> dict[str, Any]:
    """One production evaluation plus captured raw heads from the same engine attempts."""
    attempts: list[dict[str, Any]] = []
    last_metrics: dict[str, Any] | None = None

    from app.services import media_evaluator as me

    def capturing(data: bytes, engine: str) -> dict[str, Any] | None:
        nonlocal last_metrics
        eng_id = _engine_id(engine) or ENGINE_OPENCV
        metrics, err = analyze_image_metrics(data, eng_id)  # type: ignore[arg-type]
        attempts.append({"engine": engine, "ok": metrics is not None, "error_code": err})
        if metrics is not None:
            last_metrics = metrics
            return metrics
        return None

    with patch.object(me, "analyze_image_for_engine", side_effect=capturing):
        result = evaluate_production_quality(content, file_name=file_name)

    result = dict(result)
    result["engine_attempts"] = json.dumps(attempts)
    fallback_errs = [a["error_code"] for a in attempts if not a["ok"] and a.get("error_code")]
    result["fallback_reason"] = fallback_errs[0] if result.get("opencv_fallback") and fallback_errs else ""
    if last_metrics:
        for key in RAW_KEYS:
            if last_metrics.get(key) is not None:
                result[f"raw_{key}"] = last_metrics[key]
        vals = [float(last_metrics[k]) for k in RAW_KEYS if last_metrics.get(k) is not None]
        if vals:
            result["raw_mean_seven"] = sum(vals) / len(vals)
    return result


def score_subset(rows: list[dict[str, str]], images_dir: Path) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    total = len(rows)
    for i, rec in enumerate(rows, start=1):
        key = rec["source_media_key"]
        path = images_dir / key
        row: dict[str, Any] = dict(rec)
        row["relative_path"] = f"images/{key}"
        print(f"[{i}/{total}] {key}", flush=True)
        if not path.is_file():
            row.update(
                {
                    "analysis_status": "missing_file",
                    "error_code": "missing_file",
                    "fallback_reason": "",
                    "quality_engine": None,
                    "opencv_fallback": False,
                }
            )
            out.append(row)
            continue
        try:
            result = score_one(path.read_bytes(), key)
        except Exception as exc:
            row.update(
                {
                    "analysis_status": "exception",
                    "error_code": "unhandled_exception",
                    "error_detail": str(exc),
                    "fallback_reason": "",
                    "quality_engine": None,
                    "opencv_fallback": False,
                }
            )
            out.append(row)
            continue
        row.update(result)
        scores = result.get("criterion_scores") or {}
        for name in PHOTO_CRITERIA:
            row[f"criterion_{name.replace(' ', '_')}"] = scores.get(name)
        out.append(row)
    return out


def _is_enet(rec: dict[str, Any]) -> bool:
    engine = str(rec.get("quality_engine") or "").lower()
    return ("efficientnet" in engine) and not bool(rec.get("opencv_fallback"))


def _corr_block(hs: list[float], ms: list[float], spec: dict[str, Any], subset: str) -> dict[str, Any]:
    note = None
    if len(hs) < 2:
        corr: dict[str, Any] = {
            "pearson_r": None,
            "spearman_r": None,
            "n": len(hs),
            "note": "insufficient_n",
        }
        boot: dict[str, Any] = {}
        note = "insufficient_n"
    else:
        corr = pearson_spearman(ms, hs)
        boot = correlation_bootstrap(ms, hs, seed=SEED) if len(hs) >= 5 else {}
        if corr.get("pearson_r") is None:
            note = str(corr.get("note") or "correlation_undefined")
    return {
        **spec,
        "subset": subset,
        "n": len(hs),
        "human_std": float(_std(hs)) if hs else None,
        "machine_std": float(_std(ms)) if ms else None,
        "machine_unique": len(set(ms)),
        "pearson_r": corr.get("pearson_r"),
        "pearson_p": corr.get("pearson_p"),
        "pearson_ci_low": boot.get("pearson_ci_low"),
        "pearson_ci_high": boot.get("pearson_ci_high"),
        "spearman_r": corr.get("spearman_r"),
        "spearman_p": corr.get("spearman_p"),
        "spearman_ci_low": boot.get("spearman_ci_low"),
        "spearman_ci_high": boot.get("spearman_ci_high"),
        "undefined_reason": note,
    }


def _std(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    return (sum((v - mean) ** 2 for v in values) / (len(values) - 1)) ** 0.5


def _pairs(subset: list[dict[str, Any]], spec: dict[str, Any]) -> tuple[list[float], list[float]]:
    hs: list[float] = []
    ms: list[float] = []
    for rec in subset:
        raw = parse_optional_float(rec.get(spec["human_field"]))
        h = transform_human(spec["human_transform"], raw)
        m = parse_optional_float(rec.get(spec["machine_field"]))
        if h is None or m is None:
            continue
        hs.append(float(h))
        ms.append(float(m))
    return hs, ms


def distribution(values: list[float], *, integer_badges: bool) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    counts = Counter(int(round(v)) if integer_badges else round(v, 4) for v in values)
    unique = sorted(set(values))
    n = len(values)
    n_unique = len(unique)
    floor = sum(1 for v in values if integer_badges and int(round(v)) <= 1)
    ceiling = sum(1 for v in values if integer_badges and int(round(v)) >= 5)
    return {
        "n": n,
        "min": min(values),
        "max": max(values),
        "mean": sum(values) / n,
        "std": _std(values),
        "n_unique": n_unique,
        "ties": n - n_unique,
        "constant": n_unique == 1,
        "floor_n_at_1": floor if integer_badges else None,
        "ceiling_n_at_5": ceiling if integer_badges else None,
        "histogram_1_to_5": {str(i): sum(1 for v in values if int(round(v)) == i) for i in range(1, 6)}
        if integer_badges
        else None,
        "top_counts": {str(k): counts[k] for k, _ in counts.most_common(8)},
    }


def compare_rows(scored: list[dict[str, Any]]) -> dict[str, Any]:
    failed = [r for r in scored if r.get("analysis_status") != "ok"]
    ok = [r for r in scored if r.get("analysis_status") == "ok"]
    enet_only = [r for r in ok if _is_enet(r)]
    opencv = [r for r in ok if r.get("opencv_fallback") or "opencv" in str(r.get("quality_engine") or "").lower()]
    comparisons: dict[str, Any] = {}
    for spec in COMPARISON_PLAN:
        for subset_name, subset in (("all_ok", ok), ("efficientnet_only", enet_only)):
            hs, ms = _pairs(subset, spec)
            comparisons[f"{spec['key']}|{subset_name}"] = _corr_block(hs, ms, spec, subset_name)
        if spec["key"] == "noise":
            raw_spec = {**spec, "human_transform": "identity", "key": "noise_uninverted"}
            hs_raw, ms_raw = _pairs(ok, raw_spec)
            comparisons["noise_uninverted|all_ok"] = _corr_block(
                hs_raw, ms_raw, {**spec, "human_transform": "identity", "note": "Direction check: SPAQ noisiness uninverted vs ACCESS Noise."}, "all_ok"
            )

    raw_comparisons: dict[str, Any] = {}
    for spec in RAW_PAIRS:
        for subset_name, subset in (("all_ok", ok), ("efficientnet_only", enet_only)):
            hs, ms = _pairs(subset, spec)
            raw_comparisons[f"{spec['key']}|{subset_name}"] = _corr_block(hs, ms, spec, subset_name)

    badge_dist: dict[str, Any] = {}
    for name in ("overall_score", *[f"criterion_{c.replace(' ', '_')}" for c in PHOTO_CRITERIA]):
        vals = [v for v in (parse_optional_float(r.get(name)) for r in ok) if v is not None]
        badge_dist[name] = distribution(vals, integer_badges=name != "overall_score" or all(float(v).is_integer() or abs(v - round(v, 2)) < 1e-9 for v in vals))
        # overall is mean of integers, often x.xx; treat as continuous-ish but still report unique/ties
        if name == "overall_score":
            badge_dist[name] = distribution(vals, integer_badges=False)
            badge_dist[name]["note"] = "overall_score is the mean of seven integer badges"

    unlabeled = {}
    for name in NOT_LABELED:
        col = f"criterion_{name.replace(' ', '_')}"
        nums = [v for v in (parse_optional_float(r.get(col)) for r in ok) if v is not None]
        unlabeled[name] = {
            "n": len(nums),
            "human_labels": False,
            "correlation_computed": False,
            "distribution": distribution(nums, integer_badges=True),
        }

    return {
        "n_total": len(scored),
        "n_ok": len(ok),
        "n_failed": len(failed),
        "n_efficientnet_only": len(enet_only),
        "n_opencv_fallback": len(opencv),
        "failures": [
            {
                "source_media_key": r.get("source_media_key"),
                "analysis_status": r.get("analysis_status"),
                "error_code": r.get("error_code"),
                "error_detail": r.get("error_detail"),
                "fallback_reason": r.get("fallback_reason"),
                "quality_engine": r.get("quality_engine"),
            }
            for r in failed
        ],
        "comparisons": comparisons,
        "raw_head_comparisons": raw_comparisons,
        "badge_distributions": badge_dist,
        "unlabeled_criteria": unlabeled,
    }


def _fmt_r(val: Any) -> str:
    if val is None:
        return "undefined"
    return f"{float(val):.3f}"


def write_report(payload: dict[str, Any], path: Path) -> None:
    m = payload["metrics"]
    lines = [
        "# SPAQ 200 ACCESS technical scorer evaluation",
        "",
        f"**Generated:** {payload['generated_at']}",
        f"**Status:** `{payload['status']}`",
        "",
        "Research only. Production scoring, weights, API, Flutter, XP, authenticity, Gemini, and MUSIQ were not changed. Human ratings were not rewritten. No retraining or recalibration.",
        "",
        "## Inference summary",
        "",
        "| Group | n |",
        "|-------|---|",
        f"| All images | {m['n_total']} |",
        f"| Successful | {m['n_ok']} |",
        f"| Failed (kept in CSV) | {m['n_failed']} |",
        f"| EfficientNet (no fallback) | {m['n_efficientnet_only']} |",
        f"| OpenCV fallback | {m['n_opencv_fallback']} |",
        "",
    ]
    if m["failures"]:
        lines += ["Failed or incomplete rows:", ""]
        for row in m["failures"]:
            lines.append(
                f"- `{row.get('source_media_key')}`: status={row.get('analysis_status')} "
                f"error={row.get('error_code')} detail={row.get('error_detail')}"
            )
        lines.append("")
    else:
        lines += ["No failed inferences.", ""]

    lines += [
        "## Primary correlations (SPAQ 0-100 vs ACCESS 1-5 badges)",
        "",
        "Pearson and Spearman only. Different scales. High r is not proof of exact human accuracy. MOS vs overall is a related proxy only.",
        "",
        "| Pair | Subset | n | Pearson r | Pearson 95% CI | Spearman r | Spearman 95% CI | Note |",
        "|------|--------|---|-----------|----------------|------------|-----------------|------|",
    ]
    for key in (
        "overall_mos|all_ok",
        "overall_mos|efficientnet_only",
        "noise|all_ok",
        "noise|efficientnet_only",
        "noise_uninverted|all_ok",
        "sharpness|all_ok",
        "sharpness|efficientnet_only",
        "brightness|all_ok",
        "brightness|efficientnet_only",
        "contrast|all_ok",
        "contrast|efficientnet_only",
    ):
        block = m["comparisons"].get(key) or {}
        undef = block.get("undefined_reason") or ""
        lines.append(
            f"| {block.get('key', key.split('|')[0])} | {block.get('subset', key.split('|')[-1])} | {block.get('n')} | "
            f"{_fmt_r(block.get('pearson_r'))} | {_fmt_r(block.get('pearson_ci_low'))} to {_fmt_r(block.get('pearson_ci_high'))} | "
            f"{_fmt_r(block.get('spearman_r'))} | {_fmt_r(block.get('spearman_ci_low'))} to {_fmt_r(block.get('spearman_ci_high'))} | "
            f"{undef or block.get('comparability', '')} |"
        )

    noise_inv = m["comparisons"].get("noise|all_ok") or {}
    noise_raw = m["comparisons"].get("noise_uninverted|all_ok") or {}
    lines += [
        "",
        "### Noise direction check",
        "",
        f"- Uninverted SPAQ noisiness vs ACCESS Noise Spearman: `{_fmt_r(noise_raw.get('spearman_r'))}` "
        "(expected negative if ACCESS Noise is cleanliness).",
        f"- Inverted `100 - noisiness` vs ACCESS Noise Spearman: `{_fmt_r(noise_inv.get('spearman_r'))}` (primary pair).",
        "",
        "## Secondary raw-head correlations",
        "",
        "Captured from the engine that produced the production badges (same attempt). Not member-facing scores.",
        "",
        "| Pair | Subset | n | Pearson r | Spearman r | Undefined |",
        "|------|--------|---|-----------|------------|-----------|",
    ]
    for key, block in m.get("raw_head_comparisons", {}).items():
        lines.append(
            f"| {block.get('key')} | {block.get('subset')} | {block.get('n')} | "
            f"{_fmt_r(block.get('pearson_r'))} | {_fmt_r(block.get('spearman_r'))} | {block.get('undefined_reason') or ''} |"
        )

    lines += ["", "## Badge distributions (successful images)", ""]
    for name, dist in m.get("badge_distributions", {}).items():
        if name.startswith("criterion_") and name.split("criterion_")[-1].replace("_", " ") in NOT_LABELED:
            continue
        lines.append(
            f"- `{name}`: n={dist.get('n')} min={dist.get('min')} max={dist.get('max')} "
            f"mean={None if dist.get('mean') is None else round(float(dist['mean']), 3)} "
            f"unique={dist.get('n_unique')} ties={dist.get('ties')} constant={dist.get('constant')} "
            f"floor@1={dist.get('floor_n_at_1')} ceiling@5={dist.get('ceiling_n_at_5')}"
        )
    lines += ["", "## Unlabeled ACCESS criteria (no SPAQ human claim)", ""]
    for name, block in m.get("unlabeled_criteria", {}).items():
        dist = block.get("distribution") or {}
        lines.append(
            f"- **{name}**: correlation not computed. Machine n={dist.get('n')} "
            f"min={dist.get('min')} max={dist.get('max')} unique={dist.get('n_unique')} constant={dist.get('constant')}."
        )
    lines += [
        "",
        "## What these results support",
        "",
        "- Rank association between SPAQ human opinions and ACCESS member-facing badges on this 200-image MOS-stratified subset, after the documented Noise invert.",
        "- Evidence of score compression (unique values, floor/ceiling, constant heads) that limits how well badges can track 0-100 attributes.",
        "",
        "## What they do not support",
        "",
        "- Human-rated validation of Blur, Blocking Artifacts, or Ringing Artifacts.",
        "- A claim that SPAQ Brightness, Contrast, or Sharpness are the same constructs as ACCESS badges.",
        "- A claim that ACCESS overall_score is a SPAQ MOS IQA benchmark score.",
        "- Absolute accuracy, calibration, or a decision to retrain. MAE was not used.",
        "",
        "## Important limitations",
        "",
        "- ACCESS overall is the mean of seven `_soft_score` integers; rating 1 is typically unreachable on boosted heads.",
        "- EfficientNet-B0 heads were trained on `SyntheticIQADataset`, not SPAQ.",
        "- Pearson mixes a 0-100 continuous human scale with 1-5 integers.",
        "- n=200 is a stratified subset, not the full 11,125-image SPAQ database.",
        "",
        "No accuracy changes were implemented from this run.",
        "",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def flatten_row(rec: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, val in rec.items():
        if key == "criterion_scores":
            continue
        if isinstance(val, (dict, list)):
            out[key] = json.dumps(val)
        else:
            out[key] = val
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=SPAQ_ROOT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--infer", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    merged = root / "metadata" / "human_ratings_200.csv"
    images = root / "images"
    integrity = root / "metadata" / "integrity_report.json"
    if not merged.is_file() or not images.is_dir():
        print("SPAQ 200 extract missing. Run prepare_spaq_200.py first.", file=sys.stderr)
        return 2
    integrity_payload = json.loads(integrity.read_text(encoding="utf-8")) if integrity.is_file() else {}
    if integrity_payload.get("status") != "ok":
        print("Integrity status is not ok; refusing to score.", file=sys.stderr)
        return 2

    plan = comparison_plan_payload()
    plan["generated_at"] = _now()
    plan["engine_availability"] = engine_availability()
    plan["integrity_status"] = integrity_payload.get("status")
    plan["n_images"] = integrity_payload.get("n_readable_jpegs")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "comparison_plan.json").write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")

    if not args.infer:
        print(json.dumps({"status": "plan_only", "out": str(args.output_dir), "infer": False}, indent=2))
        return 0

    rows = load_merged(merged)
    scored = score_subset(rows, images)
    metrics = compare_rows(scored)
    flat = [flatten_row(rec) for rec in scored]
    fieldnames: list[str] = []
    for rec in flat:
        for key in rec:
            if key not in fieldnames:
                fieldnames.append(key)
    csv_path = args.output_dir / "spaq_200_machine_scores.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(flat)
    payload = {
        "generated_at": _now(),
        "status": "scored",
        "production_untouched": True,
        "n_scored": len(scored),
        "plan": plan,
        "metrics": metrics,
    }
    (args.output_dir / "spaq_200_metrics.json").write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(payload, args.output_dir / "SPAQ_200_EVALUATION_REPORT.md")
    write_report(payload, root / "SPAQ_200_EVALUATION_REPORT.md")
    print(json.dumps({"status": "scored", "n": len(scored), "out": str(args.output_dir)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
