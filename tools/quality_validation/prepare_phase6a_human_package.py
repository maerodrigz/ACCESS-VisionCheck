#!/usr/bin/env python3
"""Phase 6A: prepare independent 100-image human quality validation package.

Audits the frozen Phase 4A holdout, verifies independence from the 30-image pilot,
freezes MUSIQ / OpenCV / feedback versions, and builds a blinded R1/R2/R3 pack.

Does NOT:
  - invent ratings or generate consensus
  - run statistical comparisons
  - overwrite Phase 4A research files under workspace/phase4a_indval/
  - modify FastAPI, Flutter, PROBE, WaveRep, or production scoring

Usage:
  access_backend/venv312/Scripts/python.exe prepare_phase6a_human_package.py
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import struct
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

_TOOLKIT = Path(__file__).resolve().parent
PHASE4A_ROOT = _TOOLKIT / "workspace" / "phase4a_indval"
PHASE4A_MANIFEST = PHASE4A_ROOT / "holdout_manifest.csv"
PHASE4A_IMAGES = PHASE4A_ROOT / "human_packs" / "images"
PHASE4A_FREEZE = _TOOLKIT / "phase4a_freeze_manifest.json"
PILOT_FAC = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "facilitator"
    / "facilitator_manifest.csv"
)
PILOT_RUBRIC = (
    _TOOLKIT / "workspace" / "human_pilot" / "rater_pack" / "HUMAN_RATING_RUBRIC.md"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "phase6a_human_validation"

RATERS = ("R1", "R2", "R3")
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
SHEET_FIELDS = [
    "media_id",
    "rater_id",
    "media_type",
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
]


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in fieldnames})


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _jpeg_readable(path: Path) -> tuple[bool, str]:
    """Minimal JPEG SOI check + non-empty decode of dimensions via struct if possible."""
    try:
        data = path.read_bytes()
    except OSError as exc:
        return False, f"read_error:{exc}"
    if len(data) < 4:
        return False, "too_small"
    if data[0:2] != b"\xff\xd8":
        return False, "not_jpeg_soi"
    # Scan for SOF0/SOF2 to confirm dimensions exist (readable structure)
    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xD8, 0xD9):
            i += 2
            continue
        if marker == 0xDA:  # SOS — image data begins; treat as readable
            return True, "ok"
        if i + 4 > len(data):
            break
        seg_len = struct.unpack(">H", data[i + 2 : i + 4])[0]
        if marker in (0xC0, 0xC2) and seg_len >= 7:
            return True, "ok"
        i += 2 + seg_len
    return True, "ok_soi_only"  # SOI present; still usable for raters


def _link_or_copy(src: Path, dst: Path) -> str:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()
    try:
        os.link(src, dst)
        return "hardlink"
    except OSError:
        shutil.copy2(src, dst)
        return "copy"


def _probe_worker(url: str, timeout: float) -> dict[str, Any]:
    try:
        with httpx.Client(timeout=timeout) as client:
            resp = client.get(f"{url.rstrip('/')}/ready")
            if resp.status_code == 200:
                body = resp.json()
                return {"reachable": True, "ready_body": body}
            return {
                "reachable": True,
                "ready_http": resp.status_code,
                "ready_body": (resp.text or "")[:300],
            }
    except Exception as exc:  # noqa: BLE001
        return {"reachable": False, "error": str(exc)}


def _freeze_record(worker_probe: dict[str, Any], prior: dict[str, Any]) -> dict[str, Any]:
    # Prefer live worker; fall back to Phase 4A freeze + vendor constants
    ready = worker_probe.get("ready_body") if isinstance(worker_probe.get("ready_body"), dict) else {}
    hybrid = prior.get("hybrid_scoring") or {}
    feedback = prior.get("feedback") or {}
    musiq = prior.get("musiq") or {}
    return {
        "phase": "6A",
        "title": "Independent 100-image human validation package freeze",
        "freeze_id": f"phase6a_freeze_{_now_stamp()}",
        "frozen_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "FROZEN_FOR_HUMAN_RATING_COLLECTION",
        "note": (
            "Do not change these versions after human rating begins. "
            "Re-freeze with a new freeze_id if hybrid/MUSIQ/feedback code changes."
        ),
        "inherits_phase4a_freeze_id": prior.get("freeze_id"),
        "holdout": {
            "source": "phase4a_indval",
            "selection_seed": prior.get("selection_seed"),
            "n": 100,
            "blind_ids": "INDVAL-001..INDVAL-100",
        },
        "musiq": {
            "model_id": ready.get("model_id") or musiq.get("preferred_model_id") or "tfhub:google/musiq/paq2piq/1",
            "model_version": ready.get("model_version") or "paq2piq/1",
            "engine_handle": ready.get("engine_handle")
            or "https://tfhub.dev/google/musiq/paq2piq/1",
            "scale": musiq.get("scale") or "approx_0_100_mos_like",
            "worker_ready_at_freeze": bool(ready.get("musiq_ready")),
            "worker_probe": worker_probe,
        },
        "opencv_classical": {
            "classical_map_version": hybrid.get("classical_map_version")
            or "phase9_a_priori_equal_bin_v1",
            "lap_scale": hybrid.get("lap_scale", 420.0),
            "block_ratio_ref": hybrid.get("block_ratio_ref", 1.0),
            "resize_cap": hybrid.get("resize_cap", 1024),
            "equal_bin_label": "experimental_uncalibrated_a_priori",
            "soft_score_applied_to_musiq": False,
            "soft_score_applied_to_hybrid_q": False,
        },
        "experimental_feedback": {
            "feedback_ruleset_version": feedback.get("feedback_ruleset_version")
            or "hybrid_feedback_rules_v1",
            "musiq_excluded_from_criterion_feedback": True,
            "not_distributed_to_raters": True,
            "validated": False,
        },
        "production_unchanged": prior.get("production_unchanged")
        or {
            "quality_engine": "enet",
            "probe_dinov2": True,
            "waverep_g4": True,
            "flutter_admin_ui": True,
        },
        "human_rubric": {
            "source": "human_pilot/rater_pack/HUMAN_RATING_RUBRIC.md",
            "scale": "1=poorest .. 5=best (higher always better, including blur/noise)",
            "criteria": list(CRITERIA),
        },
    }


def _write_instructions(path: Path) -> None:
    text = """# Phase 6A blinded human evaluation — image quality

You are rating photographs for ACCESS VisionCheck independent validation
(holdout `INDVAL-001` … `INDVAL-100`). This set is disjoint from the 30-image pilot.

## Pack contents (rater-safe)

1. `images/INDVAL-001.jpg` … `INDVAL-100.jpg` — anonymous photos only.
2. `ratings_<YOUR_ID>.csv` — your rating sheet (R1, R2, or R3).
3. `HUMAN_RATING_RUBRIC.md` — 1–5 anchors (same wording as the pilot).
4. Optional: `rating_sheet.html` — open locally to rate in a browser, then download CSV.

## Scale (every criterion)

- **1 = poorest quality**
- **5 = best quality**
- Higher is always better, including **Blur** and **Noise**.
- Integers **1, 2, 3, 4, or 5** only. No halves.
- If you cannot judge a criterion, write `N/A`. Never guess. Never use 3 for unknown.

## Criteria to rate

Sharpness, Blur, Noise, Brightness, Contrast, Blocking artifacts, Ringing artifacts,
and Overall visual quality (independent gestalt; do not force it to equal the mean of the seven technical scores).

Photos: leave `flickering` and `motion_stability` as `N/A` (already prefilled).

## Rules

- Rate **what you see**. Do not judge whether the image is AI-generated.
- Do **not** open facilitator mapping files, machine score folders, KonIQ MOS, or other raters' sheets.
- Do not invent scores. Empty cells mean not yet rated.
- Work alone. Do not discuss scores until all three raters have submitted.
- Return your completed `ratings_R#.csv` to the facilitator.

## Viewing

1. Color-managed viewer, sRGB preferred.
2. Fit-to-window first for brightness, contrast, overall.
3. 100% (and 200% if needed) for sharpness, blur, noise, blocking, ringing.
4. Do not apply sharpening, filters, or auto-enhance.

## Status

Score cells start empty on purpose. Independent validation is **not complete** until
R1, R2, and R3 all submit filled sheets and analysis is run separately.
"""
    path.write_text(text, encoding="utf-8")


def _write_facilitator_checklist(path: Path) -> None:
    text = """# Facilitator checklist — Phase 6A

## Distribute to each rater (only)

- `rater_pack/images/`
- `rater_pack/ratings_R#.csv` (one sheet per rater)
- `rater_pack/HUMAN_RATING_RUBRIC.md`
- `rater_pack/INSTRUCTIONS.md`
- optional `rater_pack/rating_sheet.html`

## Do NOT distribute

- `facilitator/` (ID mapping, source keys, SHA-256)
- `freeze/`
- anything under `workspace/phase4a_indval/machine_output/`
- Phase 5 pilot machine scores or AI labels
- `holdout_manifest.csv` / `facilitator_mapping.csv` from Phase 4A

## Receive back

Three CSVs: `ratings_R1.csv`, `ratings_R2.csv`, `ratings_R3.csv` with filled 1–5 cells.

Place filled sheets into `rater_pack/` (or `actual_ratings/`) then run:

```bash
python generate_phase6a_consensus.py --ratings-dir <path-to-filled-sheets>
```

Consensus generation refuses empty sheets by default.
"""
    path.write_text(text, encoding="utf-8")


def _generate_rating_sheet_html(path: Path, ids: list[str]) -> None:
    option = "".join(f'<option value="{i}">{i}</option>' for i in range(1, 6))
    fields = [
        ("sharpness", "Sharpness"),
        ("blur", "Blur (low blur = high score)"),
        ("noise", "Noise (low noise = high score)"),
        ("brightness", "Brightness / exposure"),
        ("contrast", "Contrast"),
        ("blocking_artifacts", "Blocking artifacts"),
        ("ringing_artifacts", "Ringing artifacts"),
        ("overall_visual_quality", "Overall visual quality (separate)"),
    ]
    sections: list[str] = []
    for mid in ids:
        grids = []
        for key, label in fields:
            grids.append(
                f'<label>{label}<select name="{key}" data-field="{key}">'
                f'<option value="" selected></option>{option}</select></label>'
            )
        grids.append(
            '<label>Notes<input type="text" data-field="notes" autocomplete="off"></label>'
        )
        sections.append(
            f'<section class="card" data-id="{mid}"><h2>{mid}</h2>'
            f'<img src="images/{mid}.jpg" alt="{mid}" width="512">'
            f'<div class="grid">{"".join(grids)}</div></section>'
        )
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>ACCESS Phase 6A rating sheet</title>
<style>
body {{ font-family: Segoe UI, sans-serif; background: #f8fafc; color: #1e293b; margin: 1rem; }}
.card {{ background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1rem; margin: 1rem 0; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.6rem; }}
label {{ display: flex; flex-direction: column; font-size: 0.9rem; gap: 0.25rem; }}
select, input {{ padding: 0.35rem; }}
img {{ max-width: 100%; height: auto; border-radius: 8px; }}
.sticky {{ position: sticky; top: 0; background: #f8fafc; padding: 0.5rem 0; z-index: 2; }}
.note {{ color: #64748b; }}
</style>
</head>
<body>
<div class="sticky">
<p><strong>Phase 6A blinded rating sheet.</strong> Scores start empty. Do not look up machine scores.</p>
<p class="note">1 = poorest, 5 = best. Higher is always better (including Blur and Noise). Flicker and motion are N/A.</p>
<label>Rater ID
  <select id="rater">
    <option value="R1">R1</option>
    <option value="R2">R2</option>
    <option value="R3">R3</option>
  </select>
</label>
<button type="button" id="save">Download ratings CSV</button>
</div>
{"".join(sections)}
<script>
function rowFrom(section, rater) {{
  const get = (name) => (section.querySelector('[data-field="'+name+'"]').value || "");
  return [
    section.dataset.id, rater, "photo",
    get("sharpness"), get("blur"), get("noise"), get("brightness"), get("contrast"),
    get("blocking_artifacts"), get("ringing_artifacts"), "N/A", "N/A",
    get("overall_visual_quality"), get("notes")
  ].map(v => `"${{String(v).replaceAll('"','""')}}"`).join(",");
}}
document.getElementById("save").onclick = () => {{
  const rater = document.getElementById("rater").value;
  const header = "media_id,rater_id,media_type,sharpness,blur,noise,brightness,contrast,blocking_artifacts,ringing_artifacts,flickering,motion_stability,overall_visual_quality,notes";
  const rows = [...document.querySelectorAll("section.card")].map(s => rowFrom(s, rater));
  const blob = new Blob([header+"\\n"+rows.join("\\n")+"\\n"], {{type: "text/csv"}});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "ratings_" + rater + ".csv";
  a.click();
}};
</script>
</body>
</html>
"""
    path.write_text(html, encoding="utf-8")


def _write_audit_report(
    path: Path,
    *,
    out_root: Path,
    audit: dict[str, Any],
    freeze: dict[str, Any],
) -> None:
    lines = [
        "# Phase 6A — Independent 100-Image Human Validation Package",
        "",
        f"**Status:** package prepared. Human ratings **not** collected. "
        "Independent validation is **not** complete.",
        f"**Prepared (UTC):** {freeze.get('frozen_at_utc')}",
        f"**Freeze ID:** `{freeze.get('freeze_id')}`",
        f"**Package root:** `{out_root}`",
        "",
        "## 1. Holdout audit",
        "",
        f"- Manifest rows: **{audit['n_manifest']}**",
        f"- Blinded images present: **{audit['n_images']}**",
        f"- Unique INDVAL IDs: **{audit['n_unique_ids']}**",
        f"- Unique SHA-256: **{audit['n_unique_sha']}**",
        f"- Readable JPEGs: **{audit['n_readable']}/{audit['n_images']}**",
        f"- Missing images: {audit['missing_images'] or 'none'}",
        f"- Unreadable: {audit['unreadable'] or 'none'}",
        f"- Duplicate IDs: {audit['duplicate_ids'] or 'none'}",
        f"- Duplicate hashes: {audit['duplicate_sha'] or 'none'}",
        f"- Hash mismatches vs manifest: {audit['hash_mismatches'] or 'none'}",
        "",
        "## 2. Independence from 30-image pilot",
        "",
        f"- Pilot keys overlapping holdout: **{audit['overlap_pilot_keys'] or 'none'}**",
        f"- Pilot SHA-256 overlapping holdout: **{audit['overlap_pilot_sha'] or 'none'}**",
        f"- Selection report pilot_keys_in_selected: "
        f"**{audit.get('selection_pilot_overlap') or 'none'}**",
        "",
        "Holdout remains KonIQ-domain (same corpus family as the pilot) but uses "
        "**disjoint files** by `source_media_key` and content hash.",
        "",
        "## 3. Frozen machine versions (for later analysis; hidden from raters)",
        "",
        f"- MUSIQ: `{freeze['musiq']['model_id']}` / `{freeze['musiq']['model_version']}`",
        f"- OpenCV map: `{freeze['opencv_classical']['classical_map_version']}` "
        "(experimental equal-bin; uncalibrated)",
        f"- Feedback rules: `{freeze['experimental_feedback']['feedback_ruleset_version']}` "
        "(experimental; not distributed to raters)",
        f"- Production quality engine remains: **enet**",
        "",
        "## 4. Package locations",
        "",
        "| Asset | Path |",
        "|---|---|",
        f"| Rater images | `{out_root / 'rater_pack' / 'images'}` |",
        f"| Rating sheets R1–R3 | `{out_root / 'rater_pack' / 'ratings_R*.csv'}` |",
        f"| Rubric | `{out_root / 'rater_pack' / 'HUMAN_RATING_RUBRIC.md'}` |",
        f"| Instructions | `{out_root / 'rater_pack' / 'INSTRUCTIONS.md'}` |",
        f"| HTML helper | `{out_root / 'rater_pack' / 'rating_sheet.html'}` |",
        f"| Facilitator map | `{out_root / 'facilitator' / 'facilitator_mapping.csv'}` |",
        f"| Freeze record | `{out_root / 'freeze' / 'phase6a_freeze.json'}` |",
        f"| Consensus script | `{_TOOLKIT / 'generate_phase6a_consensus.py'}` |",
        "",
        "## 5. Instructions for the three evaluators",
        "",
        "Give each rater only the `rater_pack/` contents (or a zip of that folder) "
        "plus their own `ratings_R#.csv`. Point them to `INSTRUCTIONS.md` and "
        "`HUMAN_RATING_RUBRIC.md`. Collect filled CSVs before any consensus or "
        "machine comparison.",
        "",
        "## 6. Explicit non-claims",
        "",
        "- No human scores were fabricated.",
        "- Consensus was **not** generated.",
        "- Statistical human-vs-machine analysis was **not** run.",
        "- Phase 4A files under `workspace/phase4a_indval/` were **not** overwritten.",
        "- Production scoring / Flutter / PROBE / WaveRep were **not** modified.",
        "",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT)
    ap.add_argument(
        "--worker-url",
        default=os.environ.get("MUSIQ_WORKER_URL", "http://127.0.0.1:8080"),
    )
    ap.add_argument("--timeout-sec", type=float, default=10.0)
    args = ap.parse_args()

    if not PHASE4A_MANIFEST.is_file():
        raise SystemExit(f"Missing Phase 4A manifest: {PHASE4A_MANIFEST}")
    if not PILOT_FAC.is_file():
        raise SystemExit(f"Missing pilot facilitator map: {PILOT_FAC}")
    if not PILOT_RUBRIC.is_file():
        raise SystemExit(f"Missing pilot rubric: {PILOT_RUBRIC}")

    manifest = _read_csv(PHASE4A_MANIFEST)
    if len(manifest) != 100:
        raise SystemExit(f"Expected 100 holdout rows, found {len(manifest)}")

    expected_ids = [f"INDVAL-{i:03d}" for i in range(1, 101)]
    ids = [r["indval_id"] for r in manifest]
    if ids != expected_ids:
        raise SystemExit(
            f"INDVAL ID sequence mismatch. first={ids[:3]} last={ids[-3:]}"
        )

    pilot_rows = _read_csv(PILOT_FAC)
    pilot_keys = {r["source_media_key"] for r in pilot_rows if r.get("source_media_key")}
    pilot_sha = {r["file_sha256"].lower() for r in pilot_rows if r.get("file_sha256")}

    holdout_keys = [r["source_media_key"] for r in manifest]
    holdout_sha_manifest = [r["file_sha256"].lower() for r in manifest]

    selection = {}
    sel_path = PHASE4A_ROOT / "selection_report.json"
    if sel_path.is_file():
        selection = json.loads(sel_path.read_text(encoding="utf-8"))

    prior_freeze: dict[str, Any] = {}
    if PHASE4A_FREEZE.is_file():
        prior_freeze = json.loads(PHASE4A_FREEZE.read_text(encoding="utf-8"))

    # Image integrity
    missing: list[str] = []
    unreadable: list[str] = []
    hash_mismatches: list[str] = []
    computed_sha: list[str] = []
    link_modes: dict[str, int] = {}

    out = args.output
    rater_images = out / "rater_pack" / "images"
    rater_images.mkdir(parents=True, exist_ok=True)
    (out / "facilitator").mkdir(parents=True, exist_ok=True)
    (out / "freeze").mkdir(parents=True, exist_ok=True)

    fac_rows: list[dict[str, str]] = []
    for row in manifest:
        mid = row["indval_id"]
        src_blind = PHASE4A_IMAGES / f"{mid}.jpg"
        if not src_blind.is_file():
            # Fall back to source path in manifest
            alt = Path(row.get("path") or "")
            if alt.is_file():
                src_blind = alt
            else:
                missing.append(mid)
                continue
        ok, reason = _jpeg_readable(src_blind)
        if not ok:
            unreadable.append(f"{mid}:{reason}")
        sha = _sha256_file(src_blind)
        computed_sha.append(sha)
        expected = (row.get("file_sha256") or "").lower()
        if expected and sha != expected:
            hash_mismatches.append(mid)
        dst = rater_images / f"{mid}.jpg"
        mode = _link_or_copy(src_blind, dst)
        link_modes[mode] = link_modes.get(mode, 0) + 1
        fac_rows.append(
            {
                "indval_id": mid,
                "blind_file_name": f"{mid}.jpg",
                "source_media_key": row.get("source_media_key", ""),
                "pool": row.get("pool", ""),
                "koniq_media_id": row.get("koniq_media_id", ""),
                "file_sha256": sha,
                "mos_quality_raw_facilitator_only": row.get("mos_quality_raw", ""),
                "source_path_facilitator_only": row.get("path", ""),
            }
        )

    overlap_keys = sorted(set(holdout_keys) & pilot_keys)
    overlap_sha = sorted(set(holdout_sha_manifest) & pilot_sha)
    dup_ids = sorted({i for i in ids if ids.count(i) > 1})
    sha_counts: dict[str, int] = {}
    for s in computed_sha:
        sha_counts[s] = sha_counts.get(s, 0) + 1
    dup_sha = sorted([s for s, c in sha_counts.items() if c > 1])

    audit = {
        "n_manifest": len(manifest),
        "n_images": len(computed_sha),
        "n_unique_ids": len(set(ids)),
        "n_unique_sha": len(set(computed_sha)),
        "n_readable": len(computed_sha) - len(unreadable),
        "missing_images": missing,
        "unreadable": unreadable,
        "duplicate_ids": dup_ids,
        "duplicate_sha": dup_sha,
        "hash_mismatches": hash_mismatches,
        "overlap_pilot_keys": overlap_keys,
        "overlap_pilot_sha": overlap_sha,
        "selection_pilot_overlap": (selection.get("overlap_checks") or {}).get(
            "pilot_keys_in_selected"
        ),
        "image_materialization": link_modes,
        "phase4a_files_overwritten": False,
        "ratings_fabricated": False,
        "consensus_generated": False,
    }

    if missing or unreadable or dup_ids or dup_sha or hash_mismatches or overlap_keys or overlap_sha:
        # Independence / integrity failures are hard stops except readability soi_only
        hard = missing or dup_ids or dup_sha or hash_mismatches or overlap_keys or overlap_sha
        if hard:
            (out / "audit_failed.json").write_text(
                json.dumps(audit, indent=2) + "\n", encoding="utf-8"
            )
            raise SystemExit(f"Phase 6A audit FAILED: {json.dumps(audit, indent=2)}")

    # Facilitator mapping (NOT for raters)
    _write_csv(
        out / "facilitator" / "facilitator_mapping.csv",
        [
            "indval_id",
            "blind_file_name",
            "source_media_key",
            "pool",
            "koniq_media_id",
            "file_sha256",
            "mos_quality_raw_facilitator_only",
            "source_path_facilitator_only",
        ],
        fac_rows,
    )
    _write_facilitator_checklist(out / "facilitator" / "CHECKLIST.md")
    (out / "facilitator" / "DO_NOT_DISTRIBUTE.txt").write_text(
        "This folder reveals source identities and MOS. Never give to raters.\n",
        encoding="utf-8",
    )

    # Rubric: preserve pilot wording
    shutil.copy2(PILOT_RUBRIC, out / "rater_pack" / "HUMAN_RATING_RUBRIC.md")
    _write_instructions(out / "rater_pack" / "INSTRUCTIONS.md")

    # Empty rating sheets (pilot column layout; no color columns)
    for rater in RATERS:
        rows = []
        for mid in expected_ids:
            rows.append(
                {
                    "media_id": mid,
                    "rater_id": rater,
                    "media_type": "photo",
                    "sharpness": "",
                    "blur": "",
                    "noise": "",
                    "brightness": "",
                    "contrast": "",
                    "blocking_artifacts": "",
                    "ringing_artifacts": "",
                    "flickering": "N/A",
                    "motion_stability": "N/A",
                    "overall_visual_quality": "",
                    "notes": "",
                }
            )
        _write_csv(out / "rater_pack" / f"ratings_{rater}.csv", SHEET_FIELDS, rows)

    _generate_rating_sheet_html(out / "rater_pack" / "rating_sheet.html", expected_ids)

    # Pack meta (rater-safe; no scores)
    pack_meta = {
        "phase": "6A",
        "n_images": 100,
        "raters": list(RATERS),
        "criteria": list(CRITERIA),
        "scale": "1=poorest .. 5=best",
        "human_scores_fabricated": False,
        "machine_scores_in_pack": False,
        "images_linked_or_copied_from": str(PHASE4A_IMAGES),
        "rubric_source": str(PILOT_RUBRIC),
    }
    (out / "rater_pack" / "pack_meta.json").write_text(
        json.dumps(pack_meta, indent=2) + "\n", encoding="utf-8"
    )
    (out / "rater_pack" / ".gitignore").write_text(
        "# Large blinded JPGs (local research assets)\nimages/\n",
        encoding="utf-8",
    )

    worker_probe = _probe_worker(args.worker_url, args.timeout_sec)
    freeze = _freeze_record(worker_probe, prior_freeze)
    freeze_path = out / "freeze" / "phase6a_freeze.json"
    freeze_path.write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")
    # Also pin under tools/ for discoverability without touching phase4a freeze
    pin = _TOOLKIT / "phase6a_freeze_manifest.json"
    pin.write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")

    (out / "audit.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    report = out / "PHASE6A_PACKAGE_AUDIT.md"
    _write_audit_report(report, out_root=out, audit=audit, freeze=freeze)

    # Top-level pointer in quality_validation (does not overwrite phase4a)
    summary = _TOOLKIT / "PHASE6A_HUMAN_PACKAGE_READY.md"
    summary.write_text(
        f"# Phase 6A package ready\n\n"
        f"See `{report}`.\n\n"
        f"Rater pack: `{out / 'rater_pack'}`\n\n"
        f"**Independent validation is not complete.** Collect R1/R2/R3 ratings next.\n",
        encoding="utf-8",
    )

    print("Phase 6A package prepared.")
    print(f"  root: {out}")
    print(f"  images: {audit['n_images']}/100 readable={audit['n_readable']}")
    print(f"  pilot overlap keys: {audit['overlap_pilot_keys'] or 'none'}")
    print(f"  freeze: {freeze['freeze_id']}")
    print(f"  report: {report}")
    print("  consensus: NOT generated (as required)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
