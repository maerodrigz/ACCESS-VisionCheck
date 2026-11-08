#!/usr/bin/env python3
"""Extract only the selected KonIQ-10k JPEGs from a local official ZIP. No download. No scoring."""

from __future__ import annotations

import argparse
import json
import sys
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.research_datasets import KONIQ_ROOT  # noqa: E402

JPEG_SUFFIXES = {".jpg", ".jpeg"}
RESOLUTIONS = ("1024x768", "512x384")
DEFAULT_PREVIEW = KONIQ_ROOT / "metadata" / "preview_report.json"
DEFAULT_IMAGES = KONIQ_ROOT / "images"
DEFAULT_REPORT = KONIQ_ROOT / "metadata" / "extraction_report.json"


class ExtractError(ValueError):
    """Unsafe or incomplete KonIQ ZIP extraction."""


def load_selected_filenames(preview_path: Path) -> list[str]:
    data = json.loads(preview_path.read_text(encoding="utf-8"))
    records = data.get("subset_records") or []
    names: list[str] = []
    seen: set[str] = set()
    for rec in records:
        key = str(rec.get("source_media_key") or "").strip()
        if not key:
            continue
        filename = Path(key).name
        if filename in seen:
            raise ExtractError(f"Duplicate selected filename in preview report: {filename}")
        seen.add(filename)
        names.append(filename)
    if not names:
        raise ExtractError(f"No subset_records with source_media_key in {preview_path}")
    return names


def zip_member_is_safe(name: str) -> bool:
    if not name or "\x00" in name:
        return False
    unified = name.replace("\\", "/")
    if unified.startswith("/") or unified.startswith("//"):
        return False
    if len(unified) >= 2 and unified[1] == ":":
        return False
    parts = Path(unified).parts
    if any(part in ("..", "") for part in parts):
        return False
    return True


def member_basename(name: str) -> str:
    return Path(name.replace("\\", "/")).name


def member_is_jpeg(name: str) -> bool:
    return Path(name).suffix.lower() in JPEG_SUFFIXES


def infer_resolution(*, zip_path: Path, member_names: list[str], requested: str) -> str:
    if requested in RESOLUTIONS:
        return requested
    from_name = ""
    zip_lower = zip_path.name.lower()
    for res in RESOLUTIONS:
        if res in zip_lower:
            from_name = res
            break
    dirs: set[str] = set()
    for name in member_names:
        for part in Path(name.replace("\\", "/")).parts[:-1]:
            if part in RESOLUTIONS:
                dirs.add(part)
    if requested == "auto":
        if from_name and dirs and from_name not in dirs and len(dirs) > 1:
            raise ExtractError(
                f"ZIP name suggests {from_name} but archive folders include {sorted(dirs)}. "
                "Pass --resolution 1024x768 or --resolution 512x384."
            )
        if from_name:
            return from_name
        if len(dirs) == 1:
            return next(iter(dirs))
        if len(dirs) > 1:
            raise ExtractError(
                f"Archive contains both resolutions {sorted(dirs)}. Pass --resolution 1024x768 or 512x384."
            )
        return "unknown"
    raise ExtractError(f"Unsupported resolution {requested!r}")


def filter_members_for_resolution(member_names: list[str], resolution: str) -> list[str]:
    if resolution not in RESOLUTIONS:
        return member_names
    in_res = [n for n in member_names if resolution in Path(n.replace("\\", "/")).parts]
    if in_res:
        return in_res
    return member_names


def inspect_zip(zip_path: Path) -> dict[str, Any]:
    if not zip_path.is_file():
        raise ExtractError(f"ZIP not found: {zip_path}")
    if not zipfile.is_zipfile(zip_path):
        raise ExtractError(f"Not a ZIP archive: {zip_path}")
    with zipfile.ZipFile(zip_path, "r") as zf:
        infos = zf.infolist()
        names = [i.filename for i in infos if not i.is_dir()]
        unsafe = [n for n in names if not zip_member_is_safe(n)]
        jpegs = [n for n in names if zip_member_is_safe(n) and member_is_jpeg(n)]
        parents: set[str] = set()
        for name in jpegs:
            parent = str(Path(name.replace("\\", "/")).parent).replace("\\", "/")
            if parent not in (".", ""):
                parents.add(parent)
    return {
        "zip_path": str(zip_path.resolve()),
        "zip_name": zip_path.name,
        "zip_size_bytes": zip_path.stat().st_size,
        "member_file_count": len(names),
        "jpeg_member_count": len(jpegs),
        "directory_prefixes": sorted(parents),
        "unsafe_member_count": len(unsafe),
        "unsafe_members_sample": unsafe[:10],
        "jpeg_members": jpegs,
        "all_file_members": names,
    }


def match_selected(
    *,
    selected: list[str],
    jpeg_members: list[str],
    resolution: str,
) -> dict[str, Any]:
    candidates = filter_members_for_resolution(jpeg_members, resolution)
    by_base: dict[str, list[str]] = {}
    for name in candidates:
        by_base.setdefault(member_basename(name), []).append(name)
    matches: dict[str, str] = {}
    missing: list[str] = []
    ambiguous: dict[str, list[str]] = {}
    for filename in selected:
        hits = by_base.get(filename) or []
        if len(hits) == 1:
            matches[filename] = hits[0]
        elif len(hits) > 1:
            ambiguous[filename] = hits
        else:
            missing.append(filename)
    return {
        "matches": matches,
        "missing": missing,
        "ambiguous": ambiguous,
        "candidate_jpeg_count": len(candidates),
    }


def estimate_extract_bytes(zip_path: Path, member_names: list[str]) -> dict[str, int]:
    with zipfile.ZipFile(zip_path, "r") as zf:
        infos = {i.filename: i for i in zf.infolist()}
        uncompressed = 0
        compressed = 0
        for name in member_names:
            info = infos[name]
            uncompressed += int(info.file_size)
            compressed += int(info.compress_size)
    return {"uncompressed_bytes": uncompressed, "compressed_bytes": compressed}


def destination_path(images_dir: Path, filename: str) -> Path:
    if Path(filename).name != filename or filename in (".", ".."):
        raise ExtractError(f"Selected name must be a basename: {filename}")
    root = images_dir.resolve()
    dest = (root / filename).resolve()
    try:
        dest.relative_to(root)
    except ValueError as exc:
        raise ExtractError(f"Refusing destination outside images dir: {filename}") from exc
    if dest.parent != root:
        raise ExtractError(f"Refusing nested destination: {filename}")
    return dest


@dataclass
class ExtractPlan:
    selected: list[str]
    resolution: str
    inspect: dict[str, Any]
    match: dict[str, Any]
    existing: list[str] = field(default_factory=list)
    size: dict[str, int] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok_to_extract(self) -> bool:
        return not self.errors and not self.match["missing"] and not self.match["ambiguous"]


def plan_extraction(
    *,
    zip_path: Path,
    preview_path: Path,
    images_dir: Path,
    resolution: str = "auto",
    overwrite: bool = False,
) -> ExtractPlan:
    selected = load_selected_filenames(preview_path)
    inspect = inspect_zip(zip_path)
    resolved = infer_resolution(
        zip_path=zip_path, member_names=inspect["jpeg_members"], requested=resolution
    )
    matched = match_selected(
        selected=selected, jpeg_members=inspect["jpeg_members"], resolution=resolved
    )
    existing = []
    for filename in matched["matches"]:
        dest = destination_path(images_dir, filename)
        if dest.exists():
            existing.append(filename)
    errors: list[str] = []
    if matched["missing"]:
        errors.append(f"{len(matched['missing'])} selected JPEG(s) missing from archive")
    if matched["ambiguous"]:
        errors.append(f"{len(matched['ambiguous'])} selected JPEG(s) have ambiguous duplicate matches")
    warnings: list[str] = []
    if inspect["unsafe_member_count"]:
        warnings.append(
            f"{inspect['unsafe_member_count']} unsafe ZIP member path(s) skipped and will not be extracted"
        )
    if existing and not overwrite:
        errors.append(f"{len(existing)} destination file(s) already exist; pass --overwrite to replace them")
    size = estimate_extract_bytes(zip_path, list(matched["matches"].values())) if matched["matches"] else {
        "uncompressed_bytes": 0,
        "compressed_bytes": 0,
    }
    return ExtractPlan(
        selected=selected,
        resolution=resolved,
        inspect=inspect,
        match=matched,
        existing=existing,
        size=size,
        errors=errors,
        warnings=warnings,
    )


def extract_matches(*, zip_path: Path, images_dir: Path, matches: dict[str, str], overwrite: bool) -> list[str]:
    images_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    with zipfile.ZipFile(zip_path, "r") as zf:
        for filename, member in matches.items():
            if not zip_member_is_safe(member):
                raise ExtractError(f"Unsafe ZIP member blocked: {member}")
            if member_basename(member) != filename:
                raise ExtractError(f"Member {member!r} does not match selected name {filename!r}")
            dest = destination_path(images_dir, filename)
            if dest.exists() and not overwrite:
                continue
            with zf.open(member, "r") as src:
                dest.write_bytes(src.read())
            written.append(filename)
    return written


def plan_to_report(plan: ExtractPlan, *, dry_run: bool, written: list[str] | None = None) -> dict[str, Any]:
    return {
        "dataset": "KonIQ-10k",
        "dry_run": dry_run,
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "archive_source": plan.inspect["zip_path"],
        "archive_name": plan.inspect["zip_name"],
        "archive_size_bytes": plan.inspect["zip_size_bytes"],
        "archive_resolution": plan.resolution,
        "archive_directory_prefixes": plan.inspect["directory_prefixes"],
        "archive_jpeg_member_count": plan.inspect["jpeg_member_count"],
        "selected_n": len(plan.selected),
        "selected_filenames": plan.selected,
        "matched_n": len(plan.match["matches"]),
        "matches": plan.match["matches"],
        "missing": plan.match["missing"],
        "ambiguous": plan.match["ambiguous"],
        "existing_destinations": plan.existing,
        "estimated_uncompressed_bytes": plan.size.get("uncompressed_bytes"),
        "estimated_compressed_bytes": plan.size.get("compressed_bytes"),
        "extracted_filenames": written or [],
        "extracted_n": len(written or []),
        "errors": plan.errors,
        "warnings": plan.warnings,
        "ok": plan.ok_to_extract if not dry_run else not plan.match["missing"] and not plan.match["ambiguous"],
    }


def write_report(report: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Extract selected KonIQ-10k JPEGs from a local ZIP")
    parser.add_argument("--zip", type=Path, required=True, help="Path to the official KonIQ-10k JPEG ZIP")
    parser.add_argument("--preview-report", type=Path, default=DEFAULT_PREVIEW)
    parser.add_argument("--images-dir", type=Path, default=DEFAULT_IMAGES)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--resolution", choices=("auto",) + RESOLUTIONS, default="auto")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing JPEGs in images/")
    args = parser.parse_args(argv)

    try:
        plan = plan_extraction(
            zip_path=args.zip,
            preview_path=args.preview_report,
            images_dir=args.images_dir,
            resolution=args.resolution,
            overwrite=args.overwrite,
        )
    except ExtractError as exc:
        payload = {"ok": False, "error": str(exc)}
        print(json.dumps(payload, indent=2))
        return 2

    if args.dry_run:
        report = plan_to_report(plan, dry_run=True)
        write_report(report, args.report)
        print(json.dumps(report, indent=2))
        if plan.match["missing"] or plan.match["ambiguous"]:
            return 2
        return 0

    if not plan.ok_to_extract:
        report = plan_to_report(plan, dry_run=False, written=[])
        write_report(report, args.report)
        print(json.dumps(report, indent=2))
        return 2

    written = extract_matches(
        zip_path=args.zip,
        images_dir=args.images_dir,
        matches=plan.match["matches"],
        overwrite=args.overwrite,
    )
    report = plan_to_report(plan, dry_run=False, written=written)
    write_report(report, args.report)
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
