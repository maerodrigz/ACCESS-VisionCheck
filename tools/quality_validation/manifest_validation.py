"""Validate dataset manifest split integrity and reference alignment."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from pathlib import Path

from tools.quality_validation.dataset import ManifestRow, load_manifest
from tools.quality_validation.evaluate import media_type_for_path as infer_type


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


@dataclass
class ManifestValidationReport:
    ok: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    media_count: int = 0
    duplicate_media_ids: list[str] = field(default_factory=list)
    duplicate_hashes: list[dict[str, str]] = field(default_factory=list)
    cross_split_hash_collisions: list[dict[str, str]] = field(default_factory=list)


def _check_media_type(path: Path, expected: str) -> bool:
    inferred = infer_type(path)
    if inferred is None:
        return True
    return inferred == expected


def validate_manifest(
    dataset_root: Path,
    manifest_path: Path,
    *,
    reference_labels_path: Path | None = None,
) -> ManifestValidationReport:
    report = ManifestValidationReport(ok=True)
    try:
        rows = load_manifest(manifest_path, dataset_root)
    except (ValueError, FileNotFoundError) as exc:
        report.ok = False
        report.errors.append(str(exc))
        return report

    report.media_count = len(rows)
    id_counts: dict[str, list[int]] = {}
    hash_to_locs: dict[str, list[tuple[str, str, str]]] = {}

    for i, row in enumerate(rows):
        id_counts.setdefault(row.media_id, []).append(i)
        full = (dataset_root / row.relative_path).resolve()
        if not _check_media_type(full, row.media_type):
            report.errors.append(
                f"{row.media_id}: media_type={row.media_type} inconsistent with file {full.name}"
            )
        digest = file_sha256(full)
        hash_to_locs.setdefault(digest, []).append((row.media_id, row.dataset_split, row.relative_path))

    for mid, indices in id_counts.items():
        if len(indices) > 1:
            report.duplicate_media_ids.append(mid)
            report.errors.append(f"Duplicate media_id {mid!r} ({len(indices)} rows)")

    for digest, locs in hash_to_locs.items():
        if len(locs) > 1:
            report.duplicate_hashes.append(
                {"sha256": digest, "locations": "; ".join(f"{a}|{b}|{c}" for a, b, c in locs)}
            )
            splits = {loc[1] for loc in locs}
            if "dev" in splits and "held_out" in splits:
                report.cross_split_hash_collisions.append(
                    {"sha256": digest, "locations": "; ".join(f"{a}|{b}|{c}" for a, b, c in locs)}
                )
                report.errors.append(
                    f"Same file content (sha256 {digest[:12]}...) in both dev and held_out"
                )
            elif len(locs) > 1:
                report.warnings.append(
                    f"Duplicate content hash {digest[:12]}... across {len(locs)} manifest rows"
                )

    if reference_labels_path and reference_labels_path.is_file():
        import pandas as pd

        ref = pd.read_csv(reference_labels_path, dtype=str, keep_default_na=False)
        manifest_ids = {r.media_id for r in rows}
        ref_ids = set(ref["media_id"].astype(str).str.strip()) - {""}
        missing_ref = manifest_ids - ref_ids
        orphan_ref = ref_ids - manifest_ids
        for mid in sorted(missing_ref):
            report.warnings.append(f"Manifest media_id {mid!r} has no reference_labels row")
        for mid in sorted(orphan_ref):
            report.warnings.append(f"reference_labels media_id {mid!r} not in manifest")

        if "source_media_key" in ref.columns and "relative_path" in ref.columns:
            by_id = {r.media_id: r for r in rows}
            for _, rrow in ref.iterrows():
                mid = str(rrow.get("media_id", "")).strip()
                if mid not in by_id:
                    continue
                m = by_id[mid]
                rel = str(rrow.get("relative_path", "")).strip()
                if rel and rel != m.relative_path:
                    report.errors.append(
                        f"{mid}: reference relative_path {rel!r} != manifest {m.relative_path!r}"
                    )
                sk = str(rrow.get("source_media_key", "")).strip()
                if sk and Path(m.relative_path).stem != sk and Path(m.relative_path).name != sk:
                    if sk not in m.relative_path:
                        report.warnings.append(
                            f"{mid}: source_media_key {sk!r} may not match file {m.relative_path!r}"
                        )

    if report.errors:
        report.ok = False
    return report


def manifest_lookup_by_source_key(rows: list[ManifestRow], *, transform: str = "strip_extension") -> dict[str, dict[str, str]]:
    from tools.quality_validation.importers.mapping_config import normalize_source_key

    out: dict[str, dict[str, str]] = {}
    for row in rows:
        name = Path(row.relative_path).name
        key = normalize_source_key(name, transform)
        out[key] = {
            "media_id": row.media_id,
            "dataset_split": row.dataset_split,
            "relative_path": row.relative_path,
            "media_type": row.media_type,
        }
        stem = Path(row.relative_path).stem
        if stem != key:
            out.setdefault(stem, out[key])
    return out
