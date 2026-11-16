"""Load and validate JSON import mapping configs."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


PLACEHOLDER_MARK = "REPLACE_WITH_"


def mapping_placeholder_paths(value: Any, prefix: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).startswith("_"):
                continue
            found.extend(mapping_placeholder_paths(item, f"{prefix}.{key}" if prefix else str(key)))
    elif isinstance(value, list):
        for i, item in enumerate(value):
            found.extend(mapping_placeholder_paths(item, f"{prefix}[{i}]"))
    elif isinstance(value, str) and PLACEHOLDER_MARK in value:
        found.append(prefix or value)
    return found


def load_mapping_config(path: Path, *, allow_placeholders: bool = False) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Mapping config must be a JSON object")
    if not allow_placeholders:
        placeholders = mapping_placeholder_paths(data)
        if placeholders:
            raise ValueError(
                "Mapping still contains REPLACE_WITH_* placeholders: "
                + ", ".join(placeholders)
                + ". Inspect official metadata first; do not guess column names."
            )
    return data


def resolve_column(row: dict[str, Any] | Any, column_name: str | None) -> Any:
    if not column_name:
        return None
    if hasattr(row, "get"):
        return row.get(column_name)
    return None


def normalize_source_key(raw: Any, transform: str | None) -> str:
    s = str(raw or "").strip()
    if not s:
        return ""
    tf = (transform or "").strip().lower()
    if tf in ("strip_extension", "basename_no_ext"):
        return Path(s).stem
    if tf == "basename":
        return Path(s).name
    return s


def apply_media_id_template(template: str, source_key: str, source_dataset: str) -> str:
    out = template
    out = out.replace("{source_media_key}", source_key)
    out = out.replace("{source_dataset}", source_dataset)
    safe = re.sub(r"[^\w.\-]+", "_", source_key)
    out = out.replace("{source_media_key_safe}", safe)
    return out.strip()
