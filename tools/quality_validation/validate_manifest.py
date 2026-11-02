#!/usr/bin/env python3
"""Validate pilot manifest: unique IDs, hashes, split leakage, reference alignment."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.manifest_validation import validate_manifest  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate dataset manifest and optional reference labels")
    parser.add_argument("--dataset-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reference-labels", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=None, help="JSON report path")
    args = parser.parse_args(argv)

    report = validate_manifest(
        args.dataset_root.resolve(),
        args.manifest.resolve(),
        reference_labels_path=args.reference_labels.resolve() if args.reference_labels else None,
    )

    payload = {
        "ok": report.ok,
        "media_count": report.media_count,
        "errors": report.errors,
        "warnings": report.warnings,
        "duplicate_media_ids": report.duplicate_media_ids,
        "duplicate_hashes": report.duplicate_hashes,
        "cross_split_hash_collisions": report.cross_split_hash_collisions,
    }
    text = json.dumps(payload, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
        print(f"Wrote report to {args.output.resolve()}")
    else:
        print(text)

    if not report.ok:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
