"""Import LIVE-VQC subjective MOS from MAT or CSV using configurable mapping."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from scipy.io import loadmat

from tools.quality_validation.importers.mapping_config import (
    apply_media_id_template,
    load_mapping_config,
    normalize_source_key,
    resolve_column,
)
from tools.quality_validation.reference_io import empty_reference_row
from tools.quality_validation.scale_mapping import parse_optional_float, validate_raw_in_scale


def _read_mat_table(source_path: Path, mat_cfg: dict[str, Any]) -> list[dict[str, Any]]:
    data = loadmat(source_path, squeeze_me=True, struct_as_record=False)
    score_var = mat_cfg.get("scores") or mat_cfg.get("mos_variable")
    name_var = mat_cfg.get("filenames") or mat_cfg.get("names_variable")
    if not score_var:
        raise ValueError("MAT mapping must specify 'scores' (or 'mos_variable')")
    scores = np.atleast_1d(data[score_var]).astype(float)
    if name_var and name_var in data:
        names = np.atleast_1d(data[name_var])
        records = []
        for i, sc in enumerate(scores):
            name = names[i] if i < len(names) else str(i)
            records.append({"source_media_key": str(name), "mos_quality_raw": float(sc)})
        return records
    return [{"source_media_key": str(i), "mos_quality_raw": float(sc)} for i, sc in enumerate(scores)]


def _read_csv_table(source_path: Path) -> pd.DataFrame:
    suffix = source_path.suffix.lower()
    sep = "\t" if suffix == ".tsv" else ","
    return pd.read_csv(source_path, sep=sep)


def import_live_vqc(
    source_path: Path,
    mapping_path: Path,
    *,
    manifest_by_source_key: dict[str, dict[str, str]] | None = None,
    strict_scale: bool = True,
) -> tuple[list[dict[str, Any]], list[str]]:
    cfg = load_mapping_config(mapping_path)
    source_dataset = str(cfg.get("source_dataset") or "LIVE-VQC")
    label_provenance = str(cfg.get("label_provenance") or "human_subjective")
    mos_scale = str(cfg.get("mos_scale") or "0-100")
    fmt = str(cfg.get("format") or source_path.suffix.lstrip(".")).lower()
    columns_map: dict[str, str] = dict(cfg.get("columns") or {})
    key_transform = cfg.get("filename_transform") or cfg.get("source_key_transform")
    media_id_template = str(cfg.get("media_id_template") or "vqc_{source_media_key_safe}")
    split_column = columns_map.pop("dataset_split", None) or cfg.get("dataset_split_column")

    warnings: list[str] = []
    raw_records: list[dict[str, Any]]

    if fmt == "mat" or source_path.suffix.lower() == ".mat":
        raw_records = _read_mat_table(source_path, cfg.get("mat") or cfg)
    elif fmt in ("csv", "tsv") or source_path.suffix.lower() in (".csv", ".tsv"):
        df = _read_csv_table(source_path)
        for field, src_col in columns_map.items():
            if src_col and src_col not in df.columns:
                raise ValueError(f"Missing source column {src_col!r}")
        raw_records = []
        for idx, series in df.iterrows():
            raw_row = series.to_dict()
            sk_col = columns_map.get("source_media_key")
            source_key = normalize_source_key(resolve_column(raw_row, sk_col), key_transform)
            mos_col = columns_map.get("mos_quality_raw")
            mos = parse_optional_float(resolve_column(raw_row, mos_col))
            raw_records.append(
                {
                    "source_media_key": source_key,
                    "mos_quality_raw": mos,
                    "dataset_split": resolve_column(raw_row, split_column) if split_column else None,
                    "_row_index": idx,
                }
            )
    else:
        raise ValueError(f"Unsupported LIVE-VQC format: {fmt}")

    rows: list[dict[str, Any]] = []
    for rec in raw_records:
        source_key = str(rec.get("source_media_key") or "").strip()
        if not source_key:
            warnings.append(f"Record {rec}: empty source_media_key, skipped")
            continue
        manifest_row = (manifest_by_source_key or {}).get(source_key) or {}
        media_id = manifest_row.get("media_id") or apply_media_id_template(
            media_id_template, source_key, source_dataset
        )
        split = manifest_row.get("dataset_split") or ""
        if rec.get("dataset_split"):
            split = str(rec["dataset_split"]).strip().lower()

        mos = rec.get("mos_quality_raw")
        if isinstance(mos, (int, float)):
            if strict_scale and not validate_raw_in_scale(float(mos), mos_scale):
                warnings.append(f"{source_key}: MOS {mos} outside {mos_scale}")
            mos_str = str(mos)
        else:
            mos_str = ""

        row = empty_reference_row(
            media_id=media_id,
            dataset_split=split,
            media_type=manifest_row.get("media_type") or "video",
            source_dataset=source_dataset,
            source_media_key=source_key,
            label_provenance=label_provenance,
            relative_path=manifest_row.get("relative_path") or "",
            mos_scale=mos_scale,
            attribute_scale="",
            mos_quality_raw=mos_str,
            comparability_notes="LIVE-VQC overall MOS only; per-criterion attrs unavailable.",
        )
        rows.append(row)

    return rows, warnings
