"""Import SPAQ human scores from Excel or CSV using a configurable column mapping."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd

from tools.quality_validation.importers.mapping_config import (
    apply_media_id_template,
    load_mapping_config,
    normalize_source_key,
    resolve_column,
)
from tools.quality_validation.reference_io import empty_reference_row
from tools.quality_validation.scale_mapping import parse_optional_float, validate_raw_in_scale


def _read_table(source_path: Path) -> pd.DataFrame:
    suffix = source_path.suffix.lower()
    if suffix in (".csv", ".tsv"):
        sep = "\t" if suffix == ".tsv" else ","
        return pd.read_csv(source_path, sep=sep)
    if suffix in (".xlsx", ".xls"):
        try:
            return pd.read_excel(source_path, engine="openpyxl")
        except ImportError as exc:
            raise ImportError(
                "Reading .xlsx requires openpyxl. Install with: pip install openpyxl "
                "or export SPAQ scores to CSV and point --source at the CSV."
            ) from exc
    raise ValueError(f"Unsupported SPAQ source format: {suffix}")


def _validate_columns(df: pd.DataFrame, columns_map: dict[str, str]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    required_fields = ("source_media_key",)
    for field in required_fields:
        src_col = columns_map.get(field)
        if src_col and src_col not in df.columns:
            errors.append(f"Missing required source column {src_col!r} for {field}")
    for field, src_col in columns_map.items():
        if field in required_fields:
            continue
        if src_col and src_col not in df.columns:
            warnings.append(f"Missing optional source column {src_col!r} for {field}")
    return errors, warnings


def import_spaq(
    source_path: Path,
    mapping_path: Path,
    *,
    manifest_by_source_key: dict[str, dict[str, str]] | None = None,
    strict_scale: bool = True,
) -> tuple[list[dict[str, Any]], list[str]]:
    """
    Returns (reference_rows, warnings).
    manifest_by_source_key: optional map source_media_key -> {media_id, dataset_split, relative_path, media_type}
    """
    cfg = load_mapping_config(mapping_path)
    columns_map: dict[str, str] = dict(cfg.get("columns") or {})
    source_dataset = str(cfg.get("source_dataset") or "SPAQ")
    label_provenance = str(cfg.get("label_provenance") or "human_subjective")
    mos_scale = str(cfg.get("mos_scale") or "0-100")
    attribute_scale = str(cfg.get("attribute_scale") or mos_scale)
    key_transform = cfg.get("filename_transform") or cfg.get("source_key_transform")
    media_id_template = str(cfg.get("media_id_template") or "spaq_{source_media_key_safe}")
    split_column = columns_map.pop("dataset_split", None) or cfg.get("dataset_split_column")

    df = _read_table(source_path)
    col_errors, col_warnings = _validate_columns(df, {k: v for k, v in columns_map.items() if k != "dataset_split"})
    if col_errors:
        raise ValueError("; ".join(col_errors))

    warnings: list[str] = list(col_warnings)
    rows: list[dict[str, Any]] = []

    for idx, series in df.iterrows():
        raw_row = series.to_dict()
        source_key_col = columns_map.get("source_media_key") or cfg.get("source_media_key_column")
        source_key = normalize_source_key(resolve_column(raw_row, source_key_col), key_transform)
        if not source_key:
            warnings.append(f"Row {idx}: empty source_media_key, skipped")
            continue

        manifest_row = (manifest_by_source_key or {}).get(source_key) or {}
        media_id = manifest_row.get("media_id") or apply_media_id_template(
            media_id_template, source_key, source_dataset
        )

        split = manifest_row.get("dataset_split") or ""
        if split_column:
            split = str(resolve_column(raw_row, split_column) or "").strip().lower()
        if not split:
            warnings.append(f"Row {idx} ({source_key}): no dataset_split; leave empty or join manifest")

        def raw_field(field: str) -> str:
            col = columns_map.get(field)
            if col and col not in df.columns:
                return ""
            val = parse_optional_float(resolve_column(raw_row, col))
            if val is not None and strict_scale:
                scale = mos_scale if field == "mos_quality_raw" else attribute_scale
                if not validate_raw_in_scale(val, scale):
                    warnings.append(f"Row {idx} {field}={val} outside scale {scale}")
            return "" if val is None else str(val)

        row = empty_reference_row(
            media_id=media_id,
            dataset_split=split,
            media_type=manifest_row.get("media_type") or "photo",
            source_dataset=source_dataset,
            source_media_key=source_key,
            label_provenance=label_provenance,
            relative_path=manifest_row.get("relative_path") or "",
            mos_scale=mos_scale,
            attribute_scale=attribute_scale,
            mos_quality_raw=raw_field("mos_quality_raw"),
            attr_sharpness_raw=raw_field("attr_sharpness_raw"),
            attr_brightness_raw=raw_field("attr_brightness_raw"),
            attr_noisiness_raw=raw_field("attr_noisiness_raw"),
            attr_contrast_raw=raw_field("attr_contrast_raw"),
            attr_colorfulness_raw=raw_field("attr_colorfulness_raw"),
            comparability_notes="SPAQ human attributes; see comparisons.py for machine pairing.",
        )
        rows.append(row)

    return rows, warnings
