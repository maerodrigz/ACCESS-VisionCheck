"""Load and write reference_labels.csv."""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Any

import pandas as pd

from tools.quality_validation.reference_schema import REFERENCE_LABEL_COLUMNS
from tools.quality_validation.scale_mapping import apply_derived_mapped_columns, parse_optional_float


def empty_reference_row(**kwargs: Any) -> dict[str, Any]:
    row = {col: "" for col in REFERENCE_LABEL_COLUMNS}
    row.update(kwargs)
    return apply_derived_mapped_columns(row)


def write_reference_labels(rows: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized: list[dict[str, Any]] = []
    for raw in rows:
        row = {col: raw.get(col, "") for col in REFERENCE_LABEL_COLUMNS}
        normalized.append(apply_derived_mapped_columns(row))
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(REFERENCE_LABEL_COLUMNS), extrasaction="ignore")
        writer.writeheader()
        for row in normalized:
            writer.writerow({k: row.get(k, "") for k in REFERENCE_LABEL_COLUMNS})


def load_reference_labels(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    if "media_id" not in df.columns:
        raise ValueError("reference_labels.csv must include media_id")
    for col in REFERENCE_LABEL_COLUMNS:
        if col not in df.columns:
            df[col] = ""
    return df


def reference_mapped_value(row: dict[str, Any], column: str) -> float | None:
    v = parse_optional_float(row.get(column))
    if v is None:
        return None
    if 1.0 <= v <= 5.0:
        return v
    return None
