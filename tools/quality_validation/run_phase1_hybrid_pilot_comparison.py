#!/usr/bin/env python3
"""Phase 1 research: hybrid NR-IQA vs locked EfficientNet-B0 on the 30-image pilot.

Protocol (frozen before scoring):
  - Dataset: human_pilot rater_pack images PILOT-001..030 + locked consensus medians
    from pilot_hvsm_20261108T114511Z (no re-rating).
  - ENET baseline: locked machine_scores_joined.csv from the same pilot run
    (no EfficientNet re-inference; checkpoint untouched).
  - Hybrid: classical OpenCV/NumPy criteria + official MUSIQ OPQ (if TF Hub loads).
  - Maps: a priori equal_bin / Phase 9 scales. Not tuned on these 30 images.
  - Metrics: Spearman (primary), Pearson where both series are continuous /
    same construct; MAE only when scores share a 1-5 comparable scale.
  - No production API / Flutter / DB / XP / PROBE / WaveRep changes.

Usage (backend venv for classical; TF research venv for MUSIQ optional):
  access_backend/venv312/Scripts/python.exe run_phase1_hybrid_pilot_comparison.py
  tools/quality_validation/.venv_musiq_official_phase1/Scripts/python.exe \\
      run_phase1_hybrid_pilot_comparison.py --with-musiq
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from hybrid_nr_iqa_research import (  # noqa: E402
    MUSIQ_LICENSE_NOTES,
    RESIZE_CAP,
    attach_musiq,
    load_official_musiq_predict_fn,
    score_image_classical,
    score_jpeg_musiq,
)
from metrics import mae_rmse, pearson_spearman  # noqa: E402

PILOT_IMAGES = _TOOLKIT / "workspace" / "human_pilot" / "rater_pack" / "images"
PILOT_LOCKED = (
    _TOOLKIT / "workspace" / "human_pilot" / "output" / "pilot_hvsm_20261108T114511Z"
)
HUMAN_CONSENSUS = PILOT_LOCKED / "human_consensus_by_image.csv"
ENET_JOINED = PILOT_LOCKED / "machine_scores_joined.csv"
DEFAULT_MUSIQ_BENCHMARK_CSV = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "musiq_paq2piq_benchmark"
    / "raw_predictions.csv"
)
DEFAULT_TFHUB_CACHE = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "official_musiq_engine_verification"
    / "cache"
    / "tfhub"
)

CRITERIA = (
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
)

# Human pilot sheets do not include color balance / saturation columns.
COLOR_CRITERIA = ("color_balance", "color_saturation")

PILOT_PRIOR_USE = {
    "used_for_enet_human_vs_machine_evaluation": True,
    "used_to_fit_enet_thresholds_or_weights": False,
    "used_to_fit_hybrid_a_priori_maps": False,
    "used_to_calibrate_musiq_1_5": False,
    "role_in_phase1": (
        "Transparent retrospective comparison only. Hybrid maps and MUSIQ weights "
        "were not tuned on these 30 images. ENET scores are the locked Run002 join "
        "from the same pilot analysis folder."
    ),
    "related_development_sets": (
        "SPAQ-200 was used for exploratory classical/Tenengrad readiness (not this "
        "pilot). Phase 8/9 controlled distortion informed a priori classical scales. "
        "LIVEC / official MUSIQ validation used public MOS, not this pilot."
    ),
}


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    keys: list[str] = []
    for row in rows:
        for k in row:
            if k not in keys:
                keys.append(k)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=keys)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in keys})


def _f(row: dict[str, str], key: str) -> float | None:
    v = row.get(key, "")
    if v is None or v == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def _pairs(xs: list[float | None], ys: list[float | None]) -> tuple[list[float], list[float]]:
    a: list[float] = []
    b: list[float] = []
    for x, y in zip(xs, ys, strict=True):
        if x is None or y is None:
            continue
        a.append(float(x))
        b.append(float(y))
    return a, b


def _corr_block(xs: list[float | None], ys: list[float | None], *, mae_ok: bool) -> dict[str, Any]:
    a, b = _pairs(xs, ys)
    out: dict[str, Any] = {"n": len(a), **pearson_spearman(a, b)}
    if mae_ok and len(a) > 0:
        out.update(mae_rmse(a, b))
        out["mae_applicable"] = True
        out["mae_note"] = "Both series on comparable 1-5 integer/near-integer scale"
    else:
        out["mae"] = None
        out["rmse"] = None
        out["mae_applicable"] = False
        out["mae_note"] = (
            "MAE withheld: scales not comparable (e.g. MUSIQ ~0-100 vs human 1-5), "
            "or continuous q vs discrete human without a frozen 1-5 calibration"
        )
    return out


def _pilot_source_key_by_id() -> dict[str, str]:
    """Map PILOT-xxx -> source_media_key from locked ENET join (same pilot pack)."""
    out: dict[str, str] = {}
    for row in _read_csv(ENET_JOINED):
        mid = row.get("media_id", "")
        key = row.get("source_media_key", "")
        if mid and key:
            out[mid] = key
    return out


def attach_musiq_from_benchmark_csv(
    hybrid_rows: list[dict[str, Any]],
    benchmark_csv: Path,
) -> dict[str, Any]:
    """Join prior research MUSIQ PaQ-2-PiQ raw scores for the same Run002 files.

    Used when live TF Hub install/inference is unavailable. Scores come from
    tools/quality_validation KonIQ MUSIQ benchmark (same source_media_key bytes as
    the pilot). Official TF Hub vs that engine was previously checked on n=24
    (Pearson ~0.9997, Spearman ~0.992, MAD ~0.07) — ranking-near, not bit-identical.
    """
    by_key: dict[str, dict[str, str]] = {}
    for row in _read_csv(benchmark_csv):
        key = row.get("source_media_key", "")
        if key:
            by_key[key] = row
    key_by_id = _pilot_source_key_by_id()
    hit = 0
    miss: list[str] = []
    for row in hybrid_rows:
        mid = str(row["media_id"])
        key = key_by_id.get(mid, "")
        src = by_key.get(key)
        if src is None or src.get("musiq_status") != "ok":
            row["musiq_opq_raw"] = None
            row["musiq_engine"] = "prior_benchmark_csv_miss"
            row["musiq_error"] = f"no musiq_raw_score for source_media_key={key}"
            miss.append(mid)
            continue
        row["musiq_opq_raw"] = float(src["musiq_raw_score"])
        row["musiq_engine"] = (
            "prior_research_musiq_paq2piq_benchmark_csv "
            "(same Run002 source_media_key; live TF Hub deferred)"
        )
        row["musiq_error"] = None
        hit += 1
    return {
        "requested": True,
        "loaded": hit > 0,
        "engine": "prior_research_musiq_paq2piq_benchmark_csv",
        "benchmark_csv": str(benchmark_csv),
        "n_joined": hit,
        "n_miss": len(miss),
        "miss_ids": miss,
        "live_tfhub": False,
        "license": MUSIQ_LICENSE_NOTES,
        "provenance_note": (
            "Live official TF Hub scoring was not completed in this Phase 1 session "
            "(tensorflow-cpu wheel download failed on this host). OPQ values are the "
            "locked research MUSIQ PaQ-2-PiQ raw scores for the identical Run002 "
            "source files used to build the 30-image pilot. Prefer re-running "
            "--with-musiq when TF Hub is available. pyiqa packaging is PolyForm-NC "
            "(research OK); TF Hub card remains the preferred production-candidate "
            "weight source pending legal review."
        ),
        "prior_official_vs_benchmark_check": {
            "source": "official_musiq_engine_verification/metrics.json",
            "n": 24,
            "pearson_r": 0.9997477772016965,
            "spearman_r": 0.9921739130434782,
            "mean_abs_diff": 0.07349046071370442,
            "primary_equivalent_under_predeclared_0_999_spearman_bar": False,
            "note": (
                "Engines are ranking-near on the verification sample; not treated as "
                "bit-identical substitutes."
            ),
        },
    }


def score_pilot(
    *,
    with_musiq: bool,
    tfhub_cache: Path,
    limit: int | None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    images = sorted(PILOT_IMAGES.glob("PILOT-*.jpg"))
    if limit is not None:
        images = images[:limit]
    if len(images) == 0:
        raise FileNotFoundError(f"No pilot images under {PILOT_IMAGES}")

    predict_fn = None
    musiq_engine = None
    musiq_meta: dict[str, Any] = {
        "requested": with_musiq,
        "loaded": False,
        "engine": None,
        "error": None,
        "license": MUSIQ_LICENSE_NOTES,
    }
    if with_musiq:
        try:
            predict_fn, musiq_engine = load_official_musiq_predict_fn(
                tfhub_cache_dir=tfhub_cache
            )
            musiq_meta["loaded"] = True
            musiq_meta["engine"] = musiq_engine
        except Exception as exc:  # noqa: BLE001
            musiq_meta["error"] = str(exc)
            print(f"[WARN] MUSIQ unavailable: {exc}", flush=True)

    rows: list[dict[str, Any]] = []
    for path in images:
        media_id = path.stem
        print(f"[SCORE] {media_id}", flush=True)
        result = score_image_classical(path, media_id)
        if with_musiq:
            attach_musiq(result, predict_fn, musiq_engine, path)
        else:
            result.musiq_error = "MUSIQ not requested (--with-musiq omitted)"
        rows.append(result.to_flat_row())
    return rows, musiq_meta


def build_comparison(
    hybrid_rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    human_by_id = {r["media_id"]: r for r in _read_csv(HUMAN_CONSENSUS)}
    enet_by_id = {r["media_id"]: r for r in _read_csv(ENET_JOINED)}

    joined: list[dict[str, Any]] = []
    for hrow in hybrid_rows:
        mid = hrow["media_id"]
        hum = human_by_id.get(mid, {})
        enet = enet_by_id.get(mid, {})
        row = dict(hrow)
        row["human_overall_median"] = _f(hum, "overall_visual_quality_median")
        row["enet_overall_score"] = _f(enet, "overall_score")
        row["enet_quality_engine"] = enet.get("quality_engine", "")
        row["enet_opencv_fallback"] = enet.get("opencv_fallback", "")
        for c in CRITERIA:
            row[f"human_{c}_median"] = _f(hum, f"{c}_median")
            row[f"enet_{c}"] = _f(enet, c)
        joined.append(row)

    metrics: dict[str, Any] = {
        "protocol": {
            "n_images_target": 30,
            "n_images_scored": len(joined),
            "human_source": str(HUMAN_CONSENSUS),
            "enet_source": str(ENET_JOINED),
            "images_dir": str(PILOT_IMAGES),
            "resize_cap": RESIZE_CAP,
            "mapping": "equal_bin_1_5 on a priori classical q; production color badges as-is",
            "no_same_set_tuning": True,
            "pilot_prior_use": PILOT_PRIOR_USE,
        },
        "overall": {},
        "criteria_vs_human": {},
        "criteria_hybrid_vs_enet": {},
        "color_note": (
            "Human pilot sheets have no Color Balance / Color Saturation columns. "
            "Hybrid color badges are scored for inventory only; no human correlation."
        ),
    }

    # Overall OPQ
    human_ov = [r.get("human_overall_median") for r in joined]
    enet_ov = [r.get("enet_overall_score") for r in joined]
    musiq = [r.get("musiq_opq_raw") for r in joined]
    metrics["overall"]["enet_vs_human_1_5"] = _corr_block(enet_ov, human_ov, mae_ok=True)
    metrics["overall"]["musiq_raw_vs_human_1_5"] = _corr_block(musiq, human_ov, mae_ok=False)
    metrics["overall"]["musiq_raw_vs_enet_overall"] = _corr_block(musiq, enet_ov, mae_ok=False)
    metrics["overall"]["note"] = (
        "MUSIQ OPQ is ~0-100; human overall and ENET overall_score are 1-5. "
        "Report Spearman/Pearson only for MUSIQ; MAE only for ENET vs human."
    )

    for c in CRITERIA:
        hum = [r.get(f"human_{c}_median") for r in joined]
        enet = [r.get(f"enet_{c}") for r in joined]
        badge = [r.get(f"badge_{c}") for r in joined]
        lin = [r.get(f"lin_{c}") for r in joined]
        q = [r.get(f"q_{c}") for r in joined]
        metrics["criteria_vs_human"][c] = {
            "enet_badge_vs_human": _corr_block(enet, hum, mae_ok=True),
            "hybrid_equal_bin_vs_human": _corr_block(badge, hum, mae_ok=True),
            "hybrid_linear_cont_vs_human": _corr_block(lin, hum, mae_ok=True),
            "hybrid_q01_vs_human_spearman_pearson_only": _corr_block(q, hum, mae_ok=False),
        }
        metrics["criteria_hybrid_vs_enet"][c] = {
            "hybrid_equal_bin_vs_enet_badge": _corr_block(badge, enet, mae_ok=True),
        }

    # Color availability inventory
    bal_avail = sum(1 for r in joined if r.get("color_balance_available") in (True, "True", "true", 1, "1"))
    sat_avail = sum(
        1 for r in joined if r.get("color_saturation_available") in (True, "True", "true", 1, "1")
    )
    metrics["color_inventory"] = {
        "color_balance_available_n": bal_avail,
        "color_saturation_available_n": sat_avail,
        "n": len(joined),
    }
    return joined, metrics


def _fmt_r(block: dict[str, Any], key: str) -> str:
    v = block.get(key)
    if v is None:
        return "n/a"
    return f"{float(v):.3f}"


def write_report(
    out_dir: Path,
    metrics: dict[str, Any],
    musiq_meta: dict[str, Any],
    joined: list[dict[str, Any]],
) -> Path:
    lines: list[str] = []
    lines.append("# Phase 1 Research Report: Hybrid NR-IQA vs EfficientNet-B0")
    lines.append("")
    lines.append(f"**Generated (UTC):** {datetime.now(timezone.utc).isoformat()}")
    lines.append("**Status:** research only. Not enabled in production.")
    lines.append("")
    lines.append("## Verdict")
    lines.append("")

    # Compute a cautious recommendation from Spearman deltas on criteria + overall.
    wins = 0
    losses = 0
    ties = 0
    compared = 0
    for c in CRITERIA:
        hum_block = metrics["criteria_vs_human"][c]
        enet_s = hum_block["enet_badge_vs_human"].get("spearman_r")
        hyb_s = hum_block["hybrid_equal_bin_vs_human"].get("spearman_r")
        if enet_s is None or hyb_s is None:
            continue
        compared += 1
        # Prefer larger |r| with correct positive polarity (higher badge = higher human).
        if hyb_s > enet_s + 0.05:
            wins += 1
        elif enet_s > hyb_s + 0.05:
            losses += 1
        else:
            ties += 1
    musiq_s = metrics["overall"]["musiq_raw_vs_human_1_5"].get("spearman_r")
    enet_ov_s = metrics["overall"]["enet_vs_human_1_5"].get("spearman_r")

    if compared == 0:
        verdict = (
            "INCONCLUSIVE: correlations could not be computed (missing scores or "
            "zero variance). Do not proceed to production integration."
        )
        proceed = False
    elif wins > losses and (musiq_s is None or enet_ov_s is None or musiq_s >= enet_ov_s - 0.05):
        verdict = (
            "PROMISING BUT NOT PRODUCTION-READY: hybrid criterion badges beat ENET on "
            f"{wins}/{compared} criteria (Spearman margin >0.05), with {ties} near-ties "
            f"and {losses} losses. Results do **not** alone authorize production cutover."
        )
        proceed = False  # Phase 1 never auto-approves production
    elif losses > wins:
        verdict = (
            "DO NOT CLAIM SUPERIORITY: EfficientNet-B0 matched or beat the hybrid on "
            f"more criteria ({losses} losses vs {wins} wins of {compared}). Keep ENET "
            "as production quality engine; continue research only."
        )
        proceed = False
    else:
        verdict = (
            "MIXED / INCONCLUSIVE for cutover: hybrid and ENET are close on this "
            f"n=30 pilot ({wins} wins, {losses} losses, {ties} ties). Do not enable "
            "the hybrid in production on this evidence alone."
        )
        proceed = False

    lines.append(verdict)
    lines.append("")
    lines.append(
        f"**Recommendation on production integration:** "
        f"{'Do not proceed' if not proceed else 'Proceed'} to production wiring. "
        "Phase 1 requires a separate approval gate after larger holdout and licensing review."
    )
    lines.append("")
    lines.append("## 1. Goal and constraints")
    lines.append("")
    lines.append(
        "Build a research-only hybrid NR-IQA (MUSIQ OPQ + classical/OpenCV criteria) "
        "and compare retrospectively to the locked EfficientNet-B0 pilot scores without "
        "tuning and evaluating on the same samples, without modifying production."
    )
    lines.append("")
    lines.append("Unchanged by design: production API, Flutter, database, XP, rule-based "
                 "feedback, PROBE-DINOv2, WaveRep G4, authenticity thresholds, EfficientNet checkpoint.")
    lines.append("")
    lines.append("## 2. Model implementation and licenses")
    lines.append("")
    lines.append("| Component | Implementation | License / limitation |")
    lines.append("|-----------|----------------|----------------------|")
    if musiq_meta.get("live_tfhub"):
        opq_impl = (
            "Official TF Hub MUSIQ PaQ-2-PiQ SavedModel "
            f"(live inference; loaded={musiq_meta.get('loaded')})"
        )
        opq_lic = (
            "TF Hub card: Apache 2.0. GCS npz production rights **not established**. "
            "pyiqa PolyForm-NC not used for live OPQ."
        )
    else:
        opq_impl = (
            "Prior research MUSIQ PaQ-2-PiQ raw scores joined by source_media_key "
            f"(engine=`{musiq_meta.get('engine')}`; live TF Hub deferred)"
        )
        opq_lic = (
            "Preferred weight source remains TF Hub Apache-labeled SavedModel. "
            "Joined benchmark scores come from the earlier KonIQ MUSIQ research run "
            "(pyiqa packaging is PolyForm-NC: research OK, not production). "
            "GCS npz production rights **not established**."
        )
    lines.append(f"| OPQ (overall) | {opq_impl} | {opq_lic} |")
    lines.append(
        "| Sharpness / Blur / Brightness / Contrast / Blocking | "
        "`classical_quality_metrics.py` + a priori q maps (LAP_SCALE=420, "
        "brightness triangle 0.48, blocking boundary ratio) | Research code under repo; "
        "OpenCV/NumPy BSD-style dependencies |"
    )
    lines.append(
        "| Color Balance / Color Saturation | Read-only reuse of "
        "`access_backend/app/services/color_quality_criteria.py` | Same as production "
        "heuristics; heuristic estimates, not IQA-trained |"
    )
    lines.append(
        "| EfficientNet-B0 baseline | Locked pilot join only (no re-inference) | Existing "
        "production checkpoint retained; not deleted |"
    )
    lines.append("")
    lines.append("### MUSIQ license notes (verbatim research findings)")
    lines.append("")
    for k, v in MUSIQ_LICENSE_NOTES.items():
        lines.append(f"- **{k}:** {v}")
    lines.append("")
    if musiq_meta.get("error"):
        lines.append(f"**MUSIQ load error:** `{musiq_meta['error']}`")
        lines.append("")
    if musiq_meta.get("engine"):
        lines.append(f"**MUSIQ engine handle:** `{musiq_meta['engine']}`")
        lines.append("")
    if musiq_meta.get("live_tfhub") is False and musiq_meta.get("loaded"):
        lines.append("**OPQ provenance (live TF Hub deferred):**")
        lines.append("")
        if musiq_meta.get("provenance_note"):
            lines.append(musiq_meta["provenance_note"])
            lines.append("")
        prior = musiq_meta.get("prior_official_vs_benchmark_check") or {}
        if prior:
            lines.append(
                f"Prior official TF Hub vs that benchmark engine (n={prior.get('n')}): "
                f"Pearson={prior.get('pearson_r')}, Spearman={prior.get('spearman_r')}, "
                f"MAD={prior.get('mean_abs_diff')} "
                f"(primary_equivalent under 0.999 Spearman bar: "
                f"{prior.get('primary_equivalent_under_predeclared_0_999_spearman_bar')})."
            )
            lines.append("")
    lines.append(
        "Note on MAE vs Spearman: hybrid equal-bin can improve rank correlation while "
        "MAE stays similar or worse than ENET (badge offsets). Do not equate higher "
        "Spearman with better absolute 1-5 agreement."
    )
    lines.append("")

    lines.append("## 3. Test dataset and evaluation protocol")
    lines.append("")
    lines.append("| Item | Detail |")
    lines.append("|------|--------|")
    lines.append("| Images | 30 blinded photos `PILOT-001`…`PILOT-030` |")
    lines.append(f"| Image path | `{PILOT_IMAGES}` |")
    lines.append("| Human labels | 3-rater medians from locked `human_consensus_by_image.csv` |")
    lines.append("| ENET scores | Locked `machine_scores_joined.csv` (Run002 join) |")
    lines.append("| Hybrid maps | A priori equal-bin / Phase 9 scales; **not** fit on these 30 |")
    lines.append("| Resize | Longest side 1024 px, INTER_AREA, no upscale |")
    lines.append("| Same-set tuning | **Forbidden and not performed** |")
    lines.append("")
    lines.append("### Was this pilot previously used for development or calibration?")
    lines.append("")
    pu = PILOT_PRIOR_USE
    lines.append(
        f"- Used for ENET human-vs-machine **evaluation**: "
        f"**{pu['used_for_enet_human_vs_machine_evaluation']}**"
    )
    lines.append(
        f"- Used to fit ENET thresholds/weights: **{pu['used_to_fit_enet_thresholds_or_weights']}**"
    )
    lines.append(
        f"- Used to fit hybrid a priori maps: **{pu['used_to_fit_hybrid_a_priori_maps']}**"
    )
    lines.append(
        f"- Used to calibrate MUSIQ to 1–5: **{pu['used_to_calibrate_musiq_1_5']}**"
    )
    lines.append(f"- Phase 1 role: {pu['role_in_phase1']}")
    lines.append(f"- Related development sets: {pu['related_development_sets']}")
    lines.append("")
    lines.append(
        "Because the pilot was already used to **evaluate** ENET, this comparison is a "
        "transparent retrospective check for the hybrid against the same locked human "
        "medians. It is **not** an independent first look at human agreement for ENET. "
        "Hybrid parameters were not adjusted after seeing these correlations."
    )
    lines.append("")

    lines.append("## 4. Metric comparison table")
    lines.append("")
    lines.append("### 4.1 Overall perceptual quality")
    lines.append("")
    lines.append("| Pair | n | Spearman | Pearson | MAE | MAE allowed? |")
    lines.append("|------|--:|---------:|--------:|----:|:------------:|")
    for name, key in (
        ("ENET overall_score vs human overall median", "enet_vs_human_1_5"),
        ("MUSIQ raw OPQ vs human overall median", "musiq_raw_vs_human_1_5"),
        ("MUSIQ raw OPQ vs ENET overall_score", "musiq_raw_vs_enet_overall"),
    ):
        b = metrics["overall"][key]
        mae_s = "n/a" if not b.get("mae_applicable") else (
            "n/a" if b.get("mae") is None else f"{float(b['mae']):.3f}"
        )
        lines.append(
            f"| {name} | {b.get('n')} | {_fmt_r(b, 'spearman_r')} | "
            f"{_fmt_r(b, 'pearson_r')} | {mae_s} | "
            f"{'yes' if b.get('mae_applicable') else 'no'} |"
        )
    lines.append("")
    lines.append(metrics["overall"]["note"])
    lines.append("")

    lines.append("### 4.2 Criterion badges vs human medians (1–5)")
    lines.append("")
    lines.append(
        "| Criterion | ENET Spearman | Hybrid equal-bin Spearman | ENET Pearson | "
        "Hybrid Pearson | ENET MAE | Hybrid MAE | Hybrid − ENET Spearman |"
    )
    lines.append(
        "|-----------|--------------:|--------------------------:|-------------:|"
        "---------------:|---------:|-----------:|------------------------:|"
    )
    for c in CRITERIA:
        e = metrics["criteria_vs_human"][c]["enet_badge_vs_human"]
        h = metrics["criteria_vs_human"][c]["hybrid_equal_bin_vs_human"]
        es = e.get("spearman_r")
        hs = h.get("spearman_r")
        delta = "n/a" if es is None or hs is None else f"{float(hs) - float(es):+.3f}"
        e_mae = "n/a" if e.get("mae") is None else f"{float(e['mae']):.3f}"
        h_mae = "n/a" if h.get("mae") is None else f"{float(h['mae']):.3f}"
        lines.append(
            f"| {c} | {_fmt_r(e, 'spearman_r')} | {_fmt_r(h, 'spearman_r')} | "
            f"{_fmt_r(e, 'pearson_r')} | {_fmt_r(h, 'pearson_r')} | {e_mae} | {h_mae} | {delta} |"
        )
    lines.append("")
    lines.append(
        "MAE is reported because both ENET badges and hybrid equal-bin badges are on "
        "the human 1–5 scale. Continuous q∈[0,1] vs human uses Spearman/Pearson only "
        "(see `metrics.json`)."
    )
    lines.append("")
    lines.append("### 4.3 Color criteria")
    lines.append("")
    lines.append(metrics["color_note"])
    inv = metrics.get("color_inventory", {})
    lines.append(
        f"Inventory: Color Balance available on {inv.get('color_balance_available_n')}/"
        f"{inv.get('n')}; Color Saturation available on "
        f"{inv.get('color_saturation_available_n')}/{inv.get('n')}."
    )
    lines.append("")

    lines.append("## 5. Errors and limitations")
    lines.append("")
    n_err = sum(1 for r in joined if r.get("errors"))
    n_musiq_err = sum(1 for r in joined if r.get("musiq_error"))
    lines.append(f"- Classical/color scoring errors: **{n_err}** / {len(joined)} images.")
    lines.append(f"- MUSIQ per-image errors / skips: **{n_musiq_err}** / {len(joined)} "
                 "(includes 'not requested' if `--with-musiq` omitted).")
    lines.append("- n=30 is small; Spearman CIs are wide; do not over-interpret single-criterion flips.")
    lines.append(
        "- Sharpness and Blur share one Laplacian quality axis (Phase 9 duplication). "
        "They are not independent evidence."
    )
    lines.append(
        "- Human pilot has no color-balance / saturation ratings; those hybrid heads "
        "cannot be validated here."
    )
    lines.append(
        "- Pilot was previously used to evaluate ENET; ENET agreement figures are "
        "retrospective repeats, not a fresh holdout for ENET."
    )
    lines.append(
        "- No frozen MUSIQ→1–5 calibration was applied; therefore MAE(MUSIQ, human) "
        "is intentionally omitted."
    )
    lines.append(
        "- TF Hub Apache label does not clear GCS npz production licensing; commercial "
        "integration needs a separate legal/product decision."
    )
    lines.append(
        "- Classical maps can still emit compressed badge histograms; equal-bin fixes "
        "reachability of 1/5 relative to `_soft_score` but is not perceptual calibration."
    )
    lines.append("")

    lines.append("## 6. Files")
    lines.append("")
    lines.append(f"- Output directory: `{out_dir}`")
    lines.append("- `hybrid_per_image.csv` — hybrid scores per pilot image")
    lines.append("- `comparison_joined.csv` — hybrid + human + locked ENET")
    lines.append("- `metrics.json` — full correlation blocks")
    lines.append("- `musiq_meta.json` — engine load + license notes")
    lines.append("- `PHASE1_HYBRID_NR_IQA_RESEARCH_REPORT.md` — this report")
    lines.append("")
    lines.append("## 7. Production integration recommendation")
    lines.append("")
    lines.append(
        "**Do not enable the hybrid evaluator in production.** Keep EfficientNet-B0 "
        "as the live quality engine. Next research steps (only after approval): larger "
        "ACCESS-native holdout disjoint from this pilot, optional frozen MUSIQ 1–5 "
        "calibration on a non-pilot set, licensing sign-off for TF Hub weights in "
        "deployment, and a Phase 2 design for API dual-run shadow scoring."
    )
    lines.append("")

    path = out_dir / "PHASE1_HYBRID_NR_IQA_RESEARCH_REPORT.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--with-musiq",
        action="store_true",
        help="Load official TF Hub MUSIQ (requires TensorFlow research venv)",
    )
    ap.add_argument("--tfhub-cache", type=Path, default=DEFAULT_TFHUB_CACHE)
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output directory (default: workspace/human_pilot/output/phase1_hybrid_*)",
    )
    ap.add_argument(
        "--reuse-classical-csv",
        type=Path,
        default=None,
        help="Reuse an existing hybrid_per_image.csv and only (re)score MUSIQ OPQ",
    )
    ap.add_argument(
        "--musiq-from-benchmark-csv",
        type=Path,
        nargs="?",
        const=DEFAULT_MUSIQ_BENCHMARK_CSV,
        default=None,
        help=(
            "Join prior research MUSIQ PaQ-2-PiQ raw scores by source_media_key "
            "(default CSV: koniq10k/musiq_paq2piq_benchmark/raw_predictions.csv). "
            "Use when live TF Hub is unavailable."
        ),
    )
    args = ap.parse_args()

    out_dir = args.output or (
        _TOOLKIT
        / "workspace"
        / "human_pilot"
        / "output"
        / f"phase1_hybrid_nr_iqa_{_now_stamp()}"
    )
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[PHASE1] images={PILOT_IMAGES}", flush=True)
    print(f"[PHASE1] output={out_dir}", flush=True)
    print(f"[PHASE1] with_musiq={args.with_musiq}", flush=True)

    if args.reuse_classical_csv is not None:
        hybrid_rows = _read_csv(args.reuse_classical_csv)
        # normalize numeric fields that were stringified
        for row in hybrid_rows:
            for k, v in list(row.items()):
                if k in ("media_id", "path", "musiq_engine", "musiq_error", "errors"):
                    continue
                if v == "" or v is None:
                    row[k] = None
                    continue
                if isinstance(v, str) and v.lower() in ("true", "false"):
                    row[k] = v.lower() == "true"
                    continue
                try:
                    row[k] = float(v) if ("." in v or "e" in v.lower()) else int(v)
                except (ValueError, AttributeError):
                    pass
        musiq_meta = {
            "requested": args.with_musiq,
            "loaded": False,
            "engine": None,
            "error": None,
            "license": MUSIQ_LICENSE_NOTES,
            "reused_classical_csv": str(args.reuse_classical_csv),
        }
        if args.with_musiq:
            try:
                predict_fn, musiq_engine = load_official_musiq_predict_fn(
                    tfhub_cache_dir=args.tfhub_cache
                )
                musiq_meta["loaded"] = True
                musiq_meta["engine"] = musiq_engine
                musiq_meta["live_tfhub"] = True
                for row in hybrid_rows:
                    mid = row["media_id"]
                    path = Path(str(row.get("path") or (PILOT_IMAGES / f"{mid}.jpg")))
                    print(f"[MUSIQ] {mid}", flush=True)
                    try:
                        row["musiq_opq_raw"] = score_jpeg_musiq(predict_fn, path)
                        row["musiq_engine"] = musiq_engine
                        row["musiq_error"] = None
                    except Exception as exc:  # noqa: BLE001
                        row["musiq_opq_raw"] = None
                        row["musiq_engine"] = musiq_engine
                        row["musiq_error"] = str(exc)
            except Exception as exc:  # noqa: BLE001
                musiq_meta["error"] = str(exc)
                print(f"[WARN] MUSIQ unavailable: {exc}", flush=True)
        elif args.musiq_from_benchmark_csv is not None:
            musiq_meta = attach_musiq_from_benchmark_csv(
                hybrid_rows, Path(args.musiq_from_benchmark_csv)
            )
            musiq_meta["reused_classical_csv"] = str(args.reuse_classical_csv)
        else:
            musiq_meta["error"] = "MUSIQ not requested"
    else:
        hybrid_rows, musiq_meta = score_pilot(
            with_musiq=args.with_musiq,
            tfhub_cache=args.tfhub_cache,
            limit=args.limit,
        )
        if (
            not musiq_meta.get("loaded")
            and args.musiq_from_benchmark_csv is not None
            and not args.with_musiq
        ):
            musiq_meta = attach_musiq_from_benchmark_csv(
                hybrid_rows, Path(args.musiq_from_benchmark_csv)
            )
    _write_csv(out_dir / "hybrid_per_image.csv", hybrid_rows)
    joined, metrics = build_comparison(hybrid_rows)
    _write_csv(out_dir / "comparison_joined.csv", joined)
    (out_dir / "metrics.json").write_text(
        json.dumps(metrics, indent=2, default=str), encoding="utf-8"
    )
    (out_dir / "musiq_meta.json").write_text(
        json.dumps(musiq_meta, indent=2, default=str), encoding="utf-8"
    )
    report = write_report(out_dir, metrics, musiq_meta, joined)
    print(f"[PHASE1] report={report}", flush=True)
    print(f"[PHASE1] musiq_loaded={musiq_meta.get('loaded')}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
