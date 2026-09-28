"""
Step 3: Offline PROBE policy analysis from Step 8C.2 CSV (no inference).

Usage:
  cd access_backend
  python scripts/analyze_probe_policy_step3.py
"""

from __future__ import annotations

import csv
import json
import statistics
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
INPUT_CSV = ROOT / "evaluation_results" / "step8c2" / "20260927_232306" / "step8c2_1344_results.csv"

THRESHOLDS = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.60, 0.70, 0.80, 0.90]
GENERATORS = ("chatgpt", "gemini", "canva", "pixlr")


def percentile(vals: list[float], p: float) -> float:
    if not vals:
        return float("nan")
    s = sorted(vals)
    if len(s) == 1:
        return s[0]
    idx = (len(s) - 1) * p
    lo = int(idx)
    hi = min(lo + 1, len(s) - 1)
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def dist_stats(vals: list[float]) -> dict[str, float]:
    return {
        "min": min(vals),
        "p10": percentile(vals, 0.10),
        "p25": percentile(vals, 0.25),
        "median": percentile(vals, 0.50),
        "p75": percentile(vals, 0.75),
        "p90": percentile(vals, 0.90),
        "p95": percentile(vals, 0.95),
        "max": max(vals),
    }


def confusion_at_threshold(rows: list[dict], t: float) -> dict[str, float]:
    tp = tn = fp = fn = 0
    for r in rows:
        p = float(r["capped_probability"])
        pred_ai = p >= t
        is_ai = r["ground_truth"] == "AI"
        if is_ai and pred_ai:
            tp += 1
        elif not is_ai and not pred_ai:
            tn += 1
        elif not is_ai and pred_ai:
            fp += 1
        else:
            fn += 1
    n = len(rows)
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    spec = tn / (tn + fp) if (tn + fp) else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    fnr = fn / (fn + tp) if (fn + tp) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    bal_acc = (rec + spec) / 2.0
    return {
        "threshold": t,
        "TP": tp,
        "TN": tn,
        "FP": fp,
        "FN": fn,
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "specificity": round(spec, 4),
        "FPR": round(fpr, 4),
        "FNR": round(fnr, 4),
        "F1": round(f1, 4),
        "balanced_accuracy": round(bal_acc, 4),
    }


def policy_counts(rows: list[dict], low: float, high: float) -> dict[str, Any]:
    buckets = {"low_risk": 0, "review": 0, "high_risk": 0}
    real_fp_high = real_fp_review = 0
    ai_high = ai_review = ai_low = 0
    for r in rows:
        p = float(r["capped_probability"])
        gt = r["ground_truth"]
        if p < low:
            buckets["low_risk"] += 1
            if gt == "AI":
                ai_low += 1
        elif p < high:
            buckets["review"] += 1
            if gt == "REAL":
                real_fp_review += 1
            else:
                ai_review += 1
        else:
            buckets["high_risk"] += 1
            if gt == "REAL":
                real_fp_high += 1
            else:
                ai_high += 1
    return {
        "LOW": low,
        "HIGH": high,
        "low_risk_n": buckets["low_risk"],
        "review_n": buckets["review"],
        "high_risk_n": buckets["high_risk"],
        "REAL_flagged_high": real_fp_high,
        "REAL_in_review_band": real_fp_review,
        "AI_high_risk": ai_high,
        "AI_review": ai_review,
        "AI_low_risk": ai_low,
        "REAL_total_false_high": real_fp_high,
        "REAL_total_in_review_or_high": real_fp_high + real_fp_review,
    }


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def main() -> None:
    if not INPUT_CSV.is_file():
        raise SystemExit(f"BLOCKED: missing {INPUT_CSV}")

    with INPUT_CSV.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))

    errors = [r for r in rows if (r.get("error") or "").strip()]
    probs_missing = [r for r in rows if r.get("capped_probability") in (None, "")]
    real_n = sum(1 for r in rows if r["ground_truth"] == "REAL")
    ai_n = sum(1 for r in rows if r["ground_truth"] == "AI")
    ok = len(rows) == 100 and real_n == 50 and ai_n == 50 and not errors and not probs_missing
    if not ok:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        out = ROOT / "evaluation_results" / "step9_probe_policy" / stamp
        out.mkdir(parents=True, exist_ok=True)
        (out / "probe_policy_summary.json").write_text(
            json.dumps({"step3_status": "BLOCKED", "rows": len(rows), "errors": len(errors)}, indent=2),
            encoding="utf-8",
        )
        raise SystemExit("BLOCKED input verification")

    real_p = [float(r["capped_probability"]) for r in rows if r["ground_truth"] == "REAL"]
    ai_p = [float(r["capped_probability"]) for r in rows if r["ground_truth"] == "AI"]

    overlap = {
        "real_max": max(real_p),
        "ai_min": min(ai_p),
        "scores_overlap": max(real_p) >= min(ai_p),
        "real_above_ai_median_count": sum(1 for x in real_p if x > percentile(ai_p, 0.5)),
        "ai_below_real_median_count": sum(1 for x in ai_p if x < percentile(real_p, 0.5)),
    }

    threshold_rows = [confusion_at_threshold(rows, t) for t in THRESHOLDS]

    candidates: list[dict] = []
    for low in [0.05, 0.10, 0.15, 0.20, 0.25, 0.30]:
        for high in [0.35, 0.40, 0.45, 0.50, 0.60, 0.70, 0.80]:
            if high <= low:
                continue
            c = policy_counts(rows, low, high)
            c["score"] = (
                c["REAL_total_false_high"] * 5
                + c["REAL_in_review_band"] * 1
                - c["AI_high_risk"] * 2
                - c["AI_review"] * 0.5
            )
            candidates.append(c)
    candidates.sort(key=lambda x: (x["REAL_total_false_high"], x["REAL_in_review_band"], -x["AI_high_risk"]))

    picked = candidates[:8]
    best = candidates[0] if candidates else None
    # Prefer balanced: zero REAL high flags if possible with some AI catch
    for c in candidates:
        if c["REAL_total_false_high"] == 0 and (c["AI_high_risk"] + c["AI_review"]) >= 20:
            best = c
            break

    low_c, high_c = (best["LOW"], best["HIGH"]) if best else (0.15, 0.45)

    gen_policy_rows = []
    for label, filt in [
        ("chatgpt", lambda r: r["source"] == "chatgpt"),
        ("gemini", lambda r: r["source"] == "gemini"),
        ("canva", lambda r: r["source"] == "canva"),
        ("pixlr", lambda r: r["source"] == "pixlr"),
        ("REAL", lambda r: r["ground_truth"] == "REAL"),
    ]:
        sub = [r for r in rows if filt(r)]
        for t in [low_c, high_c, 0.50]:
            m = confusion_at_threshold(sub, t)
            gen_policy_rows.append(
                {
                    "group": label,
                    "n": len(sub),
                    "threshold": t,
                    "TP": m["TP"],
                    "FP": m["FP"],
                    "FN": m["FN"],
                    "recall": m["recall"],
                    "FPR": m["FPR"],
                }
            )
        pc = policy_counts(sub, low_c, high_c)
        gen_policy_rows.append(
            {
                "group": label,
                "n": len(sub),
                "policy": f"LOW={low_c}_HIGH={high_c}",
                "low_risk_n": pc["low_risk_n"],
                "review_n": pc["review_n"],
                "high_risk_n": pc["high_risk_n"],
                "REAL_or_AI_high": pc.get("REAL_flagged_high") or pc.get("AI_high_risk"),
            }
        )

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step9_probe_policy" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    write_csv(out_dir / "probe_threshold_table.csv", threshold_rows, list(threshold_rows[0].keys()))
    write_csv(
        out_dir / "probe_policy_candidates.csv",
        picked,
        [
            "LOW",
            "HIGH",
            "low_risk_n",
            "review_n",
            "high_risk_n",
            "REAL_flagged_high",
            "REAL_in_review_band",
            "AI_high_risk",
            "AI_review",
            "AI_low_risk",
            "REAL_total_false_high",
            "REAL_total_in_review_or_high",
            "score",
        ],
    )
    write_csv(out_dir / "probe_generator_policy.csv", gen_policy_rows, list(gen_policy_rows[0].keys()))

    summary = {
        "step3_status": "COMPLETE",
        "input_csv": str(INPUT_CSV),
        "input_verified": {
            "rows": 100,
            "real": 50,
            "ai": 50,
            "errors": 0,
            "probability_column": "capped_probability",
        },
        "score_distributions": {"REAL": dist_stats(real_p), "AI": dist_stats(ai_p), "overlap": overlap},
        "threshold_table": threshold_rows,
        "validation_set_candidate_policy": {
            "LOW": low_c,
            "HIGH": high_c,
            "note": "VALIDATION-SET CANDIDATE — not production-validated",
            "policy_counts_on_n100": policy_counts(rows, low_c, high_c),
        },
        "top_policy_candidates": picked,
        "fusion_replay_possible": False,
        "fusion_replay_reason": (
            "step8c2_1344_results.csv stores capped_probability only; "
            "OpenCV/metadata/filename heuristic signals are not persisted per row."
        ),
        "production_behavior_changed": False,
        "output_dir": str(out_dir),
    }
    (out_dir / "probe_policy_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    report = [
        "STEP 3 STATUS: COMPLETE",
        f"Input: {INPUT_CSV}",
        f"Candidate LOW/HIGH (validation only): {low_c} / {high_c}",
        "PRODUCTION BEHAVIOR CHANGED: NO",
        f"Output: {out_dir}",
    ]
    (out_dir / "probe_policy_report.txt").write_text("\n".join(report), encoding="utf-8")
    print(out_dir)


if __name__ == "__main__":
    main()
