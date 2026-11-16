#!/usr/bin/env python3
"""Export locked criteria.py rubric into cloud/shared + worker JS (no hand edits)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.criteria import (  # noqa: E402
    CRITERIA,
    CRITERION_IDS,
    IMAGE_IDS,
    NA_LABEL,
    SCALE_LABELS,
)


def main() -> int:
    data = {
        "criteria": list(CRITERIA),
        "scale_labels": {str(k): v for k, v in SCALE_LABELS.items()},
        "na_label": dict(NA_LABEL),
        "criterion_ids": list(CRITERION_IDS),
        "image_ids": list(IMAGE_IDS),
        "n_images": len(IMAGE_IDS),
    }
    shared = ROOT / "cloud" / "shared"
    shared.mkdir(parents=True, exist_ok=True)
    (shared / "rubric.json").write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    js_path = ROOT / "cloud" / "worker" / "src" / "rubric_data.js"
    js_path.write_text(
        "/** AUTO-GENERATED from app/criteria.py — do not hand-edit. */\n"
        f"export const RUBRIC = {json.dumps(data, ensure_ascii=False, indent=2)};\n",
        encoding="utf-8",
    )
    print(f"Wrote {shared / 'rubric.json'} and {js_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
