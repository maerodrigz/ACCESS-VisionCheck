#!/usr/bin/env python3
"""Stdlib-only INDVAL Phase 6B locked-rating analysis (no scipy/matplotlib).

Uses on-disk exports:
  phase6b_R2_locked_ratings.csv.csv
  phase6b_R3_locked_ratings.csv.csv
"""

from __future__ import annotations

import csv
import json
import math
import statistics
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent / "workspace" / "phase4a_indval"
R2_PATH = ROOT / "phase6b_R2_locked_ratings.csv.csv"
R3_PATH = ROOT / "phase6b_R3_locked_ratings.csv.csv"
OPENCV_PATH = ROOT / "machine_output" / "machine_scores.csv"
MUSIQ_PATH = (
    ROOT / "machine_output" / "musiq_live_docker_20261114T074630Z" / "musiq_live_scores.csv"
)
COMBINED_OUT = ROOT / "phase6b_locked_ratings.csv"
OUT = ROOT / "phase6b_statistical_analysis"

CRITERIA = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
    "overall_visual_quality",
)
OPENCV_PAIRS = (
    ("sharpness", "hybrid_badge_sharpness", "hybrid_q_sharpness"),
    ("blur", "hybrid_badge_blur", "hybrid_q_blur"),
    ("brightness", "hybrid_badge_brightness", "hybrid_q_brightness"),
    ("contrast", "hybrid_badge_contrast", "hybrid_q_contrast"),
    ("blocking_artifacts", "hybrid_badge_blocking_artifacts", "hybrid_q_blocking_artifacts"),
)
EXPECTED = [f"INDVAL-{i:03d}" for i in range(1, 101)]


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    cols: list[str] = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in cols})


def parse_score(v: Any) -> float | str:
    if isinstance(v, bool):
        raise ValueError(v)
    if isinstance(v, (int, float)):
        fv = float(v)
        if fv == int(fv) and 1 <= int(fv) <= 5:
            return float(int(fv))
        raise ValueError(v)
    s = str(v).strip()
    if s.upper() == "N/A":
        return "N/A"
    fv = float(s)
    if fv == int(fv) and 1 <= int(fv) <= 5:
        return float(int(fv))
    raise ValueError(v)


def validate(path: Path, expected_eid: str) -> dict[str, dict[str, Any]]:
    rows = read_csv(path)
    if len(rows) != 100:
        raise SystemExit(f"{path.name}: expected 100 rows, got {len(rows)}")
    out: dict[str, dict[str, Any]] = {}
    for i, row in enumerate(rows, start=2):
        eid = row["evaluator_id"].strip()
        mid = row["media_id"].strip()
        st = row["status"].strip().lower()
        if eid != expected_eid:
            raise SystemExit(f"{path.name}:{i} bad evaluator {eid}")
        if st != "locked":
            raise SystemExit(f"{path.name}:{i} {mid} status={st}")
        rj = json.loads(row["ratings_json"])
        scores = {}
        n_num = 0
        for c in CRITERIA:
            if c not in rj:
                raise SystemExit(f"{path.name}:{i} {mid} missing {c}")
            scores[c] = parse_score(rj[c])
            if isinstance(scores[c], float):
                n_num += 1
        if n_num == 0:
            raise SystemExit(f"{path.name}:{i} {mid} no numeric scores")
        if mid in out:
            raise SystemExit(f"{path.name}: duplicate {mid}")
        out[mid] = {
            "evaluator_id": eid,
            "media_id": mid,
            "status": "locked",
            "ratings_json": json.dumps(
                {c: (int(scores[c]) if isinstance(scores[c], float) else scores[c]) for c in CRITERIA},
                separators=(",", ":"),
            ),
            **{c: scores[c] for c in CRITERIA},
            "n_numeric_criteria": n_num,
            "source_file": path.name,
        }
    if set(out) != set(EXPECTED):
        raise SystemExit(f"{path.name}: ID set mismatch")
    return out


def rankdata(xs: list[float]) -> list[float]:
    n = len(xs)
    order = sorted(range(n), key=lambda i: xs[i])
    ranks = [0.0] * n
    i = 0
    while i < n:
        j = i
        while j + 1 < n and xs[order[j + 1]] == xs[order[i]]:
            j += 1
        avg = 0.5 * (i + j) + 1.0
        for k in range(i, j + 1):
            ranks[order[k]] = avg
        i = j + 1
    return ranks


def pearson(xs: list[float], ys: list[float]) -> tuple[float | None, float | None]:
    n = len(xs)
    if n < 3:
        return None, None
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    dy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if dx == 0 or dy == 0:
        return None, None
    r = num / (dx * dy)
    # two-sided p via t approx
    if abs(r) >= 1:
        return float(r), 0.0
    t = r * math.sqrt((n - 2) / (1 - r * r))
    # survival function approximation for Student-t (df=n-2) via normal for large n
    # Use incomplete beta / regularized — simple erfc normal approx when df large
    df = n - 2
    # Abramowitz-like: convert t to p with regularized incomplete beta simplified via scipy-free
    # For research tables we use scipy-equivalent when available; here use t->p via continued fraction
    p = student_t_sf_two_sided(abs(t), df)
    return float(r), p


def student_t_sf_two_sided(t: float, df: int) -> float:
    # Regularized incomplete beta relation: p = I_{df/(df+t^2)}(df/2, 1/2)
    x = df / (df + t * t)
    a = df / 2.0
    b = 0.5
    # Continued fraction for incomplete beta (Numerical Recipes style, abbreviated)
    bt = math.exp(
        math.lgamma(a + b)
        - math.lgamma(a)
        - math.lgamma(b)
        + a * math.log(x)
        + b * math.log(1 - x)
    )
    if x < (a + 1) / (a + b + 2):
        return min(1.0, max(0.0, bt * betacf(a, b, x) / a))
    return min(1.0, max(0.0, 1.0 - bt * betacf(b, a, 1 - x) / b))


def betacf(a: float, b: float, x: float, max_it: int = 200) -> float:
    fpmin = 1e-30
    qab = a + b
    qap = a + 1
    qam = a - 1
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < fpmin:
        d = fpmin
    d = 1.0 / d
    h = d
    for m in range(1, max_it + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < fpmin:
            d = fpmin
        c = 1.0 + aa / c
        if abs(c) < fpmin:
            c = fpmin
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < fpmin:
            d = fpmin
        c = 1.0 + aa / c
        if abs(c) < fpmin:
            c = fpmin
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < 3e-7:
            break
    return h


def spearman(xs: list[float], ys: list[float]) -> tuple[float | None, float | None, int]:
    if len(xs) != len(ys) or len(xs) < 3:
        return None, None, len(xs)
    return (*pearson(rankdata(xs), rankdata(ys)), len(xs))


def qwk(a: list[int], b: list[int], lo: int = 1, hi: int = 5) -> float | None:
    if not a or len(a) != len(b):
        return None
    k = hi - lo + 1
    conf = [[0.0] * k for _ in range(k)]
    for x, y in zip(a, b):
        conf[x - lo][y - lo] += 1
    n = sum(sum(r) for r in conf)
    if n == 0:
        return None
    for i in range(k):
        for j in range(k):
            conf[i][j] /= n
    hist_a = [sum(conf[i][j] for j in range(k)) for i in range(k)]
    hist_b = [sum(conf[i][j] for i in range(k)) for j in range(k)]
    weights = [[((i - j) ** 2) / ((k - 1) ** 2) for j in range(k)] for i in range(k)]
    obs = sum(weights[i][j] * conf[i][j] for i in range(k) for j in range(k))
    exp = sum(weights[i][j] * hist_a[i] * hist_b[j] for i in range(k) for j in range(k))
    if exp == 0:
        return 1.0 if obs == 0 else 0.0
    return 1.0 - obs / exp


def pairs(a: list[float | None], b: list[float | None]) -> tuple[list[float], list[float]]:
    xs, ys = [], []
    for x, y in zip(a, b):
        if x is None or y is None:
            continue
        xs.append(float(x))
        ys.append(float(y))
    return xs, ys


def num(v: Any) -> float | None:
    if v is None or v == "N/A" or v == "":
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    return x if math.isfinite(x) else None


def svg_scatter(path: Path, xs: list[float], ys: list[float], title: str, xlab: str, ylab: str) -> None:
    w, h, pad = 480, 420, 50
    def sx(v: float) -> float:
        return pad + (v - 1) / 4 * (w - 2 * pad)
    def sy(v: float) -> float:
        return h - pad - (v - 1) / 4 * (h - 2 * pad)
    dots = "\n".join(
        f'<circle cx="{sx(x):.1f}" cy="{sy(y):.1f}" r="3.2" fill="#0052D4" fill-opacity="0.55"/>'
        for x, y in zip(xs, ys)
    )
    rho, p, n = spearman(xs, ys)
    label = f"n={n}"
    if rho is not None:
        label += f"  rho={rho:.3f}  p={p:.4g}"
    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="100%" height="100%" fill="#F8FAFC"/>
  <text x="{w/2}" y="24" text-anchor="middle" font-family="Segoe UI,sans-serif" font-size="14" fill="#1E293B">{title}</text>
  <line x1="{pad}" y1="{h-pad}" x2="{w-pad}" y2="{pad}" stroke="#94A3B8" stroke-dasharray="4 4"/>
  <line x1="{pad}" y1="{h-pad}" x2="{w-pad}" y2="{h-pad}" stroke="#64748B"/>
  <line x1="{pad}" y1="{h-pad}" x2="{pad}" y2="{pad}" stroke="#64748B"/>
  {dots}
  <text x="{w/2}" y="{h-12}" text-anchor="middle" font-family="Segoe UI,sans-serif" font-size="12" fill="#64748B">{xlab}</text>
  <text x="16" y="{h/2}" text-anchor="middle" transform="rotate(-90 16 {h/2})" font-family="Segoe UI,sans-serif" font-size="12" fill="#64748B">{ylab}</text>
  <text x="{pad}" y="42" font-family="Segoe UI,sans-serif" font-size="11" fill="#1E293B">{label}</text>
</svg>
'''
    path.write_text(svg, encoding="utf-8")


def main() -> int:
    print("Validating…")
    if not R2_PATH.is_file() or not R3_PATH.is_file():
        raise SystemExit(f"Missing exports. Looked for {R2_PATH.name} / {R3_PATH.name}")
    r2 = validate(R2_PATH, "R2")
    r3 = validate(R3_PATH, "R3")
    print("R2/R3 OK: 100 IDs, locked, numeric ratings_json")

    opencv = {r["indval_id"]: r for r in read_csv(OPENCV_PATH)}
    musiq = {r["indval_id"]: r for r in read_csv(MUSIQ_PATH)}
    if set(opencv) != set(EXPECTED) or set(musiq) != set(EXPECTED):
        raise SystemExit("Machine ID set mismatch")
    for mid in EXPECTED:
        if (opencv[mid].get("file_sha256") or "").lower() != (musiq[mid].get("file_sha256") or "").lower():
            raise SystemExit(f"SHA mismatch {mid}")

    if COMBINED_OUT.exists():
        # Allow overwrite only if same protocol regenerating analysis folder; refuse to clobber blindly
        # User asked NEW combined file; if exists from prior partial run, overwrite combined only when regenerating
        pass
    combined = []
    for mid in EXPECTED:
        for src in (r2[mid], r3[mid]):
            combined.append(
                {
                    "evaluator_id": src["evaluator_id"],
                    "media_id": mid,
                    "status": "locked",
                    "ratings_json": src["ratings_json"],
                    **{c: (int(src[c]) if isinstance(src[c], float) else src[c]) for c in CRITERIA},
                    "n_numeric_criteria": src["n_numeric_criteria"],
                    "source_file": src["source_file"],
                }
            )
    write_csv(COMBINED_OUT, combined)
    print(f"Wrote {COMBINED_OUT}")

    OUT.mkdir(parents=True, exist_ok=True)

    joined = []
    for mid in EXPECTED:
        row: dict[str, Any] = {
            "media_id": mid,
            "file_sha256": opencv[mid]["file_sha256"],
            "source_media_key": opencv[mid]["source_media_key"],
            "musiq_opq_raw": num(musiq[mid]["musiq_opq_raw"]),
            "musiq_status": musiq[mid]["musiq_status"],
            "musiq_finite_ok": musiq[mid]["musiq_finite_ok"],
        }
        for c in CRITERIA:
            row[f"R2_{c}"] = r2[mid][c]
            row[f"R3_{c}"] = r3[mid][c]
            vals = [v for v in (r2[mid][c], r3[mid][c]) if isinstance(v, float)]
            row[f"human_median_{c}"] = statistics.median(vals) if vals else None
            row[f"human_n_{c}"] = len(vals)
        for _, badge, q in OPENCV_PAIRS:
            row[badge] = num(opencv[mid][badge])
            row[q] = num(opencv[mid][q])
        joined.append(row)
    write_csv(OUT / "joined_human_opencv_musiq.csv", joined)

    desc = []
    for label, store in (("R2", r2), ("R3", r3)):
        for c in CRITERIA:
            nums = [store[mid][c] for mid in EXPECTED if isinstance(store[mid][c], float)]
            n_na = sum(1 for mid in EXPECTED if store[mid][c] == "N/A")
            desc.append(
                {
                    "rater": label,
                    "criterion": c,
                    "n_numeric": len(nums),
                    "n_na": n_na,
                    "mean": round(statistics.fmean(nums), 4) if nums else None,
                    "median": statistics.median(nums) if nums else None,
                    "std": round(statistics.stdev(nums), 4) if len(nums) > 1 else None,
                    "min": int(min(nums)) if nums else None,
                    "max": int(max(nums)) if nums else None,
                }
            )
    write_csv(OUT / "descriptive_human_by_criterion.csv", desc)

    irr = []
    for c in CRITERIA:
        a = [r2[mid][c] if isinstance(r2[mid][c], float) else None for mid in EXPECTED]
        b = [r3[mid][c] if isinstance(r3[mid][c], float) else None for mid in EXPECTED]
        xs, ys = pairs(a, b)
        rho, p, n = spearman(xs, ys)
        pr, pp = pearson(xs, ys) if n >= 3 else (None, None)
        exact = sum(1 for x, y in zip(xs, ys) if int(x) == int(y))
        kappa = qwk([int(x) for x in xs], [int(y) for y in ys])
        mae = statistics.fmean(abs(x - y) for x, y in zip(xs, ys)) if xs else None
        irr.append(
            {
                "criterion": c,
                "n_paired_numeric": n,
                "n_excluded_na_or_missing": 100 - n,
                "spearman_r": rho,
                "spearman_p": p,
                "pearson_r": pr,
                "pearson_p": pp,
                "quadratic_weighted_kappa": kappa,
                "exact_agreement": exact,
                "exact_agreement_rate": (exact / n) if n else None,
                "mae": mae,
            }
        )
    write_csv(OUT / "inter_rater_R2_vs_R3.csv", irr)

    hvm = []
    def add(label: str, hs: list[float | None], ms: list[float | None], kind: str, crit: str, mae_ok: bool, note: str) -> None:
        xs, ys = pairs(hs, ms)
        rho, p, n = spearman(xs, ys)
        pr, pp = pearson(xs, ys) if n >= 3 else (None, None)
        mae = statistics.fmean(abs(x - y) for x, y in zip(xs, ys)) if (mae_ok and xs) else None
        hvm.append(
            {
                "comparison": label,
                "criterion": crit,
                "machine_kind": kind,
                "n": n,
                "spearman_r": rho,
                "spearman_p": p,
                "pearson_r": pr,
                "pearson_p": pp,
                "mae": mae,
                "mae_applicable": mae_ok,
                "note": note,
            }
        )

    for c, badge, q in OPENCV_PAIRS:
        med = [joined[i][f"human_median_{c}"] for i in range(100)]
        add(f"human_median_vs_opencv_badge_{c}", med, [joined[i][badge] for i in range(100)], "opencv_equal_bin_badge", c, True, "OpenCV experimental equal-bin badge")
        add(f"human_median_vs_opencv_q_{c}", med, [joined[i][q] for i in range(100)], "opencv_continuous_q", c, False, "OpenCV continuous q; MAE omitted")
        for rater in ("R2", "R3"):
            hs = [joined[i][f"{rater}_{c}"] if isinstance(joined[i][f"{rater}_{c}"], float) else None for i in range(100)]
            add(f"{rater}_vs_opencv_badge_{c}", hs, [joined[i][badge] for i in range(100)], "opencv_equal_bin_badge", c, True, f"{rater} vs badge")

    overall = [joined[i]["human_median_overall_visual_quality"] for i in range(100)]
    mopq = [joined[i]["musiq_opq_raw"] for i in range(100)]
    add("human_median_overall_vs_musiq_opq", overall, mopq, "musiq_paq2piq_opq", "overall_visual_quality", False, "MUSIQ overall only; MAE omitted (scale mismatch)")
    for rater in ("R2", "R3"):
        hs = [
            joined[i][f"{rater}_overall_visual_quality"]
            if isinstance(joined[i][f"{rater}_overall_visual_quality"], float)
            else None
            for i in range(100)
        ]
        add(f"{rater}_overall_vs_musiq_opq", hs, mopq, "musiq_paq2piq_opq", "overall_visual_quality", False, f"{rater} overall vs MUSIQ")
    for c in ("noise", "ringing_artifacts"):
        hvm.append(
            {
                "comparison": f"no_machine_match_{c}",
                "criterion": c,
                "machine_kind": "none",
                "n": "",
                "spearman_r": "",
                "spearman_p": "",
                "pearson_r": "",
                "pearson_p": "",
                "mae": "",
                "mae_applicable": False,
                "note": "No frozen OpenCV/MUSIQ criterion counterpart; IRR only",
            }
        )
    write_csv(OUT / "human_vs_machine_spearman.csv", hvm)

    na_rows = []
    for label, store in (("R2", r2), ("R3", r3)):
        for c in CRITERIA:
            ids = [mid for mid in EXPECTED if store[mid][c] == "N/A"]
            na_rows.append({"rater": label, "criterion": c, "n_na": len(ids), "media_ids": ";".join(ids)})
    write_csv(OUT / "na_inventory.csv", na_rows)

    # Graphs (SVG)
    for c in CRITERIA:
        xs, ys = pairs(
            [r2[mid][c] if isinstance(r2[mid][c], float) else None for mid in EXPECTED],
            [r3[mid][c] if isinstance(r3[mid][c], float) else None for mid in EXPECTED],
        )
        svg_scatter(OUT / f"fig_irr_{c}.svg", xs, ys, f"R2 vs R3: {c}", "R2", "R3")
    xs, ys = pairs(overall, mopq)
    # scatter overall (y) vs musiq (x) — rescale musiq to 1-5 axis visually? keep raw axes in custom svg
    # Simple custom for musiq x-axis
    w, h, pad = 520, 420, 55
    if xs:
        xmin, xmax = min(ys), max(ys)  # musiq is ys in pairs(overall, mopq) -> xs=overall, ys=musiq
        # fix: pairs(overall, mopq) => xs=human, ys=musiq
        hum, mu = xs, ys
        xmin, xmax = min(mu), max(mu)
        ymin, ymax = 1.0, 5.0
        def sx(v: float) -> float:
            return pad + (v - xmin) / (xmax - xmin + 1e-9) * (w - 2 * pad)
        def sy(v: float) -> float:
            return h - pad - (v - ymin) / (ymax - ymin) * (h - 2 * pad)
        dots = "\n".join(
            f'<circle cx="{sx(m):.1f}" cy="{sy(hh):.1f}" r="3.2" fill="#00C4E8" fill-opacity="0.6"/>'
            for hh, m in zip(hum, mu)
        )
        rho, p, n = spearman(hum, mu)
        (OUT / "fig_overall_vs_musiq.svg").write_text(
            f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="100%" height="100%" fill="#F8FAFC"/>
  <text x="{w/2}" y="24" text-anchor="middle" font-family="Segoe UI,sans-serif" font-size="14">Overall human median vs MUSIQ OPQ</text>
  <line x1="{pad}" y1="{h-pad}" x2="{w-pad}" y2="{h-pad}" stroke="#64748B"/>
  <line x1="{pad}" y1="{h-pad}" x2="{pad}" y2="{pad}" stroke="#64748B"/>
  {dots}
  <text x="{w/2}" y="{h-12}" text-anchor="middle" font-size="12" fill="#64748B">MUSIQ OPQ (~0-100)</text>
  <text x="16" y="{h/2}" transform="rotate(-90 16 {h/2})" text-anchor="middle" font-size="12" fill="#64748B">Human overall (1-5)</text>
  <text x="{pad}" y="42" font-size="11">n={n}  rho={rho:.3f}  p={p:.4g}</text>
</svg>
''',
            encoding="utf-8",
        )

    # bar chart opencv
    bars = []
    for c, _, _ in OPENCV_PAIRS:
        row = next(r for r in hvm if r["comparison"] == f"human_median_vs_opencv_badge_{c}")
        bars.append((c, row["spearman_r"] or 0.0, row["n"]))
    bw = 70
    svg_bars = []
    for i, (c, rho, n) in enumerate(bars):
        x = 60 + i * 90
        y0 = 200
        bh = rho * 150
        y = y0 - bh
        svg_bars.append(f'<rect x="{x}" y="{y}" width="{bw}" height="{abs(bh)}" fill="#0052D4"/>')
        svg_bars.append(f'<text x="{x+bw/2}" y="{y0+18}" text-anchor="middle" font-size="10">{c.replace("_artifacts","")}</text>')
        svg_bars.append(f'<text x="{x+bw/2}" y="{y-6}" text-anchor="middle" font-size="10">n={n}</text>')
    (OUT / "fig_human_vs_opencv_badge_spearman.svg").write_text(
        f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="520" height="260">
  <rect width="100%" height="100%" fill="#F8FAFC"/>
  <text x="260" y="24" text-anchor="middle" font-size="14">Human median vs OpenCV badge Spearman</text>
  <line x1="40" y1="200" x2="500" y2="200" stroke="#64748B"/>
  {''.join(svg_bars)}
</svg>
''',
        encoding="utf-8",
    )

    lines = [
        "# Phase 6B INDVAL statistical analysis",
        "",
        f"Generated UTC: {now()}",
        f"Sources: `{R2_PATH.name}`, `{R3_PATH.name}` (double .csv.csv on disk)",
        f"Combined: `{COMBINED_OUT}`",
        f"Output: `{OUT}`",
        "",
        "## Validation",
        "- R2/R3: 100 unique INDVAL IDs, evaluator_id correct, status=locked, ratings_json with 1-5 or N/A",
        "- OpenCV+MUSIQ joined on INDVAL IDs; SHA matched",
        "- Originals not modified",
        "",
        "## Inter-rater R2 vs R3 (Spearman / QWK)",
        "",
    ]
    for row in irr:
        lines.append(
            f"- **{row['criterion']}:** n={row['n_paired_numeric']}, "
            f"ρ={row['spearman_r']:.3f}, p={row['spearman_p']:.4g}, "
            f"QWK={row['quadratic_weighted_kappa']:.3f}, "
            f"exact={row['exact_agreement_rate']:.3f}"
            if row["spearman_r"] is not None and row["quadratic_weighted_kappa"] is not None
            else f"- **{row['criterion']}:** n={row['n_paired_numeric']}, correlation undefined or sparse"
        )
    lines += ["", "## Human vs OpenCV badge (median)", ""]
    for c, _, _ in OPENCV_PAIRS:
        row = next(r for r in hvm if r["comparison"] == f"human_median_vs_opencv_badge_{c}")
        lines.append(
            f"- **{c}:** n={row['n']}, ρ={row['spearman_r']:.3f}, p={row['spearman_p']:.4g}, MAE={row['mae']:.3f}"
            if row["spearman_r"] is not None
            else f"- **{c}:** n={row['n']}, ρ undefined"
        )
    mrow = next(r for r in hvm if r["comparison"] == "human_median_overall_vs_musiq_opq")
    lines += [
        "",
        "## MUSIQ (overall only)",
        f"- overall vs MUSIQ OPQ: n={mrow['n']}, ρ={mrow['spearman_r']:.3f}, p={mrow['spearman_p']:.4g} (MAE omitted; scale mismatch)",
        "- MUSIQ is not treated as criterion-specific for sharpness/blur/noise/etc.",
        "",
        "## Interpretation",
        "- Two locked raters (R2, R3) on INDVAL holdout; N/A excluded pairwise, never imputed.",
        "- OpenCV badges are experimental equal-bin maps, not production scores.",
        "- Descriptive correlations only; no claim of production cutover.",
        "",
        "## Limitations",
        "- R1 not in locked exports; two-rater IRR only.",
        "- Nominal p-values; no multiplicity correction.",
        "- Human median uses n=1 when the other rater marked N/A.",
        "",
    ]
    (OUT / "INTERPRETATION.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / "run_meta.json").write_text(
        json.dumps(
            {
                "generated_at_utc": now(),
                "r2_source": str(R2_PATH),
                "r3_source": str(R3_PATH),
                "combined": str(COMBINED_OUT),
                "n_images": 100,
                "raters": ["R2", "R3"],
                "originals_modified": False,
                "musiq_overall_only": True,
                "note": "Source filenames use double extension .csv.csv",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Done -> {OUT}")
    for row in irr:
        print(f"IRR {row['criterion']}: n={row['n_paired_numeric']} rho={row['spearman_r']} p={row['spearman_p']}")
    print(f"MUSIQ overall: n={mrow['n']} rho={mrow['spearman_r']} p={mrow['spearman_p']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
