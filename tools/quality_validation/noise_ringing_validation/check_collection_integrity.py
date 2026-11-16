#!/usr/bin/env python3
"""Lightweight integrity checks for the Noise/Ringing preliminary collection.

Does not score images or run machine-human validation.
"""

from __future__ import annotations

import csv
import hashlib
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMAGES = ROOT / "images"
MANIFEST = ROOT / "noise_ringing_image_manifest.csv"
RATINGS = [
    ROOT / "ratings" / "R1_noise_ringing_ratings.csv",
    ROOT / "ratings" / "R2_noise_ringing_ratings.csv",
    ROOT / "ratings" / "R3_noise_ringing_ratings.csv",
]
EXPECTED_IDS = [f"NR{i:03d}" for i in range(1, 16)]
MACHINE_SCORE_COLUMNS = {
    "machine_noise",
    "machine_ringing",
    "enet_noise",
    "enet_ringing",
    "classical_noise",
    "classical_ringing",
    "soft_score",
    "overall_score",
    "badge",
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        return []
    with path.open(encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    rows = load_manifest(MANIFEST)
    present_ids = [r.get("media_id", "").strip() for r in rows]
    unique_ids = set(present_ids)

    print("=== Noise/Ringing collection integrity ===")
    print(f"Manifest rows: {len(rows)}")
    print(f"Target complete set: 15 unique IDs")

    incomplete = [mid for mid in EXPECTED_IDS if mid not in unique_ids]
    if incomplete:
        warnings.append(
            f"INCOMPLETE collection: {len(unique_ids)}/15 ready; missing {', '.join(incomplete)}"
        )
    else:
        if len(present_ids) != 15 or len(unique_ids) != 15:
            errors.append("Complete collection must have exactly 15 unique media_id values")
        else:
            print("OK: exactly 15 unique media_id values when complete")

    # Duplicate IDs in manifest
    counts = Counter(present_ids)
    dup_ids = [k for k, v in counts.items() if k and v > 1]
    if dup_ids:
        errors.append(f"Duplicate media_id in manifest: {dup_ids}")

    digests: dict[str, str] = {}
    for r in rows:
        mid = r.get("media_id", "").strip()
        rel = r.get("relative_path", "").strip()
        expected_sha = (r.get("sha256") or "").strip().lower()
        path = ROOT / rel if rel else None

        if not rel:
            errors.append(f"{mid}: missing relative_path")
            continue
        if path is None or not path.is_file():
            errors.append(f"{mid}: file missing at {rel}")
            continue

        # Openability via OpenCV or PIL if available; else raw bytes header check
        openable = False
        detail = ""
        try:
            import cv2
            import numpy as np

            data = path.read_bytes()
            arr = np.frombuffer(data, dtype=np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is None:
                detail = "cv2.imdecode returned None"
            else:
                openable = True
                h, w = img.shape[:2]
                detail = f"{w}x{h}"
        except Exception as exc:  # noqa: BLE001
            # Fallback: JPEG/PNG magic
            data = path.read_bytes()
            if data[:3] == b"\xff\xd8\xff" or data[:8] == b"\x89PNG\r\n\x1a\n":
                openable = True
                detail = f"magic-ok ({exc})"
            else:
                detail = str(exc)

        if not openable:
            errors.append(f"{mid}: cannot open image ({detail})")
        else:
            print(f"OK open {mid}: {detail}")

        actual = sha256_file(path)
        if expected_sha and actual != expected_sha:
            errors.append(f"{mid}: sha256 mismatch manifest={expected_sha} actual={actual}")
        elif expected_sha:
            print(f"OK sha256 {mid}")
        else:
            warnings.append(f"{mid}: manifest missing sha256")

        if actual in digests:
            errors.append(f"Duplicate file content: {mid} matches {digests[actual]} (sha256={actual})")
        else:
            digests[actual] = mid

    # Orphan files in images/
    if IMAGES.is_dir():
        for p in sorted(IMAGES.iterdir()):
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
                stem = p.stem.upper()
                if stem not in unique_ids and not any(
                    r.get("filename") == p.name for r in rows
                ):
                    warnings.append(f"Orphan image file not in manifest: {p.name}")

    # Rating CSV checks
    for rating_path in RATINGS:
        if not rating_path.is_file():
            errors.append(f"Missing rating CSV: {rating_path.name}")
            continue
        with rating_path.open(encoding="utf-8", newline="") as fh:
            rrows = list(csv.DictReader(fh))
        cols = set(rrows[0].keys()) if rrows else set()
        bad = sorted(cols & MACHINE_SCORE_COLUMNS)
        if bad:
            errors.append(f"{rating_path.name}: machine score columns present: {bad}")
        ids = [r.get("media_id", "").strip() for r in rrows]
        if set(ids) != set(EXPECTED_IDS):
            errors.append(
                f"{rating_path.name}: media_id set mismatch "
                f"(have {len(set(ids))}, expected NR001–NR015)"
            )
        else:
            print(f"OK rating IDs: {rating_path.name}")

        # Ensure noise/ringing cells are blank (not prefilled with machine/human scores)
        for r in rrows:
            for col in ("noise", "ringing_artifacts"):
                val = (r.get(col) or "").strip()
                if val not in {"", "N/A"}:
                    # Allow only empty for blank sheets; N/A would be odd prefilled
                    errors.append(
                        f"{rating_path.name} {r.get('media_id')}: {col} prefilled with {val!r}"
                    )

    print("---")
    if warnings:
        print("INCOMPLETE / WARNINGS:")
        for w in warnings:
            print(" ", w)
    if errors:
        print("INVALID / ERRORS:")
        for e in errors:
            print(" ", e)
        return 2

    if incomplete:
        print("RESULT: collection incomplete but no hard invalid errors")
        return 1

    print("RESULT: collection complete and integrity checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
