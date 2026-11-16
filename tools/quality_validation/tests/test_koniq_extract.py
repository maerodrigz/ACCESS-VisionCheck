"""Safe KonIQ ZIP subset extraction tests (synthetic archive only)."""

from __future__ import annotations

import io
import json
import sys
import zipfile
from pathlib import Path

from PIL import Image

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.koniq_extract import (  # noqa: E402
    ExtractError,
    extract_matches,
    inspect_zip,
    load_selected_filenames,
    main as extract_main,
    match_selected,
    plan_extraction,
    zip_member_is_safe,
)


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (16, 12), color=(80, 10, 10)).save(buf, format="JPEG")
    return buf.getvalue()


def _preview(path: Path, names: list[str]) -> None:
    path.write_text(
        json.dumps(
            {
                "dataset": "KonIQ-10k",
                "subset_records": [{"source_media_key": n, "media_id": f"KONIQ-{i:03d}"} for i, n in enumerate(names, 1)],
            }
        ),
        encoding="utf-8",
    )


def _write_zip(path: Path, members: dict[str, bytes]) -> None:
    with zipfile.ZipFile(path, "w") as zf:
        for name, data in members.items():
            zf.writestr(name, data)


def test_load_selected_from_preview(tmp_path: Path) -> None:
    preview = tmp_path / "preview_report.json"
    _preview(preview, ["a.jpg", "b.jpg"])
    assert load_selected_filenames(preview) == ["a.jpg", "b.jpg"]


def test_zip_slip_members_rejected() -> None:
    assert zip_member_is_safe("1024x768/a.jpg")
    assert not zip_member_is_safe("../evil.jpg")
    assert not zip_member_is_safe("1024x768/../../evil.jpg")
    assert not zip_member_is_safe("/tmp/a.jpg")
    assert not zip_member_is_safe("C:/windows/a.jpg")


def test_inspect_and_match_1024_archive(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "koniq10k_1024x768.zip"
    _write_zip(
        archive,
        {
            "1024x768/a.jpg": jpeg,
            "1024x768/b.jpg": jpeg,
            "1024x768/c.jpg": jpeg,
        },
    )
    info = inspect_zip(archive)
    assert info["jpeg_member_count"] == 3
    assert "1024x768" in info["directory_prefixes"]
    matched = match_selected(
        selected=["a.jpg", "b.jpg"],
        jpeg_members=info["jpeg_members"],
        resolution="1024x768",
    )
    assert matched["missing"] == []
    assert matched["matches"]["a.jpg"] == "1024x768/a.jpg"


def test_ambiguous_duplicate_rejected(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "mixed.zip"
    _write_zip(archive, {"1024x768/a.jpg": jpeg, "extra/a.jpg": jpeg})
    info = inspect_zip(archive)
    matched = match_selected(selected=["a.jpg"], jpeg_members=info["jpeg_members"], resolution="unknown")
    assert "a.jpg" in matched["ambiguous"]


def test_resolution_filter_disambiguates(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "both.zip"
    _write_zip(archive, {"1024x768/a.jpg": jpeg, "512x384/a.jpg": jpeg})
    info = inspect_zip(archive)
    matched = match_selected(selected=["a.jpg"], jpeg_members=info["jpeg_members"], resolution="512x384")
    assert matched["matches"]["a.jpg"] == "512x384/a.jpg"
    assert not matched["ambiguous"]


def test_missing_selected_file(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "koniq10k_512x384.zip"
    _write_zip(archive, {"512x384/a.jpg": jpeg})
    info = inspect_zip(archive)
    matched = match_selected(selected=["a.jpg", "missing.jpg"], jpeg_members=info["jpeg_members"], resolution="512x384")
    assert matched["missing"] == ["missing.jpg"]


def test_dry_run_and_extract_cli(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "1024x768.zip"
    _write_zip(archive, {"1024x768/a.jpg": jpeg, "1024x768/b.jpg": jpeg, "readme.txt": b"nope"})
    preview = tmp_path / "preview_report.json"
    _preview(preview, ["a.jpg", "b.jpg"])
    images = tmp_path / "images"
    report = tmp_path / "extraction_report.json"
    code = extract_main(
        [
            "--zip",
            str(archive),
            "--preview-report",
            str(preview),
            "--images-dir",
            str(images),
            "--report",
            str(report),
            "--dry-run",
        ]
    )
    assert code == 0
    payload = json.loads(report.read_text(encoding="utf-8"))
    assert payload["dry_run"] is True
    assert payload["archive_resolution"] == "1024x768"
    assert payload["matched_n"] == 2
    assert payload["estimated_uncompressed_bytes"] > 0
    assert not list(images.glob("*.jpg"))

    code = extract_main(
        [
            "--zip",
            str(archive),
            "--preview-report",
            str(preview),
            "--images-dir",
            str(images),
            "--report",
            str(report),
        ]
    )
    assert code == 0
    assert (images / "a.jpg").is_file()
    assert (images / "b.jpg").is_file()
    assert not (images / "readme.txt").exists()
    done = json.loads(report.read_text(encoding="utf-8"))
    assert done["extracted_n"] == 2
    assert done["dry_run"] is False


def test_overwrite_requires_flag(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "1024x768.zip"
    _write_zip(archive, {"a.jpg": jpeg})
    preview = tmp_path / "preview_report.json"
    _preview(preview, ["a.jpg"])
    images = tmp_path / "images"
    images.mkdir()
    (images / "a.jpg").write_bytes(b"old")
    plan = plan_extraction(
        zip_path=archive,
        preview_path=preview,
        images_dir=images,
        resolution="auto",
        overwrite=False,
    )
    assert not plan.ok_to_extract
    assert "a.jpg" in plan.existing
    extract_matches(zip_path=archive, images_dir=images, matches=plan.match["matches"], overwrite=False)
    assert (images / "a.jpg").read_bytes() == b"old"
    extract_matches(zip_path=archive, images_dir=images, matches=plan.match["matches"], overwrite=True)
    assert (images / "a.jpg").read_bytes() != b"old"


def test_zip_slip_not_extracted(tmp_path: Path) -> None:
    jpeg = _jpeg_bytes()
    archive = tmp_path / "bad.zip"
    _write_zip(archive, {"1024x768/a.jpg": jpeg, "../escape.jpg": jpeg})
    preview = tmp_path / "preview_report.json"
    _preview(preview, ["a.jpg"])
    images = tmp_path / "images"
    plan = plan_extraction(zip_path=archive, preview_path=preview, images_dir=images, overwrite=True)
    assert plan.inspect["unsafe_member_count"] >= 1
    assert any("unsafe" in w for w in plan.warnings)
    assert plan.ok_to_extract
    written = extract_matches(zip_path=archive, images_dir=images, matches=plan.match["matches"], overwrite=True)
    assert written == ["a.jpg"]
    assert not (tmp_path / "escape.jpg").exists()


def test_real_preview_report_has_forty_names() -> None:
    preview = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "metadata" / "preview_report.json"
    if not preview.is_file():
        return
    names = load_selected_filenames(preview)
    assert len(names) == 40
    assert names[0] == "5205048751.jpg"
    assert len(set(names)) == 40


def test_duplicate_preview_names_rejected(tmp_path: Path) -> None:
    preview = tmp_path / "preview_report.json"
    _preview(preview, ["a.jpg", "a.jpg"])
    try:
        load_selected_filenames(preview)
        raise AssertionError("expected ExtractError")
    except ExtractError as exc:
        assert "Duplicate" in str(exc)
