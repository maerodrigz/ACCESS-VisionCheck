#!/usr/bin/env python3
"""Import SPAQ or LIVE-VQC metadata into reference_labels.csv."""

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

from tools.quality_validation.dataset import load_manifest  # noqa: E402
from tools.quality_validation.importers.koniq10k import import_koniq10k  # noqa: E402
from tools.quality_validation.importers.live_vqc import import_live_vqc  # noqa: E402
from tools.quality_validation.importers.spaq import import_spaq  # noqa: E402
from tools.quality_validation.manifest_validation import manifest_lookup_by_source_key  # noqa: E402
from tools.quality_validation.reference_io import write_reference_labels  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Import external dataset reference labels")
    parser.add_argument("--dataset", choices=("spaq", "live_vqc", "koniq10k"), required=True)
    parser.add_argument("--source", type=Path, required=True, help="Official scores file (xlsx/csv/mat)")
    parser.add_argument("--mapping", type=Path, required=True, help="JSON column mapping config")
    parser.add_argument("--output", type=Path, required=True, help="reference_labels.csv path")
    parser.add_argument("--dataset-root", type=Path, default=None, help="Pilot dataset root")
    parser.add_argument("--manifest", type=Path, default=None, help="Manifest CSV for split/id join")
    parser.add_argument("--source-key-transform", default="strip_extension")
    parser.add_argument("--no-strict-scale", action="store_true")
    args = parser.parse_args(argv)

    manifest_map: dict[str, dict[str, str]] | None = None
    if args.manifest and args.dataset_root:
        rows = load_manifest(args.manifest.resolve(), args.dataset_root.resolve())
        manifest_map = manifest_lookup_by_source_key(rows, transform=args.source_key_transform)
    elif args.manifest and not args.dataset_root:
        print("Warning: --manifest without --dataset-root; split/id join skipped", file=sys.stderr)

    strict = not args.no_strict_scale
    if args.dataset == "spaq":
        ref_rows, warnings = import_spaq(
            args.source.resolve(),
            args.mapping.resolve(),
            manifest_by_source_key=manifest_map,
            strict_scale=strict,
        )
    elif args.dataset == "koniq10k":
        ref_rows, warnings = import_koniq10k(
            args.source.resolve(),
            args.mapping.resolve(),
            manifest_by_source_key=manifest_map,
            strict_scale=strict,
        )
    else:
        ref_rows, warnings = import_live_vqc(
            args.source.resolve(),
            args.mapping.resolve(),
            manifest_by_source_key=manifest_map,
            strict_scale=strict,
        )

    write_reference_labels(ref_rows, args.output.resolve())
    print(f"Wrote {len(ref_rows)} reference rows to {args.output.resolve()}")
    for w in warnings:
        print(f"Warning: {w}", file=sys.stderr)

    sidecar = args.output.with_suffix(".import_meta.json")
    sidecar.write_text(
        json.dumps(
            {
                "dataset": args.dataset,
                "source": str(args.source.resolve()),
                "mapping": str(args.mapping.resolve()),
                "row_count": len(ref_rows),
                "warnings": warnings,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
