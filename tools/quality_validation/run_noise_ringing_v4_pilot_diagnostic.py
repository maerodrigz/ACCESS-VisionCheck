#!/usr/bin/env python3
"""Secondary diagnostic: Noise v4 / Ringing v4 vs cached v2/v3 on frozen ACCESS pilot.

- Does NOT tune thresholds or modify engines/production/human CSVs.
- Reuses cached v2/v3 badges and locked human medians.
- Scores only Noise v4 and Ringing v4 (no SPAQ, no full seven-criterion engine).
- Insufficient-evidence cases are excluded from primary metrics and listed separately.
"""

from __future__ import annotations

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

from tools.quality_validation.experimental_noise_v4_pca import (  # noqa: E402
    estimate_noise_bgr as estimate_noise_v4,
)
from tools.quality_validation.experimental_ringing_v4_halo import (  # noqa: E402
    estimate_ringing_bgr as estimate_ringing_v4,
)
from tools.quality_validation.metrics import pearson_spearman  # noqa: E402
from tools.quality_validation.scoring_candidates import equal_bin_1_5  # noqa: E402

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

PILOT_ORIGINALS = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "originals"
PILOT_CONSENSUS = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "human_consensus_by_image.csv"
)
NOISE_V3_CACHE = (
    _TOOLKIT
    / "workspace"
    / "experimental_quality"
    / "output"
    / "noise_v3_eval_20261108T133005Z"
    / "access_pilot_noise_v2_vs_v3.csv"
)
COMBINED_CACHE = (
    _TOOLKIT
    / "workspace"
    / "experimental_quality"
    / "output"
    / "combined_v1_eval_20261108T143610Z"
    / "access_pilot_combined_vs_cached.csv"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"


def _log(msg: str) -> None:
    print(msg, flush=True)


def load_csv_map(path: Path, key: str) -> dict[str, dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return {(row.get(key) or "").strip(): row for row in csv.DictReader(handle) if row.get(key)}


def _hist(values: list[int]) -> dict[str, int]:
    c = Counter(int(v) for v in values)
    return {str(i): int(c.get(i, 0)) for i in range(1, 6)}


def _mae(h: list[float], m: list[float]) -> float | None:
    if not h:
        return None
    return float(np.mean(np.abs(np.asarray(h) - np.asarray(m))))


def _bias(h: list[float], m: list[float]) -> float | None:
    if not h:
        return None
    return float(np.mean(np.asarray(m) - np.asarray(h)))


def _within1(h: list[float], m: list[float]) -> float | None:
    if not h:
        return None
    return float(np.mean(np.abs(np.asarray(h) - np.asarray(m)) <= 1.0 + 1e-9))


def _metrics(h: list[float], m: list[float]) -> dict[str, Any]:
    corr = pearson_spearman(h, m)
    return {
        "n": len(h),
        "spearman_r": corr.get("spearman_r"),
        "spearman_p": corr.get("spearman_p"),
        "mae": _mae(h, m),
        "mean_signed_bias_machine_minus_human": _bias(h, m),
        "within_1_rate": _within1(h, m),
        "badge_hist": _hist([int(round(x)) for x in m]),
        "human_hist": _hist([int(round(x)) if float(x).is_integer() else int(x) for x in h]),
    }


def _false_cases(
    rows: list[dict[str, Any]], human_key: str, machine_key: str
) -> dict[str, list[dict[str, Any]]]:
    """False-harsh: human high cleanliness, machine low. False-clean: opposite."""
    harsh: list[dict[str, Any]] = []
    clean: list[dict[str, Any]] = []
    for r in rows:
        try:
            h = float(r[human_key])
            m = float(r[machine_key])
        except (TypeError, ValueError):
            continue
        if h >= 4.5 and m <= 2:
            harsh.append({"media_id": r["media_id"], "human": h, "machine": m})
        if h <= 3.0 and m >= 5:
            clean.append({"media_id": r["media_id"], "human": h, "machine": m})
    return {"false_harsh": harsh, "false_clean": clean}


def _verdict(rho_v2: float | None, rho_v4: float | None, mae_v2: float | None, mae_v4: float | None) -> str:
    if rho_v4 is None or rho_v2 is None:
        return "MIXED"
    # Prefer rank agreement; MAE as secondary.
    if rho_v4 >= rho_v2 + 0.05 and (mae_v4 is None or mae_v2 is None or mae_v4 <= mae_v2 + 0.15):
        return "IMPROVED"
    if rho_v4 <= rho_v2 - 0.05 and (mae_v4 is None or mae_v2 is None or mae_v4 >= mae_v2 - 0.05):
        return "REGRESSED"
    # Sign flip to non-negative counts as improvement even if modest.
    if rho_v2 < 0 <= rho_v4:
        return "IMPROVED"
    if rho_v4 < 0 <= rho_v2:
        return "REGRESSED"
    return "MIXED"


def main() -> int:
    if cv2 is None:
        raise RuntimeError("OpenCV required")
    for path in (PILOT_CONSENSUS, NOISE_V3_CACHE, COMBINED_CACHE, PILOT_ORIGINALS):
        if not path.exists():
            raise FileNotFoundError(path)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = DEFAULT_OUT / f"noise_ringing_v4_pilot_diag_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)
    _log(f"[START] Noise/Ringing v4 pilot diagnostic → {out_dir}")
    _log("[NOTE] Frozen scales; no tuning; insufficient-evidence excluded from primary metrics.")

    consensus = load_csv_map(PILOT_CONSENSUS, "media_id")
    noise_cache = load_csv_map(NOISE_V3_CACHE, "media_id")
    combined_cache = load_csv_map(COMBINED_CACHE, "media_id")
    media_ids = sorted(consensus.keys())
    n = len(media_ids)

    rows: list[dict[str, Any]] = []
    noise_insufficient: list[dict[str, Any]] = []
    ringing_insufficient: list[dict[str, Any]] = []
    times_noise: list[float] = []
    times_ring: list[float] = []
    t0 = time.perf_counter()

    ckpt = out_dir / "per_image_checkpoint.csv"
    fields = [
        "media_id",
        "human_noise",
        "noise_v2",
        "noise_v3",
        "noise_v4",
        "noise_v4_amount",
        "noise_v4_evidence",
        "noise_v4_fallback_reason",
        "human_ringing",
        "ringing_v2",
        "ringing_v3",
        "ringing_v4",
        "ringing_v4_amount",
        "ringing_v4_evidence",
        "ringing_v4_limitation",
        "ms_noise_v4",
        "ms_ringing_v4",
    ]

    def _append(row: dict[str, Any]) -> None:
        exists = ckpt.is_file() and ckpt.stat().st_size > 0
        with ckpt.open("a", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
            if not exists:
                writer.writeheader()
            writer.writerow(row)

    for i, mid in enumerate(media_ids, start=1):
        path = PILOT_ORIGINALS / f"{mid}.jpg"
        cons = consensus[mid]
        ncache = noise_cache.get(mid, {})
        ccache = combined_cache.get(mid, {})
        human_noise = cons.get("noise_median") or ncache.get("human_noise_median") or ""
        human_ring = cons.get("ringing_artifacts_median") or ccache.get("human_ringing_artifacts") or ""

        rec: dict[str, Any] = {
            "media_id": mid,
            "human_noise": human_noise,
            "noise_v2": ncache.get("v2_noise_badge", ccache.get("v2_noise", "")),
            "noise_v3": ncache.get("v3_noise_badge", ""),
            "human_ringing": human_ring,
            "ringing_v2": ccache.get("v2_ringing_artifacts", ""),
            "ringing_v3": ccache.get("combined_ringing_artifacts", ""),  # combined used Ringing v3
        }

        if not path.is_file():
            rec.update(
                {
                    "noise_v4_evidence": "missing_image",
                    "ringing_v4_evidence": "missing_image",
                }
            )
            rows.append(rec)
            _append(rec)
            _log(f"[{i}/{n}] {mid} MISSING")
            continue

        bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if bgr is None:
            rec.update(
                {
                    "noise_v4_evidence": "decode_failed",
                    "ringing_v4_evidence": "decode_failed",
                }
            )
            rows.append(rec)
            _append(rec)
            _log(f"[{i}/{n}] {mid} DECODE_FAILED")
            continue

        tn = time.perf_counter()
        n4 = estimate_noise_v4(bgr)
        ms_n = (time.perf_counter() - tn) * 1000.0
        times_noise.append(ms_n)

        tr = time.perf_counter()
        r4 = estimate_ringing_v4(bgr)
        ms_r = (time.perf_counter() - tr) * 1000.0
        times_ring.append(ms_r)

        noise_insuff = bool(n4.get("insufficient_homogeneous_patches"))
        ring_ok = bool(r4.get("reliable_edge_profile"))

        rec["ms_noise_v4"] = round(ms_n, 2)
        rec["ms_ringing_v4"] = round(ms_r, 2)
        rec["noise_v4_amount"] = float(n4["noise_amount"])
        rec["noise_v4_fallback_reason"] = n4.get("fallback_reason")
        rec["ringing_v4_amount"] = float(r4["ringing_amount"])
        rec["ringing_v4_limitation"] = r4.get("limitation")

        if noise_insuff:
            rec["noise_v4_evidence"] = "insufficient"
            rec["noise_v4"] = ""
            noise_insufficient.append(
                {
                    "media_id": mid,
                    "human_noise": human_noise,
                    "fallback_reason": n4.get("fallback_reason"),
                    "raw_amount_if_fallback_applied": float(n4["noise_amount"]),
                    "note": "Excluded from primary Noise metrics; no fabricated primary badge.",
                }
            )
        else:
            rec["noise_v4_evidence"] = "ok"
            rec["noise_v4"] = equal_bin_1_5(float(n4["quality_cleanliness_0_1"]))

        if not ring_ok:
            rec["ringing_v4_evidence"] = "insufficient"
            rec["ringing_v4"] = ""
            ringing_insufficient.append(
                {
                    "media_id": mid,
                    "human_ringing": human_ring,
                    "limitation": r4.get("limitation"),
                    "raw_amount_if_returned": float(r4["ringing_amount"]),
                    "note": "Excluded from primary Ringing metrics; no fabricated primary badge.",
                }
            )
        else:
            rec["ringing_v4_evidence"] = "ok"
            rec["ringing_v4"] = equal_bin_1_5(float(r4["quality_cleanliness_0_1"]))

        rows.append(rec)
        _append(rec)
        _log(
            f"[{i}/{n}] {mid} noise_ev={rec['noise_v4_evidence']} n4={rec.get('noise_v4')} "
            f"ring_ev={rec['ringing_v4_evidence']} r4={rec.get('ringing_v4')} "
            f"({ms_n:.0f}/{ms_r:.0f} ms)"
        )

    # Write full per-image CSV
    with (out_dir / "per_image_noise_ringing_v2_v3_v4.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    def collect(version: str, human_key: str, machine_key: str, evidence_key: str | None = None) -> tuple[list[float], list[float], list[dict[str, Any]]]:
        hs: list[float] = []
        ms: list[float] = []
        used: list[dict[str, Any]] = []
        for r in rows:
            if evidence_key and r.get(evidence_key) != "ok":
                continue
            try:
                h = float(r[human_key])
                m = float(r[machine_key])
            except (TypeError, ValueError):
                continue
            hs.append(h)
            ms.append(m)
            used.append(r)
        return hs, ms, used

    # Noise metrics
    hn2, mn2, rows_n2 = collect("v2", "human_noise", "noise_v2")
    hn3, mn3, rows_n3 = collect("v3", "human_noise", "noise_v3")
    hn4, mn4, rows_n4 = collect("v4", "human_noise", "noise_v4", "noise_v4_evidence")

    noise_block = {
        "v2": {**_metrics(hn2, mn2), "cases": _false_cases(rows_n2, "human_noise", "noise_v2")},
        "v3": {**_metrics(hn3, mn3), "cases": _false_cases(rows_n3, "human_noise", "noise_v3")},
        "v4": {**_metrics(hn4, mn4), "cases": _false_cases(rows_n4, "human_noise", "noise_v4")},
        "insufficient_evidence": noise_insufficient,
        "n_insufficient": len(noise_insufficient),
        "verdict": _verdict(
            _metrics(hn2, mn2).get("spearman_r"),
            _metrics(hn4, mn4).get("spearman_r"),
            _metrics(hn2, mn2).get("mae"),
            _metrics(hn4, mn4).get("mae"),
        ),
        "verdict_vs_v3": _verdict(
            _metrics(hn3, mn3).get("spearman_r"),
            _metrics(hn4, mn4).get("spearman_r"),
            _metrics(hn3, mn3).get("mae"),
            _metrics(hn4, mn4).get("mae"),
        ),
    }

    hr2, mr2, rows_r2 = collect("v2", "human_ringing", "ringing_v2")
    hr3, mr3, rows_r3 = collect("v3", "human_ringing", "ringing_v3")
    hr4, mr4, rows_r4 = collect("v4", "human_ringing", "ringing_v4", "ringing_v4_evidence")

    ringing_block = {
        "v2": {**_metrics(hr2, mr2), "cases": _false_cases(rows_r2, "human_ringing", "ringing_v2")},
        "v3": {**_metrics(hr3, mr3), "cases": _false_cases(rows_r3, "human_ringing", "ringing_v3")},
        "v4": {**_metrics(hr4, mr4), "cases": _false_cases(rows_r4, "human_ringing", "ringing_v4")},
        "insufficient_evidence": ringing_insufficient,
        "n_insufficient": len(ringing_insufficient),
        "verdict": _verdict(
            _metrics(hr2, mr2).get("spearman_r"),
            _metrics(hr4, mr4).get("spearman_r"),
            _metrics(hr2, mr2).get("mae"),
            _metrics(hr4, mr4).get("mae"),
        ),
        "verdict_vs_v3": _verdict(
            _metrics(hr3, mr3).get("spearman_r"),
            _metrics(hr4, mr4).get("spearman_r"),
            _metrics(hr3, mr3).get("mae"),
            _metrics(hr4, mr4).get("mae"),
        ),
    }

    wall = time.perf_counter() - t0
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "role": "frozen_secondary_diagnostic_not_for_tuning",
        "n_images": n,
        "algorithms_frozen": True,
        "tuned_on_pilot": False,
        "spaq_run": False,
        "production_modified": False,
        "caches": {
            "noise_v2_v3": str(NOISE_V3_CACHE),
            "ringing_v2_v3_from_combined": str(COMBINED_CACHE),
            "human_consensus": str(PILOT_CONSENSUS),
        },
        "runtime": {
            "wall_seconds": round(wall, 3),
            "mean_ms_noise_v4": float(np.mean(times_noise)) if times_noise else None,
            "mean_ms_ringing_v4": float(np.mean(times_ring)) if times_ring else None,
        },
        "noise": noise_block,
        "ringing": ringing_block,
        "note": (
            "Primary metrics exclude insufficient-evidence v4 cases. "
            "This is diagnostic only; not human-rating validation and not for threshold fitting."
        ),
    }
    (out_dir / "noise_ringing_v4_pilot_diag.json").write_text(
        json.dumps(payload, indent=2, default=str), encoding="utf-8"
    )
    (out_dir / "noise_insufficient_evidence.json").write_text(
        json.dumps(noise_insufficient, indent=2), encoding="utf-8"
    )
    (out_dir / "ringing_insufficient_evidence.json").write_text(
        json.dumps(ringing_insufficient, indent=2), encoding="utf-8"
    )

    def _line(label: str, block: dict[str, Any]) -> list[str]:
        lines = [f"### {label}", ""]
        for ver in ("v2", "v3", "v4"):
            b = block[ver]
            lines.append(
                f"- **{ver}**: n={b['n']} Spearman={b['spearman_r']} MAE={b['mae']} "
                f"bias={b['mean_signed_bias_machine_minus_human']} within1={b['within_1_rate']} "
                f"hist={b['badge_hist']}"
            )
            lines.append(
                f"  false_harsh={len(b['cases']['false_harsh'])} "
                f"false_clean={len(b['cases']['false_clean'])}"
            )
        lines.append(f"- insufficient-evidence excluded: {block['n_insufficient']}")
        lines.append(f"- **Verdict vs v2: {block['verdict']}**")
        lines.append(f"- Verdict vs v3: {block['verdict_vs_v3']}")
        lines.append("")
        return lines

    report = [
        "# Noise / Ringing v4 frozen-pilot diagnostic",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Wall seconds: {payload['runtime']['wall_seconds']}",
        f"Mean ms Noise v4: {payload['runtime']['mean_ms_noise_v4']}",
        f"Mean ms Ringing v4: {payload['runtime']['mean_ms_ringing_v4']}",
        "",
        "Secondary diagnostic only. Scales frozen. No tuning. No SPAQ. No production changes.",
        "",
        *_line("Noise", noise_block),
        *_line("Ringing", ringing_block),
        "## Recommendation",
        "Do not integrate into production. Await approval before any further evaluation or composition change.",
        "",
    ]
    (out_dir / "NOISE_RINGING_V4_PILOT_DIAG_REPORT.md").write_text("\n".join(report), encoding="utf-8")

    summary = {
        "status": "ok",
        "output_dir": str(out_dir),
        "noise_verdict_vs_v2": noise_block["verdict"],
        "noise_verdict_vs_v3": noise_block["verdict_vs_v3"],
        "ringing_verdict_vs_v2": ringing_block["verdict"],
        "ringing_verdict_vs_v3": ringing_block["verdict_vs_v3"],
        "noise_rho": {k: noise_block[k]["spearman_r"] for k in ("v2", "v3", "v4")},
        "ringing_rho": {k: ringing_block[k]["spearman_r"] for k in ("v2", "v3", "v4")},
        "wall_seconds": payload["runtime"]["wall_seconds"],
    }
    _log(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
