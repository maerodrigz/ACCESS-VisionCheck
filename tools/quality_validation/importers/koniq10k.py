"""Import KonIQ-10k official scores using documented headers only."""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Any

from tools.quality_validation.importers.mapping_config import (
    apply_media_id_template,
    load_mapping_config,
    normalize_source_key,
)
from tools.quality_validation.reference_io import empty_reference_row
from tools.quality_validation.scale_mapping import map_mos_to_1_5, parse_optional_float, validate_raw_in_scale

DOCUMENTED_HEADERS = (
    "image_name",
    "c1",
    "c2",
    "c3",
    "c4",
    "c5",
    "c_total",
    "MOS",
    "SD",
    "MOS_zscore",
)
REQUIRED_HEADERS = ("image_name", "MOS")


def read_koniq_table(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    raw = path.read_text(encoding="utf-8-sig")
    first = raw.splitlines()[0] if raw else ""
    delimiter = "\t" if first.count("\t") >= first.count(",") else ","
    reader = csv.DictReader(raw.splitlines(), delimiter=delimiter)
    headers = [h.strip() for h in (reader.fieldnames or []) if h]
    rows: list[dict[str, str]] = []
    for rec in reader:
        rows.append({(k or "").strip(): ("" if v is None else str(v).strip()) for k, v in rec.items()})
    return headers, rows


def validate_koniq_headers(headers: list[str], *, require_documented_set: bool = False) -> list[str]:
    present = {h.strip() for h in headers}
    errors: list[str] = []
    for name in REQUIRED_HEADERS:
        if name not in present:
            errors.append(f"Missing required KonIQ header {name!r}")
    if require_documented_set:
        missing = [h for h in DOCUMENTED_HEADERS if h not in present]
        if missing:
            errors.append(f"Official documented headers missing: {missing}")
    return errors


def import_koniq10k_rows(
    source_path: Path,
    *,
    mapping_path: Path | None = None,
    strict_scale: bool = True,
) -> tuple[list[dict[str, Any]], list[str]]:
    if mapping_path:
        cfg = load_mapping_config(mapping_path)
        key_col = str((cfg.get("columns") or {}).get("source_media_key") or "image_name")
        mos_col = str((cfg.get("columns") or {}).get("mos_quality_raw") or "MOS")
        mos_scale = str(cfg.get("mos_scale") or "1-5")
    else:
        key_col, mos_col, mos_scale = "image_name", "MOS", "1-5"

    headers, table = read_koniq_table(source_path)
    header_errors = validate_koniq_headers(headers)
    if header_errors:
        raise ValueError("; ".join(header_errors))

    warnings: list[str] = []
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, rec in enumerate(table, start=1):
        source_key = rec.get(key_col, "").strip()
        if not source_key:
            warnings.append(f"Row {index}: empty {key_col}, skipped")
            continue
        if source_key in seen:
            warnings.append(f"Row {index}: duplicate image_name {source_key}")
            continue
        seen.add(source_key)
        mos = parse_optional_float(rec.get(mos_col))
        if mos is None:
            warnings.append(f"{source_key}: MOS missing, not invented")
            mapped = None
        else:
            if strict_scale and not validate_raw_in_scale(mos, mos_scale):
                warnings.append(f"{source_key}: MOS {mos} outside documented scale {mos_scale}; raw kept, mapped skipped")
                mapped = None
            else:
                mapped = map_mos_to_1_5(mos, mos_scale)
        zscore = parse_optional_float(rec.get("MOS_zscore"))
        out.append(
            {
                "source_dataset": "KonIQ-10k",
                "source_media_key": source_key,
                "media_type": "photo",
                "label_provenance": "human_subjective",
                "mos_quality_raw": mos,
                "mos_scale": mos_scale,
                "mos_direction": "higher_is_better",
                "overall_mapped_1_5": mapped,
                "mos_zscore_raw": zscore,
                "mos_sd_raw": parse_optional_float(rec.get("SD")),
                "judgment_count": parse_optional_float(rec.get("c_total")),
                "not_individual_raters": True,
                "not_criterion_scores": True,
                "mos_zscore_not_acr": True,
            }
        )
    return out, warnings


def import_koniq10k(
    source_path: Path,
    mapping_path: Path | None = None,
    *,
    manifest_by_source_key: dict[str, dict[str, str]] | None = None,
    strict_scale: bool = True,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Return reference_labels.csv rows. MOS is aggregate ACR; attributes stay empty."""
    rows, warnings = import_koniq10k_rows(
        source_path, mapping_path=mapping_path, strict_scale=strict_scale
    )
    cfg = load_mapping_config(mapping_path, allow_placeholders=True) if mapping_path else {}
    media_id_template = str(cfg.get("media_id_template") or "KONIQ-{source_media_key_safe}")
    key_transform = cfg.get("filename_transform") or "basename"
    ref_rows: list[dict[str, Any]] = []
    for rec in rows:
        source_key = normalize_source_key(rec["source_media_key"], key_transform) or str(rec["source_media_key"])
        manifest_row = (manifest_by_source_key or {}).get(source_key) or (manifest_by_source_key or {}).get(
            str(rec["source_media_key"])
        ) or {}
        media_id = manifest_row.get("media_id") or apply_media_id_template(
            media_id_template, source_key, "KonIQ-10k"
        )
        mos = rec.get("mos_quality_raw")
        ref_rows.append(
            empty_reference_row(
                media_id=media_id,
                dataset_split=manifest_row.get("dataset_split") or "",
                media_type=manifest_row.get("media_type") or "photo",
                source_dataset="KonIQ-10k",
                source_media_key=str(rec["source_media_key"]),
                label_provenance="human_subjective",
                relative_path=manifest_row.get("relative_path") or "",
                mos_scale=str(rec.get("mos_scale") or "1-5"),
                attribute_scale="",
                mos_quality_raw="" if mos is None else str(mos),
                comparability_notes=(
                    "KonIQ-10k MOS is 5-point ACR aggregate. Not three ACCESS raters. "
                    "Not criterion scores. MOS_zscore is not ACR and is not mapped to 1-5."
                ),
            )
        )
    return ref_rows, warnings
