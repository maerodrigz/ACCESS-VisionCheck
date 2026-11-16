#!/usr/bin/env python3
"""Analyze Phase 4A independent validation results AFTER human sheets are filed.

Refuses to invent human scores. Exits with a clear message if ratings are missing.
Separates image-quality metrics from feedback-generation metrics.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from metrics import fleiss_kappa, mae_rmse, pearson_spearman, quadratic_weighted_kappa  # noqa: E402
from phase4a_issue_taxonomy import (  # noqa: E402
    ISSUE_CLASSES,
    ISSUE_SEVERITIES_COUNTED,
    RULE_CRITERION_TO_ISSUE,
)

DEFAULT_ROOT = _TOOLKIT / "workspace" / "phase4a_indval"
RATERS = ("R1", "R2", "R3")
IQ_CRITERIA = (
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "color_balance",
    "color_saturation",
    "overall_visual_quality",
)


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _f(v: str | None) -> float | None:
    if v is None or v == "" or str(v).upper() == "N/A":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def _median(vals: list[float]) -> float | None:
    if not vals:
        return None
    s = sorted(vals)
    n = len(s)
    mid = n // 2
    if n % 2:
        return s[mid]
    return 0.5 * (s[mid - 1] + s[mid])


def _require_human_sheets(pack_dir: Path) -> None:
    missing = []
    for r in RATERS:
        for stem in (
            f"image_quality_ratings_{r}.csv",
            f"issue_labels_{r}.csv",
            f"feedback_quality_ratings_{r}.csv",
        ):
            p = pack_dir / stem
            if not p.is_file():
                missing.append(str(p))
                continue
            rows = _read_csv(p)
            # image quality: require at least one non-empty sharpness
            if "image_quality" in stem:
                filled = sum(1 for row in rows if (row.get("sharpness") or "").strip())
                if filled == 0:
                    missing.append(f"{p} (no sharpness ratings filled)")
            if "issue_labels" in stem:
                filled = sum(
                    1
                    for row in rows
                    if any((row.get(c) or "").strip() for c in ISSUE_CLASSES)
                )
                if filled == 0:
                    missing.append(f"{p} (no issue labels filled)")
            if "feedback_quality" in stem:
                filled = sum(
                    1
                    for row in rows
                    if (row.get("observation_correctness_1to5") or "").strip()
                )
                if filled == 0:
                    missing.append(f"{p} (no feedback quality ratings filled)")
    if missing:
        raise SystemExit(
            "Phase 4A analysis aborted: human evaluations are incomplete or missing.\n"
            "This script does not fabricate ratings.\n"
            "Missing/empty:\n- " + "\n- ".join(missing)
        )


def _consensus_image_quality(pack_dir: Path) -> dict[str, dict[str, float | None]]:
    by_media: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    for r in RATERS:
        for row in _read_csv(pack_dir / f"image_quality_ratings_{r}.csv"):
            mid = row["media_id"]
            for c in IQ_CRITERIA:
                v = _f(row.get(c))
                if v is not None:
                    by_media[mid][c].append(v)
    out: dict[str, dict[str, float | None]] = {}
    for mid, crits in by_media.items():
        out[mid] = {c: _median(vals) for c, vals in crits.items()}
        out[mid]["n_raters_sharpness"] = float(len(crits.get("sharpness", [])))
    return out


def _interrater_iq(pack_dir: Path) -> dict[str, Any]:
    # Pairwise QWK per criterion + Fleiss on sharpness matrix
    matrices: dict[str, list[list[float]]] = {c: [] for c in IQ_CRITERIA}
    ids = None
    rater_maps: dict[str, dict[str, dict[str, float | None]]] = {}
    for r in RATERS:
        m: dict[str, dict[str, float | None]] = {}
        for row in _read_csv(pack_dir / f"image_quality_ratings_{r}.csv"):
            m[row["media_id"]] = {c: _f(row.get(c)) for c in IQ_CRITERIA}
        rater_maps[r] = m
        if ids is None:
            ids = sorted(m.keys())
    assert ids is not None
    pairwise: dict[str, Any] = {}
    for c in IQ_CRITERIA:
        pairs = {}
        for a, b in (("R1", "R2"), ("R1", "R3"), ("R2", "R3")):
            xa = []
            xb = []
            for mid in ids:
                va = rater_maps[a].get(mid, {}).get(c)
                vb = rater_maps[b].get(mid, {}).get(c)
                if va is None or vb is None:
                    continue
                xa.append(int(round(va)))
                xb.append(int(round(vb)))
            pairs[f"{a}_vs_{b}"] = {
                "qwk": quadratic_weighted_kappa(xa, xb),
                "n": len(xa),
            }
        pairwise[c] = pairs
        # Fleiss matrix
        mat = []
        for mid in ids:
            row = []
            for r in RATERS:
                v = rater_maps[r].get(mid, {}).get(c)
                row.append(float("nan") if v is None else float(v))
            mat.append(row)
        import numpy as np

        pairwise[c]["fleiss_kappa"] = fleiss_kappa(np.asarray(mat, dtype=float))
    return pairwise


def _iq_correlations(
    consensus: dict[str, dict[str, float | None]],
    machine_rows: list[dict[str, str]],
) -> dict[str, Any]:
    by_id = {r["indval_id"]: r for r in machine_rows}
    out: dict[str, Any] = {"image_quality_validation": {}, "note": "MAE only on 1-5 compatible pairs"}
    for c in IQ_CRITERIA:
        if c == "overall_visual_quality":
            human = [consensus[mid].get(c) for mid in consensus]
            enet = [_f(by_id.get(mid, {}).get("enet_overall_score")) for mid in consensus]
            musiq = [_f(by_id.get(mid, {}).get("musiq_opq_raw")) for mid in consensus]
            hybrid_proxy = None  # no single hybrid overall from criteria mean unless computed
            block = {
                "enet_vs_human": {**pearson_spearman(
                    [x for x, y in zip(enet, human) if x is not None and y is not None],
                    [y for x, y in zip(enet, human) if x is not None and y is not None],
                ), **mae_rmse(
                    [x for x, y in zip(enet, human) if x is not None and y is not None],
                    [y for x, y in zip(enet, human) if x is not None and y is not None],
                ), "mae_applicable": True},
                "musiq_raw_vs_human": {
                    **pearson_spearman(
                        [x for x, y in zip(musiq, human) if x is not None and y is not None],
                        [y for x, y in zip(musiq, human) if x is not None and y is not None],
                    ),
                    "mae": None,
                    "mae_applicable": False,
                    "mae_note": "MUSIQ ~0-100 vs human 1-5",
                },
            }
            out["image_quality_validation"][c] = block
            continue
        human = []
        hybrid_badge = []
        enet = []
        for mid, cons in consensus.items():
            h = cons.get(c)
            mrow = by_id.get(mid, {})
            hb = _f(mrow.get(f"hybrid_badge_{c}"))
            # enet field naming
            ename = c if c != "blocking_artifacts" else "blocking_artifacts"
            ev = _f(mrow.get(f"enet_{ename}"))
            if h is None:
                continue
            human.append(h)
            hybrid_badge.append(hb)
            enet.append(ev)
        # filter pairs
        def _pairs(a, b):
            xa, ya = [], []
            for x, y in zip(a, b):
                if x is None or y is None:
                    continue
                xa.append(x)
                ya.append(y)
            return xa, ya

        hb_h = _pairs(hybrid_badge, human)
        en_h = _pairs(enet, human)
        out["image_quality_validation"][c] = {
            "hybrid_equal_bin_vs_human": {
                **pearson_spearman(*hb_h),
                **mae_rmse(*hb_h),
                "mae_applicable": True,
            },
            "enet_badge_vs_human": {
                **pearson_spearman(*en_h),
                **mae_rmse(*en_h),
                "mae_applicable": True,
            },
        }
    return out


def _yn(v: str | None) -> bool | None:
    if v is None or v.strip() == "":
        return None
    s = v.strip().upper()
    if s in ("Y", "YES", "1", "TRUE"):
        return True
    if s in ("N", "NO", "0", "FALSE"):
        return False
    return None


def _feedback_prf(
    pack_dir: Path,
    feedback_obs: list[dict[str, str]],
    *,
    include_mild: bool = True,
) -> dict[str, Any]:
    # Human reference: majority Y across raters per image/class
    votes: dict[str, dict[str, list[bool]]] = defaultdict(lambda: defaultdict(list))
    for r in RATERS:
        for row in _read_csv(pack_dir / f"issue_labels_{r}.csv"):
            mid = row["media_id"]
            for c in ISSUE_CLASSES:
                yn = _yn(row.get(c))
                if yn is not None:
                    votes[mid][c].append(yn)

    ref: dict[str, set[str]] = {}
    for mid, classes in votes.items():
        present = set()
        for c, ys in classes.items():
            if not ys:
                continue
            if sum(1 for y in ys if y) > len(ys) / 2:
                present.add(c)
        ref[mid] = present

    pred: dict[str, set[str]] = defaultdict(set)
    for row in feedback_obs:
        if row.get("observation_kind") != "issue":
            continue
        if row.get("suppressed") in ("True", "true", "1"):
            continue
        sev = (row.get("severity") or "").strip()
        if not include_mild and sev == "mild":
            continue
        if sev and sev not in ISSUE_SEVERITIES_COUNTED and sev != "":
            continue
        crit = row.get("criterion", "")
        issue = RULE_CRITERION_TO_ISSUE.get(crit)
        if issue:
            pred[row["indval_id"]].add(issue)

    tp = fp = fn = 0
    for mid in set(ref) | set(pred):
        rset = ref.get(mid, set())
        pset = pred.get(mid, set())
        tp += len(rset & pset)
        fp += len(pset - rset)
        fn += len(rset - pset)
    precision = tp / (tp + fp) if (tp + fp) else None
    recall = tp / (tp + fn) if (tp + fn) else None
    if precision is None or recall is None or (precision + recall) == 0:
        f1 = None
    else:
        f1 = 2 * precision * recall / (precision + recall)
    return {
        "include_mild": include_mild,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "n_images_with_ref": len(ref),
    }


def _feedback_likert(pack_dir: Path) -> dict[str, Any]:
    vals = {
        "observation_correctness_1to5": [],
        "recommendation_relevance_1to5": [],
        "clarity_1to5": [],
        "usefulness_1to5": [],
    }
    for r in RATERS:
        for row in _read_csv(pack_dir / f"feedback_quality_ratings_{r}.csv"):
            for k in vals:
                v = _f(row.get(k))
                if v is not None:
                    vals[k].append(v)
    summary = {}
    for k, arr in vals.items():
        summary[k] = {
            "n": len(arr),
            "mean": (sum(arr) / len(arr)) if arr else None,
            "note": "Feedback-quality Likert; not image-quality MOS",
        }
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--allow-empty", action="store_true", help="Dev only: skip human completeness gate")
    args = ap.parse_args()

    pack = args.root / "human_packs"
    machine_csv = args.root / "machine_output" / "machine_scores.csv"
    feedback_csv = args.root / "machine_output" / "experimental_feedback_observations.csv"
    out_dir = args.root / "analysis"
    out_dir.mkdir(parents=True, exist_ok=True)

    if not args.allow_empty:
        _require_human_sheets(pack)
    elif not (pack / "image_quality_ratings_R1.csv").is_file():
        raise SystemExit("human packs not prepared; run prepare_phase4a_human_packs.py")

    if not machine_csv.is_file():
        raise SystemExit(f"Missing machine scores: {machine_csv}")

    machine_rows = _read_csv(machine_csv)
    feedback_obs = _read_csv(feedback_csv) if feedback_csv.is_file() else []

    report: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "COMPLETE" if not args.allow_empty else "DEV_PARTIAL_NO_HUMAN_GATE",
        "human_scores_fabricated": False,
        "sections": {},
    }

    if not args.allow_empty:
        consensus = _consensus_image_quality(pack)
        report["sections"]["inter_rater_image_quality"] = _interrater_iq(pack)
        report["sections"]["image_quality_vs_machines"] = _iq_correlations(consensus, machine_rows)
        report["sections"]["feedback_issue_prf_include_mild"] = _feedback_prf(
            pack, feedback_obs, include_mild=True
        )
        report["sections"]["feedback_issue_prf_exclude_mild"] = _feedback_prf(
            pack, feedback_obs, include_mild=False
        )
        report["sections"]["feedback_quality_likert"] = _feedback_likert(pack)
    else:
        report["sections"]["note"] = (
            "Human gate skipped. No accuracy claims. Machine-only inventory below."
        )
        report["sections"]["machine_inventory"] = {
            "n": len(machine_rows),
            "musiq_ok": sum(1 for r in machine_rows if r.get("musiq_status") == "ok"),
            "musiq_unavailable": sum(
                1 for r in machine_rows if r.get("musiq_status") == "unavailable"
            ),
        }

    (out_dir / "phase4a_analysis.json").write_text(
        json.dumps(report, indent=2, default=str), encoding="utf-8"
    )

    # Chapter 4 markdown stub filled only with real numbers when present
    md = []
    md.append("# Phase 4A Independent Validation Analysis")
    md.append("")
    md.append(f"Generated: {report['generated_at_utc']}")
    md.append(f"Status: **{report['status']}**")
    md.append("")
    md.append("Human scores fabricated: **false**")
    md.append("")
    if args.allow_empty:
        md.append(
            "Human ratings are not yet available. Do not report accuracy figures in Chapter 4."
        )
    else:
        md.append("## Image-quality validation")
        md.append("")
        md.append("See `phase4a_analysis.json` → `image_quality_vs_machines` and `inter_rater_image_quality`.")
        md.append("")
        md.append("## Feedback-generation validation")
        md.append("")
        prf = report["sections"]["feedback_issue_prf_include_mild"]
        md.append(
            f"Issue-level (include mild): P={prf.get('precision')} R={prf.get('recall')} F1={prf.get('f1')}"
        )
        md.append("")
        md.append("Likert feedback-quality means: see JSON `feedback_quality_likert`.")
    md.append("")
    md.append("## Separation of concerns")
    md.append("")
    md.append("- Image-quality: Spearman/Pearson/MAE vs human criterion medians.")
    md.append("- Feedback: issue P/R/F1 + feedback-quality Likert (not image MOS).")
    (out_dir / "PHASE4A_ANALYSIS_REPORT.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"[PHASE4A] analysis -> {out_dir}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
