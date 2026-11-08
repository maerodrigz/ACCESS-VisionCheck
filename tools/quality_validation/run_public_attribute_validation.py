#!/usr/bin/env python3
"""Score Phase 9 candidates against public criterion-specific labels when local files exist.

Does not download datasets. Does not invent labels. Does not overwrite the 30-photo pilot pack.
Does not use KonIQ or LIVEC MOS as criterion ground truth.
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

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.classical_quality_metrics import analyze_image_bytes as classical_analyze  # noqa: E402
from tools.quality_validation.engines import ENGINE_EFFICIENTNET, ENGINE_OPENCV, analyze_image_metrics  # noqa: E402
from tools.quality_validation.importers.spaq import import_spaq  # noqa: E402
from tools.quality_validation.metrics import spearman_bootstrap  # noqa: E402
from tools.quality_validation.public_dataset_catalog import CATALOG, DATASETS_ROOT, discover  # noqa: E402
from tools.quality_validation.scale_mapping import (  # noqa: E402
    apply_derived_mapped_columns,
    map_linear_to_1_5,
    map_noisiness_raw_to_noise_quality_1_5,
    parse_optional_float,
)
from tools.quality_validation.scoring_candidates import (  # noqa: E402
    MAPPINGS,
    classical_quality_signals,
    enet_quality_signals,
    opencv_quality_signals,
)

SEED = 20261107
INTEGER_MAPS = frozenset({"baseline_soft_int", "equal_bin_int", "linear_round_int"})
DEFAULT_OUT = DATASETS_ROOT / "public_attribute_validation" / "output" / "run_001"
SPAQ_ROOT = DATASETS_ROOT / "spaq"
SPAQ_MAPPING = _TOOLKIT / "templates" / "import_mapping.spaq.example.json"
HUMAN_PILOT = _TOOLKIT / "workspace" / "human_pilot"

# SPAQ attribute -> ACCESS signal name in scoring_candidates (higher = better after invert).
SPAQ_PAIRS = (
    {
        "key": "noise",
        "access": "Noise",
        "comparability": "directly_comparable_after_invert",
        "reference_raw": "attr_noisiness_raw",
        "human_quality": lambda raw, scale: map_noisiness_raw_to_noise_quality_1_5(raw, scale),
        "signal": "noise",
        "mae_if_integer": True,
    },
    {
        "key": "sharpness",
        "access": "Sharpness",
        "comparability": "related_proxy",
        "reference_raw": "attr_sharpness_raw",
        "human_quality": lambda raw, scale: map_linear_to_1_5(raw) if str(scale).startswith("0") else None,
        "signal": "sharpness",
        "mae_if_integer": False,
    },
    {
        "key": "brightness",
        "access": "Brightness",
        "comparability": "related_proxy",
        "reference_raw": "attr_brightness_raw",
        "human_quality": lambda raw, scale: map_linear_to_1_5(raw) if str(scale).startswith("0") else None,
        "signal": "exposure",
        "mae_if_integer": False,
    },
    {
        "key": "contrast",
        "access": "Contrast",
        "comparability": "related_proxy",
        "reference_raw": "attr_contrast_raw",
        "human_quality": lambda raw, scale: map_linear_to_1_5(raw) if str(scale).startswith("0") else None,
        "signal": "contrast",
        "mae_if_integer": False,
    },
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def find_spaq_table(root: Path) -> Path | None:
    candidates: list[Path] = []
    for folder in (root, root / "metadata"):
        if not folder.is_dir():
            continue
        for p in folder.iterdir():
            if p.suffix.lower() in {".csv", ".xlsx", ".xls"} and p.is_file():
                name = p.name.lower()
                if "mos" in name or "attribute" in name or p.suffix.lower() == ".csv":
                    candidates.append(p)
    for p in candidates:
        if "attribute" in p.name.lower() or "mos" in p.name.lower():
            return p
    return candidates[0] if candidates else None


def find_image(images_dir: Path, key: str) -> Path | None:
    name = Path(key).name
    for cand in (images_dir / name, images_dir / f"{Path(key).stem}.jpg", images_dir / f"{Path(key).stem}.JPG"):
        if cand.is_file():
            return cand
    return None


def score_image(path: Path) -> dict[str, Any]:
    content = path.read_bytes()
    enet, _ = analyze_image_metrics(content, ENGINE_EFFICIENTNET)
    opencv, _ = analyze_image_metrics(content, ENGINE_OPENCV)
    classic = classical_analyze(content) or {}
    raw: dict[str, str] = {}
    for prefix, src in (("enet", enet), ("opencv", opencv)):
        if not src:
            continue
        for k in ("sharpness", "blur", "noise", "brightness", "contrast", "blocking_artifacts", "ringing_artifacts"):
            if src.get(k) is not None:
                raw[f"{prefix}_raw_{k}"] = str(src[k])
    mapping = {
        "classic_sharpness_laplacian_var": "sharpness_laplacian_var",
        "classic_noise_immerkaer": "noise_immerkaer",
        "classic_brightness_mean": "brightness_mean",
        "classic_exposure_clip_frac": "exposure_clip_frac",
        "classic_contrast_rms": "contrast_rms",
        "classic_blocking_boundary_ratio": "blocking_boundary_ratio",
        "classic_ringing_edge_lap": "ringing_edge_lap",
    }
    for dest, src_k in mapping.items():
        if classic.get(src_k) is not None:
            raw[dest] = str(classic[src_k])
    out: dict[str, Any] = {"path": str(path), **raw}
    for src_name, fn in (
        ("enet", enet_quality_signals),
        ("opencv", opencv_quality_signals),
        ("classical", classical_quality_signals),
    ):
        sigs = fn(raw)
        for sig, q in sigs.items():
            if q is None or not isinstance(q, (int, float)):
                continue
            for map_name, mapper in MAPPINGS.items():
                out[f"{src_name}_{map_name}_{sig}"] = mapper(float(q))
    return out


def histogram(values: list[float], integer: bool) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    if integer:
        c = Counter(int(round(v)) for v in values)
        return {"n": len(values), "counts": {str(i): c.get(i, 0) for i in range(1, 6)}}
    return {"n": len(values), "min": min(values), "max": max(values), "mean": sum(values) / len(values)}


def run_spaq(spaq_root: Path, output_dir: Path, *, limit: int | None, infer: bool) -> dict[str, Any]:
    table = find_spaq_table(spaq_root)
    images_dir = spaq_root / "images"
    mapping = SPAQ_ROOT / "metadata" / "import_mapping.spaq.json"
    if not mapping.is_file():
        mapping = SPAQ_MAPPING
    if table is None:
        return {"status": "blocked", "reason": "SPAQ score table not found", "root": str(spaq_root)}
    if not images_dir.is_dir():
        return {"status": "blocked", "reason": "SPAQ images/ folder not found", "table": str(table)}

    rows, warnings = import_spaq(table, mapping)
    rows = [apply_derived_mapped_columns(dict(r)) for r in rows]
    paired: list[dict[str, Any]] = []
    missing_images = 0
    for rec in rows:
        img = find_image(images_dir, rec["source_media_key"])
        if img is None:
            missing_images += 1
            continue
        rec = dict(rec)
        rec["image_path"] = str(img)
        paired.append(rec)
        if limit is not None and len(paired) >= limit:
            break
    if not paired:
        return {
            "status": "blocked",
            "reason": "SPAQ labels loaded but no matching image files",
            "n_labels": len(rows),
            "missing_images": missing_images,
            "warnings": warnings[:20],
        }
    if not infer:
        return {
            "status": "labels_ready_images_present",
            "n_paired": len(paired),
            "n_labels": len(rows),
            "missing_images": missing_images,
            "table": str(table),
            "note": "Pass --infer to score Phase 9 candidates. Not run by default in discovery.",
        }

    scored_rows: list[dict[str, Any]] = []
    for rec in paired:
        machine = score_image(Path(rec["image_path"]))
        scored_rows.append({**rec, **machine})

    comparisons: dict[str, Any] = {}
    distributions: dict[str, Any] = {}
    for spec in SPAQ_PAIRS:
        humans: list[float] = []
        for rec in scored_rows:
            raw = parse_optional_float(rec.get(spec["reference_raw"]))
            hq = spec["human_quality"](raw, rec.get("attribute_scale") or "0-100")
            rec[f"human_{spec['key']}_quality_1_5"] = hq
            if hq is not None:
                humans.append(float(hq))
        distributions[f"human_{spec['key']}"] = histogram(humans, integer=False)
        for src in ("enet", "opencv", "classical"):
            for map_name in MAPPINGS:
                col = f"{src}_{map_name}_{spec['signal']}"
                hs: list[float] = []
                ms: list[float] = []
                for rec in scored_rows:
                    h = rec.get(f"human_{spec['key']}_quality_1_5")
                    m = rec.get(col)
                    if h is None or m is None:
                        continue
                    hs.append(float(h))
                    ms.append(float(m))
                mae_ok = bool(spec["mae_if_integer"] and map_name in INTEGER_MAPS)
                boot = spearman_bootstrap(ms, hs, seed=SEED)
                comparisons[f"{spec['key']}|{src}|{map_name}"] = {
                    "access": spec["access"],
                    "comparability": spec["comparability"],
                    "n_paired": len(hs),
                    "spearman_r": boot.get("spearman_r"),
                    "spearman_ci_low": boot.get("spearman_ci_low"),
                    "spearman_ci_high": boot.get("spearman_ci_high"),
                    "pearson_r": boot.get("pearson_r"),
                    "mae": None,
                    "mae_reported": False,
                }
                if mae_ok and hs:
                    from tools.quality_validation.metrics import mae_rmse

                    err = mae_rmse(ms, hs)
                    comparisons[f"{spec['key']}|{src}|{map_name}"]["mae"] = err["mae"]
                    comparisons[f"{spec['key']}|{src}|{map_name}"]["mae_reported"] = True
                distributions[col] = histogram(ms, integer=map_name in INTEGER_MAPS)

    output_dir.mkdir(parents=True, exist_ok=True)
    if scored_rows:
        fieldnames: list[str] = []
        for rec in scored_rows:
            for k in rec:
                if k not in fieldnames:
                    fieldnames.append(k)
        with (output_dir / "spaq_candidate_scores.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(scored_rows)
    payload = {
        "status": "scored",
        "n_paired": len(scored_rows),
        "missing_images": missing_images,
        "comparisons": comparisons,
        "distributions": distributions,
        "warnings": warnings[:20],
        "seed": SEED,
    }
    (output_dir / "spaq_metrics.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--spaq-root", type=Path, default=SPAQ_ROOT)
    parser.add_argument("--limit", type=int, default=None, help="Optional cap for a smoke subset. Not a fitted split.")
    parser.add_argument("--infer", action="store_true", help="Run EfficientNet/OpenCV/classical on matched SPAQ images.")
    args = parser.parse_args()
    if HUMAN_PILOT.exists() and args.output_dir.resolve() == HUMAN_PILOT.resolve():
        print("STOP: will not write into the 30-photo pilot pack", file=sys.stderr)
        return 2
    discovery = discover()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "dataset_discovery.json").write_text(json.dumps(discovery, indent=2), encoding="utf-8")
    (args.output_dir / "dataset_catalog.json").write_text(json.dumps(CATALOG, indent=2), encoding="utf-8")
    spaq = run_spaq(args.spaq_root.resolve(), args.output_dir.resolve() / "spaq", limit=args.limit, infer=args.infer)
    summary = {
        "generated_at": _now(),
        "seed": SEED,
        "pilot_pack_untouched": True,
        "production_untouched": True,
        "koniq_livec_used_as_criterion_gt": False,
        "discovery": discovery,
        "spaq": spaq,
        "disclaimer": (
            "No fabricated labels. Missing public datasets are blockers, not zeros. "
            "Controlled-distortion Spearman is not human accuracy. MUSIQ overall is not a criterion."
        ),
    }
    (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")
    print(json.dumps({"spaq_status": spaq.get("status"), "out": str(args.output_dir)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
