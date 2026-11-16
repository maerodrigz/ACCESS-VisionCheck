"""Subset selection, filename matching, and preview (no scoring, no downloads)."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
from typing import Any

from tools.quality_validation.scale_mapping import map_mos_to_1_5, parse_optional_float, validate_raw_in_scale

TOOLKIT = Path(__file__).resolve().parent
DATASETS = TOOLKIT / "workspace" / "datasets"
KONIQ_ROOT = DATASETS / "koniq10k"
LIVE_ROOT = DATASETS / "live_vqc"

DEFAULT_PHOTO_N = 40
DEFAULT_VIDEO_N = 20
DEFAULT_SEED = 20261106


def find_score_file(metadata_dir: Path, candidates: tuple[str, ...]) -> Path | None:
    if not metadata_dir.is_dir():
        return None
    for name in candidates:
        path = metadata_dir / name
        if path.is_file():
            return path
    matches = sorted(
        p
        for p in metadata_dir.iterdir()
        if p.is_file() and p.suffix.lower() in {".csv", ".tab", ".tsv", ".mat", ".xlsx"}
    )
    return matches[0] if len(matches) == 1 else None


def list_media_files(folder: Path, suffixes: frozenset[str]) -> list[Path]:
    if not folder.is_dir():
        return []
    return sorted(
        path for path in folder.rglob("*") if path.is_file() and path.suffix.lower() in suffixes
    )


def media_lookup(files: list[Path]) -> dict[str, Path]:
    out: dict[str, Path] = {}
    for path in files:
        out[path.name] = path
        out[path.stem] = path
    return out


def empirical_percentile(sorted_values: list[float], p: float) -> float:
    """Linear interpolation percentile on a pre-sorted list (inclusive rank)."""
    if not sorted_values:
        raise ValueError("Cannot compute percentile of an empty list")
    if p < 0 or p > 100:
        raise ValueError("p must be in 0..100")
    n = len(sorted_values)
    rank = (n - 1) * (p / 100.0)
    lo = int(rank)
    hi = min(lo + 1, n - 1)
    frac = rank - lo
    return float(sorted_values[lo] * (1.0 - frac) + sorted_values[hi] * frac)


def koniq_quintile_cuts(mos_values: list[float]) -> tuple[float, ...]:
    """Return (min, p20, p40, p60, p80, max) from observed MOS."""
    xs = sorted(float(v) for v in mos_values)
    return (
        xs[0],
        empirical_percentile(xs, 20),
        empirical_percentile(xs, 40),
        empirical_percentile(xs, 60),
        empirical_percentile(xs, 80),
        xs[-1],
    )


def assign_mos_quintile(mos: float, cuts: tuple[float, ...]) -> int:
    """Strata 1..5. Cuts are (min, p20, p40, p60, p80, max). Ties at a cut go to the lower stratum."""
    if len(cuts) != 6:
        raise ValueError("cuts must have 6 values")
    if mos <= cuts[1]:
        return 1
    if mos <= cuts[2]:
        return 2
    if mos <= cuts[3]:
        return 3
    if mos <= cuts[4]:
        return 4
    return 5


STRATUM_LABELS = {
    1: "Q1_very_low",
    2: "Q2_low",
    3: "Q3_mid",
    4: "Q4_high",
    5: "Q5_very_high",
}


def deterministic_subset(keys: list[str], n: int, seed: int) -> list[str]:
    """Stable shuffle: sort, then order by sha256(seed + key)."""
    unique = sorted({k for k in keys if k})
    if n < 0:
        raise ValueError("n must be >= 0")
    ranked = sorted(
        unique,
        key=lambda key: hashlib.sha256(f"{seed}\0{key}".encode("utf-8")).hexdigest(),
    )
    return ranked[: min(n, len(ranked))]


def mos_to_access_1_5(raw: float | None, mos_scale: str) -> float | None:
    if raw is None:
        return None
    if not validate_raw_in_scale(raw, mos_scale):
        return None
    return map_mos_to_1_5(raw, mos_scale)


def match_filename(source_key: str, files: list[Path] | dict[str, Path]) -> Path | None:
    lookup = files if isinstance(files, dict) else media_lookup(files)
    key = source_key.strip()
    if key in lookup:
        return lookup[key]
    name = Path(key).name
    if name in lookup:
        return lookup[name]
    stem = Path(key).stem
    if stem in lookup:
        return lookup[stem]
    return None


def summarize_mos(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0, "min": None, "max": None, "mean": None}
    return {
        "n": len(values),
        "min": min(values),
        "max": max(values),
        "mean": sum(values) / len(values),
    }


def build_subset_records(
    rows: list[dict[str, Any]],
    *,
    media_files: list[Path] | dict[str, Path],
    dataset_root: Path,
    n: int,
    seed: int,
    media_type: str,
    id_prefix: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    keys = [str(r["source_media_key"]) for r in rows if r.get("source_media_key")]
    by_key = {str(r["source_media_key"]): r for r in rows}
    records: list[dict[str, Any]] = []
    missing_files: list[str] = []
    missing_mos: list[str] = []
    for index, key in enumerate(deterministic_subset(keys, n, seed), start=1):
        src = by_key[key]
        path = match_filename(key, media_files)
        exists = path is not None and path.is_file()
        if not exists:
            missing_files.append(key)
        mos = src.get("mos_quality_raw")
        if mos is None:
            missing_mos.append(key)
        rel = ""
        if path is not None:
            try:
                rel = path.resolve().relative_to(dataset_root.resolve()).as_posix()
            except ValueError:
                rel = path.name
        records.append(
            {
                "media_id": f"{id_prefix}-{index:03d}",
                "source_dataset": src.get("source_dataset"),
                "source_media_key": key,
                "media_type": media_type,
                "relative_path": rel,
                "file_exists": exists,
                "mos_quality_raw": mos,
                "mos_scale": src.get("mos_scale"),
                "overall_mapped_1_5": src.get("overall_mapped_1_5"),
                "selection_seed": seed,
                "selection_index": index,
                "label_provenance": src.get("label_provenance"),
                "not_individual_raters": True,
                "not_criterion_scores": True,
            }
        )
    report = {
        "catalog_n": len(rows),
        "requested_n": n,
        "selected_n": len(records),
        "selection_seed": seed,
        "files_present": sum(1 for r in records if r["file_exists"]),
        "files_missing": missing_files,
        "mos_missing": missing_mos,
        "mos_distribution_raw": summarize_mos(
            [float(r["mos_quality_raw"]) for r in records if isinstance(r.get("mos_quality_raw"), (int, float))]
        ),
        "mos_distribution_mapped_1_5": summarize_mos(
            [float(r["overall_mapped_1_5"]) for r in records if isinstance(r.get("overall_mapped_1_5"), (int, float))]
        ),
    }
    return records, report


def inspect_live_vqc_metadata(path: Path) -> dict[str, Any]:
    suffix = path.suffix.lower()
    if suffix == ".mat":
        from scipy.io import loadmat

        data = loadmat(path, squeeze_me=True, struct_as_record=False)
        keys = sorted(k for k in data.keys() if not k.startswith("__"))
        return {"format": "mat", "path": str(path), "mat_keys": keys, "ready_to_import": False,
                "reason": "Fill templates/import_mapping.live_vqc.example.json from these keys. Do not guess."}
    if suffix in {".csv", ".tsv", ".tab"}:
        text = path.read_text(encoding="utf-8-sig")
        delimiter = "\t" if text.splitlines()[0].count("\t") >= text.splitlines()[0].count(",") else ","
        headers = next(csv.reader(text.splitlines(), delimiter=delimiter))
        return {
            "format": "csv",
            "path": str(path),
            "headers": [h.strip() for h in headers],
            "ready_to_import": False,
            "reason": "Copy exact headers into import_mapping.live_vqc.example.json columns.*",
        }
    return {"format": suffix, "path": str(path), "ready_to_import": False, "reason": "Unsupported metadata format"}


PUBLISHED_MOS_COLUMNS = (
    "media_id",
    "source_dataset",
    "source_media_key",
    "media_type",
    "relative_path",
    "file_exists",
    "mos_quality_raw",
    "mos_scale",
    "mos_direction",
    "overall_mapped_1_5",
    "selection_seed",
    "selection_index",
    "label_provenance",
    "not_individual_raters",
    "not_criterion_scores",
    "license_note",
)


def write_published_mos(records: list[dict[str, Any]], path: Path, *, license_note: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(PUBLISHED_MOS_COLUMNS), extrasaction="ignore")
        writer.writeheader()
        for rec in records:
            row = {col: rec.get(col, "") for col in PUBLISHED_MOS_COLUMNS}
            row["file_exists"] = "true" if rec.get("file_exists") else "false"
            row["not_individual_raters"] = "true"
            row["not_criterion_scores"] = "true"
            row["mos_direction"] = rec.get("mos_direction") or "higher_is_better"
            row["license_note"] = rec.get("license_note") or license_note
            for key in ("mos_quality_raw", "overall_mapped_1_5"):
                if row[key] is None:
                    row[key] = ""
            writer.writerow(row)


def load_published_mos(path: Path) -> list[dict[str, Any]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for rec in rows:
        media_id = (rec.get("media_id") or "").strip()
        if not media_id:
            continue
        if media_id in seen:
            raise ValueError(f"Duplicate media_id in published MOS file: {media_id}")
        seen.add(media_id)
        out.append(
            {
                "media_id": media_id,
                "source_dataset": rec.get("source_dataset") or "",
                "source_media_key": rec.get("source_media_key") or "",
                "media_type": rec.get("media_type") or "",
                "relative_path": rec.get("relative_path") or "",
                "file_exists": str(rec.get("file_exists") or "").strip().lower() in {"1", "true", "yes"},
                "mos_quality_raw": parse_optional_float(rec.get("mos_quality_raw")),
                "mos_scale": rec.get("mos_scale") or "",
                "overall_mapped_1_5": parse_optional_float(rec.get("overall_mapped_1_5")),
                "label_provenance": rec.get("label_provenance") or "human_subjective",
                "not_individual_raters": True,
                "not_criterion_scores": True,
                "selection_seed": rec.get("selection_seed") or "",
            }
        )
    return out


def write_subset_manifest(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = (
        "media_id",
        "relative_path",
        "media_type",
        "source_dataset",
        "source_media_key",
        "selection_seed",
        "selection_index",
        "file_exists",
        "quality_condition",
        "notes",
    )
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for rec in records:
            writer.writerow(
                {
                    "media_id": rec.get("media_id"),
                    "relative_path": rec.get("relative_path") or "",
                    "media_type": rec.get("media_type"),
                    "source_dataset": rec.get("source_dataset"),
                    "source_media_key": rec.get("source_media_key"),
                    "selection_seed": rec.get("selection_seed"),
                    "selection_index": rec.get("selection_index"),
                    "file_exists": "true" if rec.get("file_exists") else "false",
                    "quality_condition": rec.get("quality_condition") or "",
                    "notes": rec.get("notes") or "published MOS overall only",
                }
            )
