#!/usr/bin/env python3
"""Compare locked Phase 10 single-rater scores to EfficientNet and candidate maps.

Does not invent ratings. MAE is reported only on 1-5 integer vs 1-5 integer pairs.
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
from tools.quality_validation.metrics import mae_rmse, pearson_spearman  # noqa: E402
from tools.quality_validation.real_world_schema import parse_score_1_5  # noqa: E402
from tools.quality_validation.scoring_candidates import (  # noqa: E402
    MAPPINGS,
    classical_quality_signals,
    enet_quality_signals,
    opencv_quality_signals,
)

PHOTO_TECHNICAL = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)
HUMAN_TO_SIGNAL = {
    "sharpness": "sharpness",
    "blur": "blur",
    "noise": "noise",
    "brightness": "exposure",
    "contrast": "contrast",
    "blocking_artifacts": "blocking",
    "ringing_artifacts": "ringing",
}
RUN002_CRITERION = {
    "sharpness": "criterion_Sharpness",
    "blur": "criterion_Blur",
    "noise": "criterion_Noise",
    "brightness": "criterion_Brightness",
    "contrast": "criterion_Contrast",
    "blocking_artifacts": "criterion_Blocking_Artifacts",
    "ringing_artifacts": "criterion_Ringing_Artifacts",
}
INTEGER_MAPS = ("baseline_soft_int", "equal_bin_int", "linear_round_int")
DEFAULT_RATINGS = _TOOLKIT / "workspace" / "human_pilot" / "rater_pack" / "ratings_DEV.csv"
DEFAULT_MANIFEST = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "facilitator_manifest.csv"
DEFAULT_IMAGES = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "originals"
DEFAULT_RUN002 = (
    _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output" / "per_image_results.csv"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "analysis"


def load_ratings(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for raw in csv.DictReader(handle):
            mid = (raw.get("media_id") or "").strip()
            if not mid:
                continue
            scores = {col: parse_score_1_5(raw.get(col)) for col in PHOTO_TECHNICAL}
            scores["overall_visual_quality"] = parse_score_1_5(raw.get("overall_visual_quality"))
            rows.append(
                {
                    "media_id": mid,
                    "rater_id": (raw.get("rater_id") or "").strip() or "DEV",
                    "scores": scores,
                    "notes": (raw.get("notes") or "").strip(),
                }
            )
    return rows


def filled_count(rows: list[dict[str, Any]]) -> int:
    n = 0
    for row in rows:
        n += sum(1 for col in PHOTO_TECHNICAL if row["scores"].get(col) is not None)
    return n


def load_csv_map(path: Path, key: str) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {(row.get(key) or "").strip(): row for row in csv.DictReader(handle) if row.get(key)}


def histogram(values: list[float]) -> dict[str, int]:
    counts = Counter(int(v) for v in values)
    return {str(i): counts.get(i, 0) for i in range(1, 6)}


def metric_block(human: list[float], machine: list[float], *, mae_allowed: bool) -> dict[str, Any]:
    corr = pearson_spearman(human, machine)
    out: dict[str, Any] = {
        "n_paired": len(human),
        "spearman_r": corr.get("spearman_r"),
        "spearman_p": corr.get("spearman_p"),
        "pearson_r": corr.get("pearson_r"),
        "mae": None,
        "rmse": None,
        "mae_reported": False,
        "mae_reason": "not a matched 1-5 integer pair",
    }
    if mae_allowed:
        err = mae_rmse(machine, human)
        out["mae"] = err["mae"]
        out["rmse"] = err["rmse"]
        out["mae_reported"] = True
        out["mae_reason"] = "human 1-5 integer vs machine 1-5 integer"
    return out


def row_from_metrics(enet: dict[str, Any] | None, opencv: dict[str, Any] | None, classic: dict[str, float] | None) -> dict[str, str]:
    def put(prefix: str, src: dict[str, Any] | None) -> dict[str, str]:
        if not src:
            return {}
        keys = (
            "sharpness",
            "blur",
            "noise",
            "brightness",
            "contrast",
            "blocking_artifacts",
            "ringing_artifacts",
        )
        out: dict[str, str] = {}
        for key in keys:
            val = src.get(key)
            if val is not None:
                out[f"{prefix}_raw_{key}"] = str(val)
        return out

    row: dict[str, str] = {}
    row.update(put("enet", enet))
    row.update(put("opencv", opencv))
    if classic:
        mapping = {
            "classic_sharpness_laplacian_var": "sharpness_laplacian_var",
            "classic_noise_immerkaer": "noise_immerkaer",
            "classic_brightness_mean": "brightness_mean",
            "classic_exposure_clip_frac": "exposure_clip_frac",
            "classic_contrast_rms": "contrast_rms",
            "classic_blocking_boundary_ratio": "blocking_boundary_ratio",
            "classic_ringing_edge_lap": "ringing_edge_lap",
        }
        for dest, src in mapping.items():
            if classic.get(src) is not None:
                row[dest] = str(classic[src])
    return row


def infer_candidates(image_path: Path) -> dict[str, Any]:
    content = image_path.read_bytes()
    enet, _ = analyze_image_metrics(content, ENGINE_EFFICIENTNET)
    opencv, _ = analyze_image_metrics(content, ENGINE_OPENCV)
    classic = classical_analyze(content)
    raw_row = row_from_metrics(enet, opencv, classic)
    scored: dict[str, Any] = {"raw": raw_row}
    sources = {
        "enet": enet_quality_signals(raw_row),
        "opencv": opencv_quality_signals(raw_row),
        "classical": classical_quality_signals(raw_row),
    }
    for src_name, sigs in sources.items():
        for human_col, sig_name in HUMAN_TO_SIGNAL.items():
            q = sigs.get(sig_name)
            if q is None:
                continue
            for map_name, mapper in MAPPINGS.items():
                scored[f"{src_name}_{map_name}_{human_col}"] = mapper(float(q))
    return scored


def analyze(
    *,
    ratings_path: Path,
    manifest_path: Path,
    run002_csv: Path,
    images_dir: Path,
    infer: bool,
) -> dict[str, Any]:
    human_rows = load_ratings(ratings_path)
    n_filled = filled_count(human_rows)
    if n_filled == 0:
        raise SystemExit(
            "STOP: no human technical scores found. Do not invent ratings. "
            "Fill ratings_DEV.csv or rating_sheet.html, then re-run."
        )
    manifest = load_csv_map(manifest_path, "anonymous_id")
    run002 = load_csv_map(run002_csv, "media_id")

    dist: dict[str, Any] = {}
    for col in PHOTO_TECHNICAL + ("overall_visual_quality",):
        vals = [float(r["scores"][col]) for r in human_rows if r["scores"].get(col) is not None]
        dist[col] = {"n": len(vals), "counts": histogram(vals) if vals else {str(i): 0 for i in range(1, 6)}}

    comparisons: dict[str, Any] = {}
    inferred: dict[str, dict[str, Any]] = {}
    for col in PHOTO_TECHNICAL:
        h_prod: list[float] = []
        m_prod: list[float] = []
        for row in human_rows:
            h = row["scores"].get(col)
            fac = manifest.get(row["media_id"])
            if h is None or not fac:
                continue
            machine = run002.get(fac["koniq2_media_id"], {})
            raw = machine.get(RUN002_CRITERION[col], "")
            m = parse_score_1_5(raw)
            if m is None:
                continue
            h_prod.append(float(h))
            m_prod.append(float(m))
        comparisons[f"human_vs_run002_production_{col}"] = metric_block(h_prod, m_prod, mae_allowed=True)

        if not infer:
            continue
        for src in ("enet", "opencv", "classical"):
            for map_name in MAPPINGS:
                hs: list[float] = []
                ms: list[float] = []
                for row in human_rows:
                    h = row["scores"].get(col)
                    if h is None:
                        continue
                    img = images_dir / f"{row['media_id']}.jpg"
                    if not img.is_file():
                        continue
                    scored = inferred.get(row["media_id"])
                    if scored is None:
                        scored = infer_candidates(img)
                        inferred[row["media_id"]] = scored
                    key = f"{src}_{map_name}_{col}"
                    if scored.get(key) is None:
                        continue
                    hs.append(float(h))
                    ms.append(float(scored[key]))
                mae_ok = map_name in INTEGER_MAPS
                comparisons[f"human_vs_{src}_{map_name}_{col}"] = metric_block(hs, ms, mae_allowed=mae_ok)

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": "exploratory_single_rater",
        "bias_warning": (
            "Single rater, likely the developer. Findings are exploratory and may be biased. "
            "They are not inter-rater reliability and not production accuracy."
        ),
        "n_rows": len(human_rows),
        "n_technical_cells_filled": n_filled,
        "human_distributions": dist,
        "comparisons": comparisons,
        "mae_policy": "MAE only when both series are 1-5 integers (human vs production / equal-bin / linear-round).",
        "disclaimer": "KonIQ MOS is overall-only and is not used as a criterion label. Production unmodified.",
    }
    return payload


def write_report(path: Path, payload: dict[str, Any]) -> None:
    lines = [
        "# Phase 10 single-rater comparison (exploratory)",
        "",
        payload["bias_warning"],
        "",
        f"Generated: {payload['generated_at']}",
        f"Filled technical cells: {payload['n_technical_cells_filled']}",
        "",
        "## Human score distributions",
        "",
    ]
    for col, block in payload["human_distributions"].items():
        c = block["counts"]
        lines.append(
            f"- `{col}` n={block['n']}: 1={c.get('1', 0)} 2={c.get('2', 0)} "
            f"3={c.get('3', 0)} 4={c.get('4', 0)} 5={c.get('5', 0)}"
        )
    lines += ["", "## Spearman (and MAE only on integer pairs)", ""]
    for key, rec in payload["comparisons"].items():
        mae = rec["mae"] if rec["mae_reported"] else "not reported"
        lines.append(
            f"- `{key}`: n={rec['n_paired']} Spearman={rec['spearman_r']} MAE={mae}"
        )
    lines += ["", payload["disclaimer"], ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ratings", type=Path, default=DEFAULT_RATINGS)
    parser.add_argument("--facilitator-manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--run002-results", type=Path, default=DEFAULT_RUN002)
    parser.add_argument("--images-dir", type=Path, default=DEFAULT_IMAGES)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--infer-candidates",
        action="store_true",
        help="After lock only: score ENET/OpenCV/classical candidates on facilitator originals.",
    )
    parser.add_argument("--i-have-locked-ratings", action="store_true")
    args = parser.parse_args()
    if not args.i_have_locked_ratings:
        print("STOP: pass --i-have-locked-ratings after the sheet is filled. No invented scores.", file=sys.stderr)
        return 2
    if not args.ratings.is_file():
        print(f"STOP: missing ratings {args.ratings}", file=sys.stderr)
        return 2
    payload = analyze(
        ratings_path=args.ratings.resolve(),
        manifest_path=args.facilitator_manifest.resolve(),
        run002_csv=args.run002_results.resolve(),
        images_dir=args.images_dir.resolve(),
        infer=args.infer_candidates,
    )
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / "phase10_single_rater_metrics.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    write_report(out / "PHASE10_SINGLE_RATER_RESULTS.md", payload)
    print(json.dumps({"n_filled": payload["n_technical_cells_filled"], "out": str(out)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
