#!/usr/bin/env python3
"""Copy blinded INDVAL JPGs into ./images for Docker builds (no facilitator map)."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = (
    ROOT.parents[0]
    / "workspace"
    / "phase6a_human_validation"
    / "rater_pack"
    / "images"
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC)
    ap.add_argument("--dst", type=Path, default=ROOT / "images")
    args = ap.parse_args()
    if not args.src.is_dir():
        raise SystemExit(f"Missing source images: {args.src}")
    args.dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for src in sorted(args.src.glob("INDVAL-*.jpg")):
        shutil.copy2(src, args.dst / src.name)
        n += 1
    if n != 100:
        raise SystemExit(f"Expected 100 images, staged {n}")
    print(f"Staged {n} images -> {args.dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
