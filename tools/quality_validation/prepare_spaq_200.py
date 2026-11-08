#!/usr/bin/env python3
"""Extract SPAQ Part 1-5 ZIPs, merge human ratings, verify 200 JPEGs.

Research only. Does not score images, retrain, or change production.
Does not rewrite values inside the original part CSVs.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import shutil
import statistics
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps, UnidentifiedImageError

_TOOLKIT = Path(__file__).resolve().parent
SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
RATING_FIELDS = (
    "media_id",
    "source_media_key",
    "mos_quality_raw",
    "attr_brightness_raw",
    "attr_colorfulness_raw",
    "attr_contrast_raw",
    "attr_noisiness_raw",
    "attr_sharpness_raw",
    "stratum_id",
    "stratum_label",
    "selection_seed",
    "n_per_stratum",
    "image_on_disk",
)
NUMERIC_FIELDS = (
    "mos_quality_raw",
    "attr_brightness_raw",
    "attr_colorfulness_raw",
    "attr_contrast_raw",
    "attr_noisiness_raw",
    "attr_sharpness_raw",
)
STRATUM_LABELS = {
    1: "Q1_very_low",
    2: "Q2_low",
    3: "Q3_mid",
    4: "Q4_high",
    5: "Q5_very_high",
}


class IntegrityError(RuntimeError):
    pass


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe_zip_members(zf: zipfile.ZipFile, dest: Path) -> list[zipfile.ZipInfo]:
    dest_res = dest.resolve()
    out: list[zipfile.ZipInfo] = []
    for info in zf.infolist():
        name = info.filename.replace("\\", "/")
        if name.startswith("/") or name.startswith("\\") or ":" in Path(name).parts[0]:
            raise IntegrityError(f"Rejected absolute zip path: {info.filename!r}")
        if any(part == ".." for part in Path(name).parts):
            raise IntegrityError(f"Rejected zip-slip path: {info.filename!r}")
        target = (dest / name).resolve()
        if dest_res not in target.parents and target != dest_res:
            raise IntegrityError(f"Rejected path outside dest: {info.filename!r}")
        out.append(info)
    return out


def extract_zip(zip_path: Path, dest: Path) -> list[str]:
    dest.mkdir(parents=True, exist_ok=True)
    names: list[str] = []
    with zipfile.ZipFile(zip_path) as zf:
        for info in _safe_zip_members(zf, dest):
            zf.extract(info, dest)
            names.append(info.filename.replace("\\", "/"))
    return names


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    text = path.read_text(encoding="utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        raise IntegrityError(f"Empty CSV: {path}")
    missing = [f for f in RATING_FIELDS if f not in reader.fieldnames]
    if missing:
        raise IntegrityError(f"{path.name} missing columns: {missing}")
    rows = []
    for rec in reader:
        rows.append({k: (rec.get(k) or "").strip() for k in RATING_FIELDS})
    return rows


def parse_float(val: str) -> float | None:
    s = (val or "").strip()
    if s == "":
        return None
    try:
        return float(s)
    except ValueError:
        return None


def jpeg_ok(path: Path) -> tuple[bool, str, int, int]:
    try:
        with Image.open(path) as img:
            fmt = (img.format or "").upper()
            img.verify()
        with Image.open(path) as img:
            img = ImageOps.exif_transpose(img)
            img.load()
            w, h = img.size
        if fmt not in {"JPEG", "MPO"}:
            return False, f"format={fmt or 'unknown'}", 0, 0
        if w < 1 or h < 1:
            return False, "empty_size", w, h
        return True, "ok", w, h
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        return False, str(exc), 0, 0


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_selected_csv(path: Path) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {row["source_media_key"]: row for row in csv.DictReader(handle)}


def values_close(a: str, b: str, *, tol: float = 1e-6) -> bool:
    fa, fb = parse_float(a), parse_float(b)
    if fa is None or fb is None:
        return (a or "").strip() == (b or "").strip()
    return math.isclose(fa, fb, rel_tol=0.0, abs_tol=tol)


def summarize(values: list[float]) -> dict[str, float | int | None]:
    if not values:
        return {"n": 0, "min": None, "max": None, "mean": None, "stdev": None}
    return {
        "n": len(values),
        "min": min(values),
        "max": max(values),
        "mean": statistics.fmean(values),
        "stdev": statistics.pstdev(values) if len(values) > 1 else 0.0,
    }


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def prepare(
    root: Path,
    *,
    n_parts: int = 5,
    expected_per_part: int = 40,
    expected_total: int | None = None,
) -> dict[str, Any]:
    expected_total = expected_total if expected_total is not None else n_parts * expected_per_part
    zips = [root / f"SPAQ_Part_{i}.zip" for i in range(1, n_parts + 1)]
    missing_zips = [str(p) for p in zips if not p.is_file()]
    if missing_zips:
        raise IntegrityError(f"Missing ZIP packages: {missing_zips}")

    extract_root = root / "extracted"
    images_dir = root / "images"
    metadata = root / "metadata"
    parts_csv_dir = metadata / "parts"
    if images_dir.exists():
        shutil.rmtree(images_dir)
    if extract_root.exists():
        shutil.rmtree(extract_root)
    images_dir.mkdir(parents=True, exist_ok=True)
    parts_csv_dir.mkdir(parents=True, exist_ok=True)

    merged: list[dict[str, str]] = []
    issues: list[str] = []
    per_part: list[dict[str, Any]] = []

    for zip_path in zips:
        dest = extract_root / zip_path.stem
        names = extract_zip(zip_path, dest)
        csv_path = dest / "human_ratings.csv"
        img_dir = dest / "images"
        if not csv_path.is_file():
            raise IntegrityError(f"{zip_path.name}: human_ratings.csv missing after extract")
        if not img_dir.is_dir():
            raise IntegrityError(f"{zip_path.name}: images/ missing after extract")
        shutil.copy2(csv_path, parts_csv_dir / f"{zip_path.stem}_human_ratings.csv")
        rows = read_csv_rows(csv_path)
        jpgs = sorted(p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg"})
        per_part.append(
            {
                "zip": zip_path.name,
                "zip_bytes": zip_path.stat().st_size,
                "n_zip_entries": len(names),
                "n_csv_rows": len(rows),
                "n_jpegs": len(jpgs),
            }
        )
        if len(rows) != expected_per_part:
            issues.append(f"{zip_path.name}: expected {expected_per_part} CSV rows, got {len(rows)}")
        if len(jpgs) != expected_per_part:
            issues.append(f"{zip_path.name}: expected {expected_per_part} JPEGs, got {len(jpgs)}")
        merged.extend(rows)
        for jpg in jpgs:
            target = images_dir / jpg.name
            if target.exists():
                issues.append(f"Duplicate filename while copying: {jpg.name}")
                continue
            shutil.copy2(jpg, target)

    write_csv(metadata / "human_ratings_200.csv", merged, list(RATING_FIELDS))

    mapping = {
        "source_dataset": "SPAQ",
        "subset": "mos_stratified_200",
        "label_provenance": "human_subjective",
        "mos_scale": "0-100",
        "attribute_scale": "0-100",
        "filename_transform": "identity",
        "media_id_template": "spaq_{source_media_key_safe}",
        "source_media_key_column": "source_media_key",
        "dataset_split_column": None,
        "columns": {
            "source_media_key": "source_media_key",
            "mos_quality_raw": "mos_quality_raw",
            "attr_sharpness_raw": "attr_sharpness_raw",
            "attr_brightness_raw": "attr_brightness_raw",
            "attr_noisiness_raw": "attr_noisiness_raw",
            "attr_contrast_raw": "attr_contrast_raw",
            "attr_colorfulness_raw": "attr_colorfulness_raw",
        },
        "_comment": (
            "Merged from SPAQ_Part_1..5 human_ratings.csv without changing original values. "
            "Do not retrain production heads on this subset."
        ),
    }
    (metadata / "import_mapping.spaq_200.json").write_text(
        json.dumps(mapping, indent=2) + "\n", encoding="utf-8"
    )

    selected_path = root / "spaq_mos_stratified_200.csv"
    selected = load_selected_csv(selected_path) if selected_path.is_file() else {}

    keys = [r["source_media_key"] for r in merged]
    ids = [r["media_id"] for r in merged]
    disk_jpgs = sorted(p for p in images_dir.iterdir() if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg"})
    disk_names = [p.name for p in disk_jpgs]

    dup_keys = sorted(k for k, n in Counter(keys).items() if n > 1)
    dup_ids = sorted(k for k, n in Counter(ids).items() if n > 1)
    dup_files = sorted(k for k, n in Counter(disk_names).items() if n > 1)
    if dup_keys:
        issues.append(f"Duplicate source_media_key in merged CSV: {dup_keys}")
    if dup_ids:
        issues.append(f"Duplicate media_id in merged CSV: {dup_ids}")
    if dup_files:
        issues.append(f"Duplicate JPEG filenames: {dup_files}")

    csv_set = set(keys)
    disk_set = set(disk_names)
    missing_files = sorted(csv_set - disk_set)
    extra_files = sorted(disk_set - csv_set)
    if missing_files:
        issues.append(f"CSV keys without JPEG: {missing_files}")
    if extra_files:
        issues.append(f"JPEGs without CSV row: {extra_files}")

    if selected:
        selected_keys = set(selected)
        missing_selected = sorted(selected_keys - csv_set)
        extra_vs_selected = sorted(csv_set - selected_keys)
        if missing_selected:
            issues.append(f"Selected 200 list keys missing from ZIP CSV: {missing_selected}")
        if extra_vs_selected:
            issues.append(f"ZIP CSV keys not in selected 200 list: {extra_vs_selected}")

    index_rows: list[dict[str, Any]] = []
    unreadable: list[str] = []
    value_mismatch: list[str] = []
    empty_ratings: list[str] = []
    stratum_counts: Counter[str] = Counter()
    rating_stats: dict[str, list[float]] = {f: [] for f in NUMERIC_FIELDS}

    for rec in merged:
        key = rec["source_media_key"]
        path = images_dir / key
        ok, reason, w, h = jpeg_ok(path) if path.is_file() else (False, "missing", 0, 0)
        if not ok:
            unreadable.append(f"{key}: {reason}")
        sel = selected.get(key, {})
        for field in NUMERIC_FIELDS:
            val = parse_float(rec[field])
            if val is None:
                empty_ratings.append(f"{key}.{field}")
            else:
                rating_stats[field].append(val)
            if sel and field in sel and not values_close(rec[field], sel[field]):
                value_mismatch.append(f"{key}.{field}: zip={rec[field]!r} selected={sel[field]!r}")
        if sel and rec["media_id"] != sel.get("media_id"):
            value_mismatch.append(f"{key}.media_id: zip={rec['media_id']!r} selected={sel.get('media_id')!r}")
        label = rec["stratum_label"]
        stratum_counts[label] += 1
        expected_label = STRATUM_LABELS.get(int(rec["stratum_id"]) if rec["stratum_id"].isdigit() else -1)
        if expected_label and label != expected_label:
            issues.append(f"{key}: stratum_id {rec['stratum_id']} label {label!r} != {expected_label}")
        index_rows.append(
            {
                "media_id": rec["media_id"],
                "source_media_key": key,
                "relative_path": f"images/{key}",
                "stratum_id": rec["stratum_id"],
                "stratum_label": rec["stratum_label"],
                "jpeg_readable": ok,
                "jpeg_error": "" if ok else reason,
                "width": w,
                "height": h,
                "bytes": path.stat().st_size if path.is_file() else 0,
                "sha256": sha256_file(path) if ok else "",
            }
        )

    if unreadable:
        issues.append(f"Unreadable JPEGs: {unreadable}")
    if empty_ratings:
        issues.append(f"Empty rating cells: {empty_ratings}")
    if value_mismatch:
        issues.append(f"Value mismatches vs spaq_mos_stratified_200.csv: {value_mismatch[:20]}")

    expected_per_stratum = expected_per_part if n_parts == 5 else None
    if expected_per_stratum is not None:
        for label in STRATUM_LABELS.values():
            n = stratum_counts.get(label, 0)
            if n != expected_per_stratum:
                issues.append(f"Stratum {label}: expected {expected_per_stratum}, got {n}")

    n_unique = len(set(keys))
    n_readable = sum(1 for r in index_rows if r["jpeg_readable"])
    paired = (
        n_unique == expected_total
        and n_readable == expected_total
        and not missing_files
        and not extra_files
        and not dup_keys
    )

    write_csv(
        metadata / "integrity_index.csv",
        index_rows,
        [
            "media_id",
            "source_media_key",
            "relative_path",
            "stratum_id",
            "stratum_label",
            "jpeg_readable",
            "jpeg_error",
            "width",
            "height",
            "bytes",
            "sha256",
        ],
    )

    payload = {
        "generated_at": _now(),
        "status": "ok" if paired and not issues else "failed",
        "production_untouched": True,
        "original_part_csvs_unmodified": True,
        "n_zip_packages": n_parts,
        "n_annotation_rows": len(merged),
        "n_unique_source_keys": n_unique,
        "n_jpegs_on_disk": len(disk_jpgs),
        "n_readable_jpegs": n_readable,
        "one_to_one_image_annotation": paired,
        "stratum_counts": dict(stratum_counts),
        "expected_per_stratum": expected_per_stratum,
        "selection_seed": merged[0]["selection_seed"] if merged else None,
        "rating_completeness": {
            "empty_cells": empty_ratings,
            "n_empty": len(empty_ratings),
            "all_seven_fields_present": not empty_ratings,
        },
        "duplicates": {"source_media_key": dup_keys, "media_id": dup_ids, "filenames": dup_files},
        "missing_files": missing_files,
        "extra_files": extra_files,
        "unreadable": unreadable,
        "value_mismatch_vs_selected_list": value_mismatch,
        "per_part": per_part,
        "rating_summary": {k: summarize(v) for k, v in rating_stats.items()},
        "paths": {
            "images": str(images_dir),
            "merged_csv": str(metadata / "human_ratings_200.csv"),
            "parts_csv": str(parts_csv_dir),
            "integrity_index": str(metadata / "integrity_index.csv"),
        },
        "issues": issues,
        "notes": [
            "Merged CSV copies original ZIP rating values, including image_on_disk=False from the packages.",
            "Do not treat image_on_disk in the merged CSV as a live disk flag; use integrity_index.csv.",
            "Original SPAQ_Part_*.zip files were not modified.",
        ],
    }
    (metadata / "integrity_report.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    (root / "SPAQ_200_INTEGRITY.md").write_text(render_markdown(payload), encoding="utf-8")
    return payload


def render_markdown(payload: dict[str, Any]) -> str:
    summary = payload.get("rating_summary") or {}
    lines = [
        "# SPAQ 200-image dataset integrity",
        "",
        f"**Generated:** {payload['generated_at']}",
        f"**Status:** `{payload['status']}`",
        "",
        "Research workspace only. Production scoring, weights, API, Flutter, XP, authenticity, Gemini, and MUSIQ were not changed. Original ZIP `human_ratings.csv` values were copied, not rewritten.",
        "",
        "## Counts",
        "",
        "| Check | Value |",
        "|-------|-------|",
        f"| ZIP packages | {payload['n_zip_packages']} |",
        f"| Annotation rows | {payload['n_annotation_rows']} |",
        f"| Unique `source_media_key` | {payload['n_unique_source_keys']} |",
        f"| JPEGs on disk | {payload['n_jpegs_on_disk']} |",
        f"| Readable JPEGs | {payload['n_readable_jpegs']} |",
        f"| 1:1 image-annotation | {payload['one_to_one_image_annotation']} |",
        f"| Empty rating cells | {payload['rating_completeness']['n_empty']} |",
        f"| Value mismatches vs selected list | {len(payload['value_mismatch_vs_selected_list'])} |",
        "",
        "## MOS quintiles (must be 40 each)",
        "",
        "| Stratum | Count |",
        "|---------|-------|",
    ]
    counts = payload.get("stratum_counts") or {}
    for i in range(1, 6):
        label = STRATUM_LABELS[i]
        lines.append(f"| {i} `{label}` | {counts.get(label, 0)} |")
    lines += [
        "",
        "## Rating summaries (original 0-100 values)",
        "",
        "| Field | n | min | max | mean |",
        "|-------|---|-----|-----|------|",
    ]
    for key in NUMERIC_FIELDS:
        st = summary.get(key) or {}
        lines.append(
            f"| `{key}` | {st.get('n')} | {st.get('min')} | {st.get('max')} | "
            f"{None if st.get('mean') is None else round(float(st['mean']), 4)} |"
        )
    lines += [
        "",
        "## Duplicates / missing",
        "",
        f"- Duplicate keys: {payload['duplicates']['source_media_key'] or 'none'}",
        f"- Missing JPEGs: {payload['missing_files'] or 'none'}",
        f"- Extra JPEGs: {payload['extra_files'] or 'none'}",
        f"- Unreadable: {payload['unreadable'] or 'none'}",
        "",
        "## Issues",
        "",
    ]
    if payload["issues"]:
        for item in payload["issues"]:
            lines.append(f"- {item}")
    else:
        lines.append("- none")
    lines += [
        "",
        "## Files",
        "",
        f"- Images: `{payload['paths']['images']}`",
        f"- Master annotations: `{payload['paths']['merged_csv']}`",
        f"- Per-part original CSVs: `{payload['paths']['parts_csv']}`",
        f"- Integrity index: `{payload['paths']['integrity_index']}`",
        "",
        "Scoring was not run in this step.",
        "",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=SPAQ_ROOT)
    args = parser.parse_args()
    payload = prepare(args.root.resolve())
    print(json.dumps({"status": payload["status"], "n_readable": payload["n_readable_jpegs"]}, indent=2))
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
