#!/usr/bin/env python3
"""Baseline vs experimental photo-quality evaluation (research-only).

Holdout policy:
- Experimental scales are a priori (not fitted on SPAQ-200 or the ACCESS pilot).
- Primary external test set: SPAQ-200 attribute labels (sharpness, noisiness,
  brightness, contrast). No Blur/Blocking/Ringing SPAQ attributes exist.
- Controlled-distortion ladders provide technical monotonicity diagnostics.
- The 30-image ACCESS human pilot is reported only as a frozen secondary check
  and must NOT be used to tune scales in this script.

Does not modify production code, Run 001/002 outputs, or human CSVs.
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

from tools.quality_validation.metrics import pearson_spearman  # noqa: E402


def _load_engine(engine: str):
    if engine in {"v1", "experimental_classical_v1"}:
        from tools.quality_validation.experimental_quality_engine import (  # noqa: WPS433
            ENGINE_ID,
            analyze_image_bytes,
        )

        return ENGINE_ID, analyze_image_bytes
    if engine in {"v2", "experimental_classical_v2"}:
        from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: WPS433
            ENGINE_ID,
            analyze_image_bytes,
        )

        return ENGINE_ID, analyze_image_bytes
    if engine in {"v3", "experimental_classical_v3"}:
        from tools.quality_validation.experimental_quality_engine_v3 import (  # noqa: WPS433
            ENGINE_ID,
            analyze_image_bytes,
        )

        return ENGINE_ID, analyze_image_bytes
    raise SystemExit(f"Unknown engine {engine!r}; use v1, v2, or v3")

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
SPAQ_IMAGES = SPAQ_ROOT / "images"
SPAQ_HUMAN = SPAQ_ROOT / "metadata" / "human_ratings_200.csv"
SPAQ_BASELINE = SPAQ_ROOT / "output" / "run_001" / "spaq_200_machine_scores.csv"
CTRL_ROOT = _TOOLKIT / "workspace" / "datasets" / "controlled_distortion" / "generated"
CTRL_SEED = CTRL_ROOT / "CTRL-001"
PILOT_MANIFEST = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "facilitator_manifest.csv"
PILOT_CONSENSUS = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "human_consensus_by_image.csv"
)
PILOT_MACHINE = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "machine_scores_joined.csv"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"

PHOTO_CRITERIA = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)
CSV_COL = {
    "Sharpness": "sharpness",
    "Blur": "blur",
    "Noise": "noise",
    "Brightness": "brightness",
    "Contrast": "contrast",
    "Blocking Artifacts": "blocking_artifacts",
    "Ringing Artifacts": "ringing_artifacts",
}


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


def _corr_block(xs: list[float], ys: list[float]) -> dict[str, Any]:
    if len(xs) < 3:
        return {"n": len(xs), "spearman_r": None, "pearson_r": None}
    corr = pearson_spearman(xs, ys)
    return {
        "n": len(xs),
        "spearman_r": corr.get("spearman_r"),
        "spearman_p": corr.get("spearman_p"),
        "pearson_r": corr.get("pearson_r"),
        "pearson_p": corr.get("pearson_p"),
    }


def load_csv_map(path: Path, key: str) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {(row.get(key) or "").strip(): row for row in csv.DictReader(handle) if row.get(key)}


def score_spaq(
    *,
    analyze_image_bytes,
    limit: int | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    humans = load_csv_map(SPAQ_HUMAN, "media_id")
    baseline = load_csv_map(SPAQ_BASELINE, "media_id")
    rows: list[dict[str, Any]] = []
    failures = 0
    t0 = time.perf_counter()
    media_ids = sorted(humans.keys())
    if limit is not None:
        media_ids = media_ids[:limit]
    for mid in media_ids:
        hum = humans[mid]
        key = hum.get("source_media_key") or f"{mid.replace('spaq_', '')}.jpg"
        path = SPAQ_IMAGES / key
        base = baseline.get(mid, {})
        rec: dict[str, Any] = {
            "media_id": mid,
            "source_media_key": key,
            "stratum_label": hum.get("stratum_label", ""),
            "mos_quality_raw": hum.get("mos_quality_raw", ""),
            "attr_sharpness_raw": hum.get("attr_sharpness_raw", ""),
            "attr_noisiness_raw": hum.get("attr_noisiness_raw", ""),
            "attr_brightness_raw": hum.get("attr_brightness_raw", ""),
            "attr_contrast_raw": hum.get("attr_contrast_raw", ""),
            "baseline_overall": base.get("overall_score", ""),
            "baseline_engine": base.get("quality_engine", ""),
        }
        for name in PHOTO_CRITERIA:
            rec[f"baseline_{CSV_COL[name]}"] = base.get(f"criterion_{name.replace(' ', '_')}", "")
        if not path.is_file():
            rec["experimental_status"] = "missing_file"
            failures += 1
            rows.append(rec)
            continue
        content = path.read_bytes()
        t_img = time.perf_counter()
        result = analyze_image_bytes(content)
        elapsed_ms = (time.perf_counter() - t_img) * 1000.0
        if result is None:
            rec["experimental_status"] = "failed"
            failures += 1
            rows.append(rec)
            continue
        rec["experimental_status"] = "ok"
        rec["experimental_elapsed_ms"] = round(elapsed_ms, 2)
        rec["experimental_overall"] = result["overall_score"]
        for name, col in CSV_COL.items():
            rec[f"experimental_{col}"] = result["criterion_scores"][name]
            rec[f"experimental_q_{col}"] = result["quality_0_1"][col]
        for raw_name, raw_val in result["raw"].items():
            rec[f"raw_{raw_name}"] = raw_val
        rows.append(rec)
    wall = time.perf_counter() - t0
    summary = {
        "dataset": "SPAQ-200",
        "n_requested": len(media_ids),
        "n_rows": len(rows),
        "n_ok": sum(1 for r in rows if r.get("experimental_status") == "ok"),
        "n_failed": failures,
        "wall_seconds": round(wall, 3),
        "mean_ms_ok": None,
    }
    times = [float(r["experimental_elapsed_ms"]) for r in rows if r.get("experimental_elapsed_ms") is not None]
    if times:
        summary["mean_ms_ok"] = float(np.mean(times))
        summary["median_ms_ok"] = float(np.median(times))
    return rows, summary


def spaq_comparisons(rows: list[dict[str, Any]]) -> dict[str, Any]:
    ok = [r for r in rows if r.get("experimental_status") == "ok"]
    out: dict[str, Any] = {"badge_distributions": {}, "attribute_correlations": {}, "notes": []}

    for name, col in CSV_COL.items():
        base_vals = [int(float(r[f"baseline_{col}"])) for r in ok if str(r.get(f"baseline_{col}", "")).strip()]
        exp_vals = [int(r[f"experimental_{col}"]) for r in ok if r.get(f"experimental_{col}") is not None]
        out["badge_distributions"][name] = {
            "baseline": _hist(base_vals),
            "experimental": _hist(exp_vals),
            "baseline_n_unique": len(set(base_vals)),
            "experimental_n_unique": len(set(exp_vals)),
        }

    # SPAQ attributes: higher sharpness/brightness/contrast = better.
    # noisiness: higher = more noise; ACCESS Noise badge higher = cleaner => invert SPAQ.
    pairs = [
        ("Sharpness", "attr_sharpness_raw", "experimental_sharpness", False, "baseline_sharpness"),
        ("Noise_cleanliness", "attr_noisiness_raw", "experimental_noise", True, "baseline_noise"),
        ("Brightness", "attr_brightness_raw", "experimental_brightness", False, "baseline_brightness"),
        ("Contrast", "attr_contrast_raw", "experimental_contrast", False, "baseline_contrast"),
    ]
    for label, attr, exp_col, invert_attr, base_col in pairs:
        hx: list[float] = []
        ey: list[float] = []
        by: list[float] = []
        for r in ok:
            try:
                h = float(r[attr])
                e = float(r[exp_col])
                b = float(r[base_col])
            except (TypeError, ValueError, KeyError):
                continue
            if invert_attr:
                h = 100.0 - h
            hx.append(h)
            ey.append(e)
            by.append(b)
        out["attribute_correlations"][label] = {
            "human_field": attr,
            "human_inverted": invert_attr,
            "experimental_vs_human": _corr_block(hx, ey),
            "baseline_vs_human": _corr_block(hx, by),
            "comparable": True,
            "note": (
                "SPAQ attribute is a related proxy, not an ACCESS 1-5 rubric label."
            ),
        }

    out["notes"].extend(
        [
            "SPAQ has no Blur, Blocking, or Ringing attribute labels.",
            "Do not claim ACCESS human alignment from SPAQ attributes alone.",
            "Scales were not fitted on SPAQ-200.",
        ]
    )

    # Overall vs MOS (different construct; report only).
    mos_x: list[float] = []
    exp_o: list[float] = []
    base_o: list[float] = []
    for r in ok:
        try:
            mos_x.append(float(r["mos_quality_raw"]))
            exp_o.append(float(r["experimental_overall"]))
            base_o.append(float(r["baseline_overall"]))
        except (TypeError, ValueError):
            continue
    out["overall_vs_mos_exploratory"] = {
        "construct_note": "SPAQ MOS is overall-only; experimental/baseline overall are means of seven badges.",
        "experimental_vs_mos": _corr_block(mos_x, exp_o),
        "baseline_vs_mos": _corr_block(mos_x, base_o),
    }
    return out


def controlled_ladder_diagnostics(analyze_image_bytes) -> dict[str, Any]:
    """Monotonicity checks on existing controlled-distortion PNGs/JPGs."""
    root = CTRL_SEED if CTRL_SEED.is_dir() else CTRL_ROOT
    if not root.is_dir():
        return {"available": False, "reason": "controlled_distortion/generated missing"}

    families = {
        "gaussian_blur": sorted(root.glob("gaussian_blur_*.png")),
        "awgn": sorted(root.glob("awgn_*.png")),
        "jpeg": sorted(root.glob("jpeg_*.jpg")),
        "underexposure": sorted(root.glob("underexposure_*.png")),
        "overexposure": sorted(root.glob("overexposure_*.png")),
    }
    report: dict[str, Any] = {"available": True, "families": {}}
    for family, paths in families.items():
        series: list[dict[str, Any]] = []
        for path in paths:
            result = analyze_image_bytes(path.read_bytes())
            if result is None:
                continue
            series.append(
                {
                    "file": path.name,
                    "sharpness": result["criterion_scores"]["Sharpness"],
                    "blur": result["criterion_scores"]["Blur"],
                    "noise": result["criterion_scores"]["Noise"],
                    "brightness": result["criterion_scores"]["Brightness"],
                    "contrast": result["criterion_scores"]["Contrast"],
                    "blocking": result["criterion_scores"]["Blocking Artifacts"],
                    "ringing": result["criterion_scores"]["Ringing Artifacts"],
                    "q": result["quality_0_1"],
                    "raw": result.get("raw"),
                }
            )
        primary = {
            "gaussian_blur": ("blur", "descending_expected"),
            "awgn": ("noise", "descending_expected"),
            "jpeg": ("blocking", "mixed_or_descending"),
            "underexposure": ("brightness", "descending_expected"),
            "overexposure": ("brightness", "descending_expected"),
        }[family]
        vals = [row[primary[0]] for row in series]
        report["families"][family] = {
            "n": len(series),
            "primary_badge": primary[0],
            "expectation": primary[1],
            "badge_sequence": vals,
            "rows": series,
        }
    return report


def frozen_access_pilot_check(analyze_image_bytes) -> dict[str, Any]:
    """Secondary check only. Must not be used for tuning."""
    if not PILOT_CONSENSUS.is_file() or not PILOT_MANIFEST.is_file():
        return {"available": False}
    consensus = load_csv_map(PILOT_CONSENSUS, "media_id")
    manifest = load_csv_map(PILOT_MANIFEST, "anonymous_id")
    baseline = load_csv_map(PILOT_MACHINE, "media_id") if PILOT_MACHINE.is_file() else {}
    originals = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "originals"
    rows: list[dict[str, Any]] = []
    for mid in sorted(consensus.keys()):
        img = originals / f"{mid}.jpg"
        if not img.is_file():
            continue
        result = analyze_image_bytes(img.read_bytes())
        if result is None:
            continue
        hum = consensus[mid]
        base = baseline.get(mid, {})
        row: dict[str, Any] = {
            "media_id": mid,
            "koniq2_media_id": manifest.get(mid, {}).get("koniq2_media_id", ""),
            "experimental_overall": result["overall_score"],
            "baseline_overall": base.get("overall_score", ""),
        }
        for name, col in CSV_COL.items():
            row[f"human_{col}_median"] = hum.get(f"{col}_median", "")
            row[f"experimental_{col}"] = result["criterion_scores"][name]
            row[f"baseline_{col}"] = base.get(col, "")
        rows.append(row)

    corrs: dict[str, Any] = {}
    for name, col in CSV_COL.items():
        hx: list[float] = []
        ey: list[float] = []
        by: list[float] = []
        for r in rows:
            try:
                h = float(r[f"human_{col}_median"])
                e = float(r[f"experimental_{col}"])
            except (TypeError, ValueError):
                continue
            hx.append(h)
            ey.append(e)
            try:
                by.append(float(r[f"baseline_{col}"]))
            except (TypeError, ValueError):
                pass
        corrs[name] = {
            "experimental_vs_human_median": _corr_block(hx, ey),
            "baseline_vs_human_median": _corr_block(hx[: len(by)], by) if len(by) == len(hx) else {"n": len(by)},
        }
    return {
        "available": True,
        "role": "frozen_secondary_check_not_for_tuning",
        "n_images": len(rows),
        "correlations": corrs,
        "per_image": rows,
        "disclaimer": (
            "ACCESS pilot was not used to select experimental scales. "
            "These correlations are descriptive only and are not an unbiased claim of improvement."
        ),
    }


def write_report(path: Path, payload: dict[str, Any]) -> None:
    spaq = payload["spaq"]
    corr = spaq["comparisons"]["attribute_correlations"]
    lines = [
        "# Experimental photo-quality engine evaluation",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Experimental engine: `{payload['engine_id']}`",
        "",
        "## Safety",
        "",
        "- Production scoring, Run 001/002 folders, and human CSVs were not modified.",
        "- Experimental scales are a priori (not fitted on SPAQ-200 or the ACCESS pilot).",
        "- SPAQ attributes are related proxies, not ACCESS rubric labels.",
        "- Blur / Blocking / Ringing have no SPAQ attribute ground truth here.",
        "",
        "## SPAQ-200 runtime",
        "",
        f"- n_ok: {spaq['summary']['n_ok']} / {spaq['summary']['n_requested']}",
        f"- wall seconds: {spaq['summary']['wall_seconds']}",
        f"- mean ms/image: {spaq['summary'].get('mean_ms_ok')}",
        "",
        "## Badge distributions (baseline production vs experimental)",
        "",
    ]
    for name, block in spaq["comparisons"]["badge_distributions"].items():
        lines.append(
            f"- **{name}**: baseline unique={block['baseline_n_unique']} {block['baseline']}; "
            f"experimental unique={block['experimental_n_unique']} {block['experimental']}"
        )
    lines.extend(
        [
            "",
            "## SPAQ attribute Spearman (proxy human labels)",
            "",
            "| Pair | Baseline ρ | Experimental ρ | n |",
            "|---|---:|---:|---:|",
        ]
    )
    for label, block in corr.items():
        b = block["baseline_vs_human"]
        e = block["experimental_vs_human"]
        lines.append(
            f"| {label} | {_fmt(b.get('spearman_r'))} | {_fmt(e.get('spearman_r'))} | {e.get('n')} |"
        )
    mos = spaq["comparisons"]["overall_vs_mos_exploratory"]
    lines.extend(
        [
            "",
            "## Overall vs SPAQ MOS (exploratory; different constructs)",
            "",
            f"- Baseline ρ: {_fmt(mos['baseline_vs_mos'].get('spearman_r'))}",
            f"- Experimental ρ: {_fmt(mos['experimental_vs_mos'].get('spearman_r'))}",
            "",
            "## Controlled-distortion diagnostics",
            "",
        ]
    )
    ctrl = payload.get("controlled_distortion") or {}
    if not ctrl.get("available"):
        lines.append("- Not available.")
    else:
        for family, block in ctrl.get("families", {}).items():
            lines.append(
                f"- `{family}` primary `{block['primary_badge']}` sequence: {block['badge_sequence']}"
            )
    pilot = payload.get("access_pilot_frozen") or {}
    lines.extend(["", "## ACCESS pilot frozen secondary check", ""])
    if not pilot.get("available"):
        lines.append("- Not available.")
    else:
        lines.append(pilot["disclaimer"])
        lines.append("")
        lines.append("| Criterion | Baseline ρ | Experimental ρ | n |")
        lines.append("|---|---:|---:|---:|")
        for name, block in pilot.get("correlations", {}).items():
            b = block.get("baseline_vs_human_median") or {}
            e = block.get("experimental_vs_human_median") or {}
            lines.append(
                f"| {name} | {_fmt(b.get('spearman_r'))} | {_fmt(e.get('spearman_r'))} | {e.get('n')} |"
            )
    lines.extend(
        [
            "",
            "## Recommendation",
            "",
            payload["recommendation"]["summary"],
            "",
        ]
    )
    for bullet in payload["recommendation"]["bullets"]:
        lines.append(f"- {bullet}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def _fmt(value: Any) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value)


def build_recommendation(payload: dict[str, Any]) -> dict[str, Any]:
    corr = payload["spaq"]["comparisons"]["attribute_correlations"]
    improved = []
    worsened = []
    for label, block in corr.items():
        b = block["baseline_vs_human"].get("spearman_r")
        e = block["experimental_vs_human"].get("spearman_r")
        if b is None or e is None:
            continue
        if e > b + 0.05:
            improved.append((label, b, e))
        elif e < b - 0.05:
            worsened.append((label, b, e))
    dist = payload["spaq"]["comparisons"]["badge_distributions"]
    more_spread = [
        name
        for name, block in dist.items()
        if block["experimental_n_unique"] > block["baseline_n_unique"]
    ]
    bullets = [
        "Do not auto-integrate into production from this run alone.",
        "Preserve production EfficientNet + `_soft_score` until ACCESS-criterion humans on a held-out set show stable gains.",
        "Experimental engine increases ordinal spread via equal-bin mapping and classical proxies.",
    ]
    if improved:
        bullets.append(
            "SPAQ proxy Spearman improved for: "
            + ", ".join(f"{n} ({b:.3f}→{e:.3f})" for n, b, e in improved)
        )
    if worsened:
        bullets.append(
            "SPAQ proxy Spearman worsened for: "
            + ", ".join(f"{n} ({b:.3f}→{e:.3f})" for n, b, e in worsened)
        )
    if more_spread:
        bullets.append("Broader experimental badge support on: " + ", ".join(more_spread))
    bullets.extend(
        [
            "Blocking/Ringing remain proxies; edge-Laplacian ringing can confuse texture with halos.",
            "Blur remains a focus-related proxy, not a validated motion-blur detector.",
            "Next smallest step: freeze experimental v1, collect more ACCESS-rubric labels on a disjoint set, then re-evaluate without retuning.",
        ]
    )
    engine_name = payload.get("engine_id", "experimental")
    if improved and not worsened:
        summary = (
            f"{engine_name} shows defensible SPAQ-proxy gains without fitted pilot thresholds, "
            "but production integration is still NOT recommended until ACCESS-criterion holdout evidence exists."
        )
        integrate = False
    elif improved:
        summary = (
            f"{engine_name} shows mixed SPAQ-proxy results (some gains, some losses). "
            "Do not replace production scoring."
        )
        integrate = False
    else:
        summary = (
            f"{engine_name} did not demonstrate clear SPAQ-proxy superiority across available attributes. "
            "Keep production unchanged; continue research."
        )
        integrate = False
    return {
        "integrate_to_production": integrate,
        "summary": summary,
        "bullets": bullets,
        "smallest_safe_next_step": (
            f"Keep {engine_name} research-only; add ACCESS-rubric labels on a new "
            "disjoint photo set; compare baseline vs experimental without retuning scales."
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--engine", type=str, default="v2", help="v1 or v2 (default v2)")
    parser.add_argument("--limit", type=int, default=None, help="Optional SPAQ subset for smoke tests")
    parser.add_argument("--skip-pilot", action="store_true")
    parser.add_argument("--skip-controlled", action="store_true")
    args = parser.parse_args(argv)

    engine_id, analyze_image_bytes = _load_engine(args.engine)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.output_root / f"exp_eval_{args.engine}_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)

    spaq_rows, spaq_summary = score_spaq(analyze_image_bytes=analyze_image_bytes, limit=args.limit)
    _write_csv(out_dir / "spaq200_baseline_vs_experimental.csv", spaq_rows)
    comparisons = spaq_comparisons(spaq_rows)

    controlled = {"available": False, "skipped": True}
    if not args.skip_controlled:
        controlled = controlled_ladder_diagnostics(analyze_image_bytes)
        (out_dir / "controlled_distortion_diagnostics.json").write_text(
            json.dumps(controlled, indent=2, default=str), encoding="utf-8"
        )

    pilot = {"available": False, "skipped": True}
    if not args.skip_pilot:
        pilot = frozen_access_pilot_check(analyze_image_bytes)
        if pilot.get("available"):
            _write_csv(out_dir / "access_pilot_frozen_secondary.csv", pilot.get("per_image") or [])

    payload: dict[str, Any] = {
        "generated_at": _now(),
        "engine_id": engine_id,
        "output_dir": str(out_dir),
        "spaq": {"summary": spaq_summary, "comparisons": comparisons},
        "controlled_distortion": controlled,
        "access_pilot_frozen": {k: v for k, v in pilot.items() if k != "per_image"},
        "production_modified": False,
        "inference_rerun_production": False,
        "fitted_on_spaq": False,
        "fitted_on_access_pilot": False,
    }
    payload["recommendation"] = build_recommendation(payload)
    (out_dir / "evaluation_report.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    write_report(out_dir / "EXPERIMENTAL_QUALITY_EVAL_REPORT.md", payload)
    print(json.dumps({"status": "ok", "output_dir": str(out_dir), "recommendation": payload["recommendation"]["summary"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
