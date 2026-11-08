#!/usr/bin/env python3
"""Build a blinded 30-image human-rating pack from Run 002. No ratings. No scoring."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.metadata import file_sha256  # noqa: E402
from tools.quality_validation.research_datasets import KONIQ_ROOT  # noqa: E402

SELECTION_SEED = 20261107
SELECTION_SALT = "pilot30"
PRESENTATION_SALT = "presentation"
STRATA = ("Q1_very_low", "Q3_mid", "Q5_very_high")
N_PER_BAND = 10
RUN002_ROOT = KONIQ_ROOT / "run_002"
RUN002_MANIFEST = RUN002_ROOT / "metadata" / "selection_manifest.csv"
RUN002_IMAGES = RUN002_ROOT / "images"
PILOT_ROOT = _TOOLKIT / "workspace" / "human_pilot"
RATING_COLUMNS = (
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
)


class PilotError(ValueError):
    pass


def salted_rank(keys: list[str], seed: int, salt: str) -> list[str]:
    unique = sorted({k for k in keys if k})
    return sorted(
        unique,
        key=lambda key: hashlib.sha256(f"{seed}\0{salt}\0{key}".encode("utf-8")).hexdigest(),
    )


def load_run002_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def inspect_jpeg(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise PilotError(f"Missing image: {path}")
    with Image.open(path) as image:
        image.load()
        rgb = ImageOps.exif_transpose(image) or image
        width, height = rgb.size
        fmt = image.format
    if fmt not in frozenset({"MPO", "JPEG"}):
        raise PilotError(f"Not a readable JPEG: {path} format={fmt}")
    if width < 8 or height < 8:
        raise PilotError(f"Image too small: {path} {width}x{height}")
    return {"width": width, "height": height, "format": fmt, "bytes": path.stat().st_size}


def select_pilot(rows: list[dict[str, str]], *, images_dir: Path) -> list[dict[str, Any]]:
    by_stratum: dict[str, list[dict[str, str]]] = {s: [] for s in STRATA}
    seen_keys: set[str] = set()
    for row in rows:
        key = (row.get("source_media_key") or "").strip()
        label = (row.get("stratum_label") or "").strip()
        if not key:
            raise PilotError("Run 002 manifest row missing source_media_key")
        if key in seen_keys:
            raise PilotError(f"Duplicate source_media_key in Run 002 manifest: {key}")
        seen_keys.add(key)
        if label not in by_stratum:
            continue
        by_stratum[label].append(row)

    selected_rows: list[dict[str, str]] = []
    for label in STRATA:
        pool = by_stratum[label]
        if len(pool) < N_PER_BAND:
            raise PilotError(f"{label}: need {N_PER_BAND} images, pool has {len(pool)}")
        keys = [r["source_media_key"] for r in pool]
        take = salted_rank(keys, SELECTION_SEED, f"{SELECTION_SALT}|{label}")[:N_PER_BAND]
        lookup = {r["source_media_key"]: r for r in pool}
        selected_rows.extend(lookup[k] for k in take)

    hashes: dict[str, str] = {}
    enriched: list[dict[str, Any]] = []
    for row in selected_rows:
        src = images_dir / Path(row["source_media_key"]).name
        meta = inspect_jpeg(src)
        digest = file_sha256(src)
        if digest in hashes:
            raise PilotError(f"Duplicate file content: {hashes[digest]} and {src.name}")
        hashes[digest] = src.name
        rec = dict(row)
        rec["source_path"] = src.resolve()
        rec.update(meta)
        rec["file_sha256"] = digest
        enriched.append(rec)

    order_keys = [r["source_media_key"] for r in enriched]
    presentation = salted_rank(order_keys, SELECTION_SEED, PRESENTATION_SALT)
    lookup = {r["source_media_key"]: r for r in enriched}
    ordered = [lookup[k] for k in presentation]
    labels = [r["stratum_label"] for r in ordered[:10]]
    if len(set(labels)) == 1:
        raise PilotError("Presentation order is still grouped by a single stratum in the first 10")
    return ordered


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def write_rater_sheet(path: Path, rater_id: str, media_ids: list[str]) -> None:
    rows = [
        {
            "media_id": mid,
            "rater_id": rater_id,
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
        for mid in media_ids
    ]
    write_csv(path, list(RATING_COLUMNS), rows)


def rater_texts_are_blind(rater_root: Path, forbidden: list[str]) -> list[str]:
    leaks: list[str] = []
    for path in rater_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() in {".jpeg", ".png", ".jpg"}:
            continue
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            if token and token in text:
                leaks.append(f"{path.name}: {token}")
    return leaks


def rater_readme(media_ids: list[str]) -> str:
    first = media_ids[0] if media_ids else "PILOT-001"
    return f"""# Single-rater pack (Phase 10)

Rate what you see. Do not open facilitator files, machine CSVs, or published opinion scores.

Start with `{first}.jpg` in `images/`. Fill the matching row in `ratings_DEV.csv` or use `rating_sheet.html`.

Seven technical scores are independent of overall visual quality. Photos: flickering and motion stay `N/A`.

Higher is always better, including Blur and Noise. Integers 1–5 only. Empty means not yet rated. Never guess. Never use 3 for unknown.

This pack is blinded. File names are `PILOT-001` … `PILOT-030` only.
"""


def facilitator_checklist(n: int) -> str:
    return f"""# Facilitator (private)

Do not share this folder with the rater.

- Seed `{SELECTION_SEED}`, selection salt `{SELECTION_SALT}`, presentation salt `{PRESENTATION_SALT}`.
- {n} JPEGs copied from Run 002. Original filenames and MOS stay in `facilitator_manifest.csv`.
- Rater materials must not include this file.
- After the rater locks `ratings_DEV.csv`, run `analyze_phase10_single_rater.py`.
- Single-rater results are exploratory and can reflect developer bias.
- Do not retrain, retune `_soft_score`, or write production APIs from this pack.
"""


def verification_markdown(checks: dict[str, Any]) -> str:
    lines = [
        "# Human pilot verification",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "",
        "Selection uses frozen seed/salts. No human scores were written.",
        "",
    ]
    for key, value in checks.items():
        lines.append(f"- `{key}`: {value}")
    lines.append("")
    return "\n".join(lines)


def rating_sheet_html(media_ids: list[str]) -> str:
    options = "".join(f'<option value="{i}">{i}</option>' for i in range(1, 6))
    criteria = [
        ("sharpness", "Sharpness"),
        ("blur", "Blur (low blur = high score)"),
        ("noise", "Noise (low noise = high score)"),
        ("brightness", "Brightness / exposure"),
        ("contrast", "Contrast"),
        ("blocking_artifacts", "Blocking artifacts"),
        ("ringing_artifacts", "Ringing artifacts"),
    ]
    cards = []
    for mid in media_ids:
        fields = []
        for col, label in criteria:
            fields.append(
                f'<label>{label}<select name="{col}" data-field="{col}">'
                f'<option value="" selected></option>{options}</select></label>'
            )
        fields.append(
            '<label>Overall visual quality (separate)'
            f'<select name="overall_visual_quality" data-field="overall_visual_quality">'
            f'<option value="" selected></option>{options}</select></label>'
        )
        fields.append('<label>Notes<input type="text" data-field="notes" autocomplete="off"></label>')
        cards.append(
            f'<section class="card" data-id="{mid}">'
            f"<h2>{mid}</h2>"
            f'<img src="images/{mid}.jpg" alt="{mid}" width="512">'
            f'<div class="grid">{"".join(fields)}</div></section>'
        )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>ACCESS Phase 10 rating sheet</title>
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
<p><strong>Phase 10 single-rater sheet.</strong> Scores start empty. Do not look up machine scores.</p>
<p class="note">Seven technical fields are not averaged into overall. Flicker and motion are N/A for photos.</p>
<button type="button" id="save">Download ratings_DEV.csv</button>
</div>
{"".join(cards)}
<script>
const RATER = "DEV";
function rowFrom(section) {{
  const get = (name) => (section.querySelector('[data-field="'+name+'"]').value || "");
  return [
    section.dataset.id, RATER, "photo",
    get("sharpness"), get("blur"), get("noise"), get("brightness"), get("contrast"),
    get("blocking_artifacts"), get("ringing_artifacts"), "N/A", "N/A",
    get("overall_visual_quality"), get("notes")
  ].map(v => `"${{String(v).replaceAll('"','""')}}"`).join(",");
}}
document.getElementById("save").onclick = () => {{
  const header = "media_id,rater_id,media_type,sharpness,blur,noise,brightness,contrast,blocking_artifacts,ringing_artifacts,flickering,motion_stability,overall_visual_quality,notes";
  const rows = [...document.querySelectorAll("section.card")].map(rowFrom);
  const blob = new Blob([header+"\\n"+rows.join("\\n")+"\\n"], {{type: "text/csv"}});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "ratings_DEV.csv";
  a.click();
}};
</script>
</body>
</html>
"""


def build_pack(output_root: Path, run002_root: Path) -> dict[str, Any]:
    rows = load_run002_rows(run002_root / "metadata" / "selection_manifest.csv")
    images_dir = run002_root / "images"
    ordered = select_pilot(rows, images_dir=images_dir)
    rater_root = output_root / "rater_pack"
    fac_root = output_root / "facilitator"
    img_out = rater_root / "images"
    if output_root.exists():
        for sub in (rater_root, fac_root):
            if sub.exists():
                shutil.rmtree(sub)
    img_out.mkdir(parents=True, exist_ok=True)
    fac_root.mkdir(parents=True, exist_ok=True)
    (fac_root / "originals").mkdir(parents=True, exist_ok=True)

    records: list[dict[str, Any]] = []
    for index, src in enumerate(ordered, start=1):
        anon = f"PILOT-{index:03d}"
        dest = img_out / f"{anon}.jpg"
        shutil.copy2(src["source_path"], dest)
        inspect_jpeg(dest)
        preserved = fac_root / "originals" / f"{anon}.jpg"
        shutil.copy2(src["source_path"], preserved)
        rec = {
            "anonymous_id": anon,
            "presentation_order": index,
            "koniq2_media_id": src["media_id"],
            "source_media_key": src["source_media_key"],
            "original_relative_path": src.get("relative_path") or f"images/{src['source_media_key']}",
            "blind_relative_path": f"images/{anon}.jpg",
            "mos_quality_raw": src.get("mos_quality_raw", ""),
            "overall_mapped_1_5": src.get("overall_mapped_1_5", ""),
            "stratum_id": src.get("stratum_id", ""),
            "stratum_label": src.get("stratum_label", ""),
            "selection_seed": SELECTION_SEED,
            "selection_salt": SELECTION_SALT,
            "presentation_salt": PRESENTATION_SALT,
            "width": src["width"],
            "height": src["height"],
            "file_bytes": src["bytes"],
            "file_sha256": src["file_sha256"],
            "source_path": str(src["source_path"]),
        }
        records.append(rec)

    media_ids = [r["anonymous_id"] for r in records]
    write_csv(
        fac_root / "facilitator_manifest.csv",
        [
            "anonymous_id",
            "presentation_order",
            "koniq2_media_id",
            "source_media_key",
            "original_relative_path",
            "blind_relative_path",
            "mos_quality_raw",
            "overall_mapped_1_5",
            "stratum_id",
            "stratum_label",
            "selection_seed",
            "selection_salt",
            "presentation_salt",
            "width",
            "height",
            "file_bytes",
            "file_sha256",
        ],
        records,
    )
    write_rater_sheet(rater_root / "ratings_DEV.csv", "DEV", media_ids)
    write_rater_sheet(rater_root / "ratings_R1.csv", "R1", media_ids)
    (rater_root / "rating_sheet.html").write_text(rating_sheet_html(media_ids), encoding="utf-8")
    (rater_root / "INSTRUCTIONS.md").write_text(rater_readme(media_ids), encoding="utf-8")
    rubric_src = _TOOLKIT / "HUMAN_RATING_RUBRIC.md"
    shutil.copy2(rubric_src, rater_root / "HUMAN_RATING_RUBRIC.md")
    (fac_root / "CHECKLIST.md").write_text(facilitator_checklist(len(records)), encoding="utf-8")

    forbidden = []
    for rec in records:
        forbidden.extend(
            [
                rec["source_media_key"],
                Path(rec["source_media_key"]).stem,
                rec["koniq2_media_id"],
                str(rec["mos_quality_raw"]),
                rec["stratum_label"],
            ]
        )
    forbidden.extend(["Q1_very_low", "Q3_mid", "Q5_very_high", "published_mos", "overall_score"])
    leaks = rater_texts_are_blind(rater_root, forbidden)
    if leaks:
        raise PilotError("Rater pack leak: " + "; ".join(leaks[:8]))

    empty_ok = True
    with (rater_root / "ratings_DEV.csv").open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            for col in (
                "sharpness",
                "blur",
                "noise",
                "brightness",
                "contrast",
                "blocking_artifacts",
                "ringing_artifacts",
                "overall_visual_quality",
            ):
                if (row.get(col) or "").strip():
                    empty_ok = False
    checks = {
        "n_images": len(records),
        "unique_sha256": len({r["file_sha256"] for r in records}),
        "readable_jpeg": all(inspect_jpeg(img_out / f"{mid}.jpg") for mid in media_ids),
        "stratum_counts": dict(Counter(r["stratum_label"] for r in records)),
        "rating_fields_empty": empty_ok,
        "rater_leaks": 0,
        "first_id": media_ids[0] if media_ids else None,
    }
    (fac_root / "verification.md").write_text(verification_markdown(checks), encoding="utf-8")
    (fac_root / "verification.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
    (output_root / "README.md").write_text(
        "# Human validation pilot\n\n"
        "Share only `rater_pack/` with the rater. Keep `facilitator/` private.\n"
        "Original Run 002 files were copied, not moved.\n",
        encoding="utf-8",
    )
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=PILOT_ROOT)
    parser.add_argument("--run002-root", type=Path, default=RUN002_ROOT)
    args = parser.parse_args()
    try:
        checks = build_pack(args.output_dir.resolve(), args.run002_root.resolve())
    except PilotError as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(checks, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
