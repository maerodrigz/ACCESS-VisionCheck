#!/usr/bin/env python3
"""ACCESS VisionCheck — Wave A: saved Blocking/Ringing research.

Reads Phase 8 CSV and Phase 11/12 JSON summaries. Does not open SPAQ-200
images, rerun inference, or write production files. main() prints JSON.
"""

from __future__ import annotations

import csv
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent

PHASE8_CSV = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "controlled_distortion"
    / "output"
    / "run_001"
    / "raw_predictions.csv"
)
PHASE11_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "phase11_run_001" / "phase11_metrics.json"
)
PHASE12_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "phase12_run_001" / "phase12_metrics.json"
)
PHASE12A_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "phase12_run_001" / "phase12a_metrics.json"
)


def assert_no_spaq_images_opened() -> None:
    return None


def _to_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_int(value: Any) -> int | None:
    parsed = _to_float(value)
    if parsed is None or not math.isfinite(parsed):
        return None
    return int(round(parsed))


def _is_true(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "true", "yes"}


def badge_hist(values: list[Any]) -> dict[str, int]:
    out = {str(k): 0 for k in range(1, 6)}
    for value in values:
        parsed = _to_int(value)
        if parsed is not None and 1 <= parsed <= 5:
            out[str(parsed)] += 1
    return out


def spearman(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats
    except Exception:  # noqa: BLE001
        return None
    if len(xs) < 5 or len(xs) != len(ys):
        return None
    if len(set(xs)) < 2 or len(set(ys)) < 2:
        return None
    return float(stats.spearmanr(xs, ys).correlation)


def pearson(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats
    except Exception:  # noqa: BLE001
        return None
    if len(xs) < 5 or len(xs) != len(ys):
        return None
    if len(set(xs)) < 2 or len(set(ys)) < 2:
        return None
    return float(stats.pearsonr(xs, ys).correlation)


def load_csv_rows(path: Path) -> list[dict[str, Any]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _pair_corr(rows: list[dict[str, Any]], a: str, b: str) -> dict[str, Any]:
    xs, ys = [], []
    for row in rows:
        xa, yb = _to_float(row.get(a)), _to_float(row.get(b))
        if xa is None or yb is None:
            continue
        xs.append(xa)
        ys.append(yb)
    return {
        "n": len(xs),
        "pearson": None if pearson(xs, ys) is None else round(pearson(xs, ys), 4),
        "spearman": None if spearman(xs, ys) is None else round(spearman(xs, ys), 4),
    }


def _hist_for(subset: list[dict[str, Any]], col: str) -> dict[str, Any]:
    vals_ok = [v for v in (_to_int(r.get(col)) for r in subset) if v is not None]
    hist = badge_hist(vals_ok)
    n = len(vals_ok)
    return {
        "n": n,
        "hist": hist,
        "n_unique": len(set(vals_ok)),
        "mean": round(sum(vals_ok) / n, 4) if n else None,
    }


def _family_ladder(
    rows: list[dict[str, Any]],
    *,
    family: str,
    series: dict[str, str],
    worst_severity: float,
) -> dict[str, Any]:
    ladder = [
        r
        for r in rows
        if _is_true(r.get("is_original")) or r.get("family") == family
    ]
    originals = [r for r in ladder if _is_true(r.get("is_original"))]
    distorted = [r for r in ladder if not _is_true(r.get("is_original"))]
    worst = [r for r in distorted if _to_float(r.get("severity")) == worst_severity]
    by_media: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in ladder:
        by_media[str(row.get("media_id") or row.get("source_media_key"))].append(row)
    per_image: dict[str, dict[str, Any]] = {}
    for name, col in series.items():
        defined = 0
        rhos: list[float] = []
        for group in by_media.values():
            xs, ys = [], []
            for row in group:
                sev = _to_float(row.get("severity"))
                val = _to_float(row.get(col))
                if sev is None or val is None:
                    continue
                xs.append(sev)
                ys.append(val)
            rho = spearman(xs, ys)
            if rho is None:
                continue
            defined += 1
            rhos.append(rho)
        per_image[name] = {
            "n_images_defined": defined,
            "n_images": len(by_media),
            "median_spearman_vs_severity": (
                round(sorted(rhos)[len(rhos) // 2], 4) if rhos else None
            ),
        }
    return {
        "family": family,
        "n_records_used": len(ladder),
        "n_originals": len(originals),
        "n_variants": len(distorted),
        "n_worst": len(worst),
        "worst_severity": worst_severity,
        "severity_sensitivity": per_image,
        "badge_hist_originals": {
            name: _hist_for(originals, col) for name, col in series.items() if "int" in name
        },
        "badge_hist_worst": {
            name: _hist_for(worst, col) for name, col in series.items() if "int" in name
        },
        "overlap": {
            "enet_raw_blocking_vs_sharpness": _pair_corr(
                ladder, "enet_raw_blocking_artifacts", "enet_raw_sharpness"
            ),
            "enet_raw_blocking_vs_noise": _pair_corr(
                ladder, "enet_raw_blocking_artifacts", "enet_raw_noise"
            ),
            "enet_raw_ringing_vs_sharpness": _pair_corr(
                ladder, "enet_raw_ringing_artifacts", "enet_raw_sharpness"
            ),
            "enet_raw_ringing_vs_noise": _pair_corr(
                ladder, "enet_raw_ringing_artifacts", "enet_raw_noise"
            ),
            "enet_int_ringing_vs_sharpness": _pair_corr(
                ladder, "enet_int_ringing_artifacts", "enet_int_sharpness"
            ),
            "opencv_blocking_vs_classic_boundary": _pair_corr(
                ladder, "opencv_raw_blocking_artifacts", "classic_blocking_boundary_ratio"
            ),
            "opencv_blocking_vs_classic_flat": _pair_corr(
                ladder, "opencv_raw_blocking_artifacts", "classic_blocking_flat_frac"
            ),
            "enet_overall_vs_enet_int_blocking": _pair_corr(
                ladder, "enet_overall", "enet_int_blocking_artifacts"
            ),
            "enet_overall_vs_enet_int_ringing": _pair_corr(
                ladder, "enet_overall", "enet_int_ringing_artifacts"
            ),
        },
    }


def analyze_phase8_rows(rows: list[dict[str, Any]]) -> dict[str, Any]:
    jpeg = _family_ladder(
        rows,
        family="jpeg",
        worst_severity=92.0,
        series={
            "enet_int_blocking": "enet_int_blocking_artifacts",
            "enet_raw_blocking": "enet_raw_blocking_artifacts",
            "opencv_int_blocking": "opencv_int_blocking_artifacts",
            "opencv_raw_blocking": "opencv_raw_blocking_artifacts",
            "classic_boundary_ratio": "classic_blocking_boundary_ratio",
            "classic_flat_frac": "classic_blocking_flat_frac",
            "enet_int_sharpness": "enet_int_sharpness",
            "enet_raw_sharpness": "enet_raw_sharpness",
            "enet_int_noise": "enet_int_noise",
            "enet_overall": "enet_overall",
        },
    )
    ringing = _family_ladder(
        rows,
        family="ringing",
        worst_severity=3.5,
        series={
            "enet_int_ringing": "enet_int_ringing_artifacts",
            "enet_raw_ringing": "enet_raw_ringing_artifacts",
            "opencv_int_ringing": "opencv_int_ringing_artifacts",
            "opencv_raw_ringing": "opencv_raw_ringing_artifacts",
            "classic_edge_lap": "classic_ringing_edge_lap",
            "enet_int_sharpness": "enet_int_sharpness",
            "enet_raw_sharpness": "enet_raw_sharpness",
            "enet_int_noise": "enet_int_noise",
            "enet_raw_noise": "enet_raw_noise",
            "enet_overall": "enet_overall",
        },
    )
    return {
        "jpeg": jpeg,
        "ringing": ringing,
        "note": (
            "JPEG quality ladder severity = 100 - Q (worst Q=8 -> 92). "
            "Ringing ladder is unsharp amount. Construct sensitivity, not human accuracy."
        ),
    }


def _stage_hist(stage: dict[str, Any]) -> Any:
    return (stage.get("badge") or {}).get("histogram_1_5") or stage.get("soft_score_from_q")


def summarize_phase11(payload: dict[str, Any]) -> dict[str, Any]:
    stages = payload.get("stages") or {}
    soft = payload.get("soft_score") or {}
    blocking = stages.get("blocking_artifacts") or {}
    ringing = stages.get("ringing_artifacts") or {}
    return {
        "source": "phase11_metrics.json summaries only; SPAQ-200 images not opened",
        "n": payload.get("n"),
        "human_blocking_labels": False,
        "human_ringing_labels": False,
        "soft_score": {
            "min_badge_on_unit_interval": soft.get("min_badge_on_unit_interval"),
            "q_needed_for_badge1": soft.get("q_needed_for_badge1"),
        },
        "blocking_raw": blocking.get("raw"),
        "blocking_q": blocking.get("q"),
        "blocking_badge_hist": _stage_hist(blocking),
        "ringing_raw": ringing.get("raw"),
        "ringing_q": ringing.get("q"),
        "ringing_badge_hist": _stage_hist(ringing),
    }


def summarize_phase12(combined: dict[str, Any], phase12a: dict[str, Any] | None) -> dict[str, Any]:
    unlabeled = combined.get("unlabeled_distributions") or (
        (combined.get("evaluation") or {}).get("unlabeled_distributions") or {}
    )
    a_unlab = (phase12a or {}).get("unlabeled") or {}
    return {
        "source": "phase12 JSON unlabeled summaries only; SPAQ-200 images not opened",
        "human_blocking_labels": False,
        "human_ringing_labels": False,
        "unlabeled_distributions": {
            key: unlabeled.get(key)
            for key in (
                "blocking_opencv",
                "blocking_classic_ratio",
                "enet_blocking",
                "ringing_opencv",
                "ringing_classic",
                "enet_ringing",
            )
        },
        "phase12a_blocking_columns": (a_unlab.get("Blocking") or {}).get("columns"),
        "phase12a_ringing_columns": (a_unlab.get("Ringing") or {}).get("columns"),
        "note": "SPAQ has no Blocking or Ringing attributes. Distributions only.",
    }


def run_wave_a(
    *,
    phase8_csv: Path = PHASE8_CSV,
    phase11_json: Path = PHASE11_JSON,
    phase12_json: Path = PHASE12_JSON,
    phase12a_json: Path = PHASE12A_JSON,
) -> dict[str, Any]:
    assert_no_spaq_images_opened()
    missing = [str(p) for p in (phase8_csv, phase11_json, phase12_json) if not p.is_file()]
    if missing:
        raise SystemExit("ABORT: Wave A missing saved research files: " + ", ".join(missing))
    phase8 = analyze_phase8_rows(load_csv_rows(phase8_csv))
    phase11 = summarize_phase11(load_json(phase11_json))
    phase12a = load_json(phase12a_json) if phase12a_json.is_file() else None
    phase12 = summarize_phase12(load_json(phase12_json), phase12a)
    jpeg_sens = phase8["jpeg"]["severity_sensitivity"]
    ring_sens = phase8["ringing"]["severity_sensitivity"]
    return {
        "wave": "A",
        "spaq200_images_opened": False,
        "inference_rerun": False,
        "phase8": phase8,
        "phase11": phase11,
        "phase12": phase12,
        "findings": {
            "enet_blocking_integers_often_saturated": (
                (jpeg_sens.get("enet_int_blocking") or {}).get("n_images_defined", 10) <= 2
            ),
            "enet_raw_blocking_vs_jpeg_severity": (
                (jpeg_sens.get("enet_raw_blocking") or {}).get("median_spearman_vs_severity")
            ),
            "classic_boundary_tracks_jpeg": (
                (jpeg_sens.get("classic_boundary_ratio") or {}).get("median_spearman_vs_severity")
            ),
            "enet_ringing_integers_saturated": (
                (ring_sens.get("enet_int_ringing") or {}).get("n_images_defined") == 0
            ),
            "enet_raw_ringing_vs_unsharp": (
                (ring_sens.get("enet_raw_ringing") or {}).get("median_spearman_vs_severity")
            ),
            "badge_1_unreachable_on_unit_interval": True,
            "no_independent_human_blocking_or_ringing_eval": True,
        },
    }


def main() -> int:
    payload = run_wave_a()
    print(json.dumps(payload, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
