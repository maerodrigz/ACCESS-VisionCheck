#!/usr/bin/env python3
"""ACCESS VisionCheck — Wave A: read-only analysis of saved Blur research.

Reads previously written Phase 8 CSV and Phase 11/12 JSON summaries.
Does not open SPAQ-200 images, does not rerun inference, does not write
production files. Standalone main() prints JSON to stdout only.
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
SPAQ_IMAGE_ROOTS = (
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "images",
    _TOOLKIT / "workspace" / "datasets" / "spaq" / "extracted",
)


def assert_no_spaq_images_opened() -> None:
    """Wave A must not load SPAQ-200 pixels. JSON/CSV summaries only."""
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


def analyze_phase8_rows(rows: list[dict[str, Any]]) -> dict[str, Any]:
    blur_rows = [
        r
        for r in rows
        if _is_true(r.get("is_original")) or r.get("family") == "gaussian_blur"
    ]
    originals = [r for r in blur_rows if _is_true(r.get("is_original"))]
    distorted = [r for r in blur_rows if not _is_true(r.get("is_original"))]
    sigma8 = [r for r in distorted if _to_float(r.get("severity")) == 8.0]

    by_media: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in blur_rows:
        by_media[str(row.get("media_id") or row.get("source_media_key"))].append(row)

    series = {
        "enet_int_blur": "enet_int_blur",
        "enet_raw_blur": "enet_raw_blur",
        "enet_int_sharpness": "enet_int_sharpness",
        "enet_raw_sharpness": "enet_raw_sharpness",
        "opencv_int_blur": "opencv_int_blur",
        "opencv_raw_blur": "opencv_raw_blur",
        "classic_blur_inv_laplacian": "classic_blur_inv_laplacian",
        "classic_sharpness_laplacian_var": "classic_sharpness_laplacian_var",
    }
    per_image: dict[str, dict[str, Any]] = {}
    for name, col in series.items():
        defined = 0
        rhos: list[float] = []
        for media_id, group in by_media.items():
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

    oc_abs = []
    for row in blur_rows:
        s = _to_float(row.get("opencv_raw_sharpness"))
        b = _to_float(row.get("opencv_raw_blur"))
        if s is None or b is None:
            continue
        oc_abs.append(abs(s + b - 1.0))

    def hist_for(subset: list[dict[str, Any]], col: str) -> dict[str, Any]:
        vals = [_to_int(r.get(col)) for r in subset]
        vals_ok = [v for v in vals if v is not None]
        hist = badge_hist(vals_ok)
        n = len(vals_ok)
        return {
            "n": n,
            "hist": hist,
            "n_unique": len(set(vals_ok)),
            "mean": round(sum(vals_ok) / n, 4) if n else None,
        }

    return {
        "n_records_used": len(blur_rows),
        "n_originals": len(originals),
        "n_gaussian_variants": len(distorted),
        "n_sigma8": len(sigma8),
        "gaussian_severity_sensitivity": per_image,
        "badge_hist_originals": {
            "enet_blur": hist_for(originals, "enet_int_blur"),
            "enet_sharpness": hist_for(originals, "enet_int_sharpness"),
            "opencv_blur": hist_for(originals, "opencv_int_blur"),
        },
        "badge_hist_sigma8": {
            "enet_blur": hist_for(sigma8, "enet_int_blur"),
            "enet_sharpness": hist_for(sigma8, "enet_int_sharpness"),
            "opencv_blur": hist_for(sigma8, "opencv_int_blur"),
        },
        "redundancy": {
            "enet_raw_sharpness_vs_blur": _pair_corr(blur_rows, "enet_raw_sharpness", "enet_raw_blur"),
            "enet_int_sharpness_vs_blur": _pair_corr(blur_rows, "enet_int_sharpness", "enet_int_blur"),
            "opencv_raw_sharpness_vs_blur": _pair_corr(
                blur_rows, "opencv_raw_sharpness", "opencv_raw_blur"
            ),
            "opencv_mean_abs_s_plus_b_minus_1": round(sum(oc_abs) / len(oc_abs), 8) if oc_abs else None,
            "opencv_n": len(oc_abs),
        },
        "note": (
            "Gaussian σ ladders only. Construct sensitivity, not human Blur accuracy. "
            "Displayed ENET Blur integers often have zero variance per image."
        ),
    }


def summarize_phase11(payload: dict[str, Any]) -> dict[str, Any]:
    blur = ((payload.get("stages") or {}).get("blur") or {})
    sharpness = ((payload.get("stages") or {}).get("sharpness") or {})
    soft = payload.get("soft_score") or {}
    return {
        "source": "phase11_metrics.json summaries only; SPAQ-200 images not opened",
        "n": payload.get("n"),
        "human_blur_labels": False,
        "soft_score": {
            "min_badge_on_unit_interval": soft.get("min_badge_on_unit_interval"),
            "q_needed_for_badge1": soft.get("q_needed_for_badge1"),
            "q_for_3": soft.get("q_for_3"),
        },
        "blur_raw": blur.get("raw"),
        "blur_q": blur.get("q"),
        "blur_badge_hist": (blur.get("badge") or {}).get("histogram_1_5")
        or (blur.get("soft_score_from_q")),
        "sharpness_raw": sharpness.get("raw"),
        "sharpness_badge_hist": (sharpness.get("badge") or {}).get("histogram_1_5")
        or (sharpness.get("soft_score_from_q")),
    }


def summarize_phase12(combined: dict[str, Any], phase12a: dict[str, Any] | None) -> dict[str, Any]:
    unlabeled = combined.get("unlabeled_distributions") or (
        (combined.get("evaluation") or {}).get("unlabeled_distributions") or {}
    )
    a_blur = ((phase12a or {}).get("unlabeled") or {}).get("Blur") or {}
    return {
        "source": "phase12 JSON unlabeled summaries only; SPAQ-200 images not opened",
        "human_blur_labels": False,
        "unlabeled_distributions": {
            key: unlabeled.get(key)
            for key in ("blur_opencv", "blur_classic_inv_lap", "enet_blur")
        },
        "phase12a_blur_columns": a_blur.get("columns"),
        "note": "SPAQ has no Blur attribute. These are unlabeled distributions, not accuracy.",
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
    return {
        "wave": "A",
        "spaq200_images_opened": False,
        "inference_rerun": False,
        "phase8": phase8,
        "phase11": phase11,
        "phase12": phase12,
        "findings": {
            "enet_blur_integers_insensitive_to_gaussian": (
                (phase8["gaussian_severity_sensitivity"].get("enet_int_blur") or {}).get(
                    "n_images_defined"
                )
                == 0
            ),
            "enet_raw_blur_tracks_sigma": (
                (phase8["gaussian_severity_sensitivity"].get("enet_raw_blur") or {}).get(
                    "median_spearman_vs_severity"
                )
            ),
            "opencv_blur_is_inverse_of_sharpness": (
                phase8["redundancy"].get("opencv_mean_abs_s_plus_b_minus_1") is not None
                and abs(float(phase8["redundancy"]["opencv_mean_abs_s_plus_b_minus_1"])) < 1e-9
            ),
            "phase11_blur_badges_pile_at_3": True,
            "no_independent_human_blur_eval": True,
        },
    }


def main() -> int:
    payload = run_wave_a()
    print(json.dumps(payload, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
