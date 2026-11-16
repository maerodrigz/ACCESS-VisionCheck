"""Tests for reference import, scale mapping, manifest validation, reference analysis."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest
from PIL import Image
from scipy.io import savemat

_FIX = Path(__file__).resolve().parent / "fixtures"
_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.analyze_reference import analyze_reference_split  # noqa: E402
from tools.quality_validation.importers.live_vqc import import_live_vqc  # noqa: E402
from tools.quality_validation.importers.spaq import import_spaq  # noqa: E402
from tools.quality_validation.manifest_validation import validate_manifest  # noqa: E402
from tools.quality_validation.reference_io import load_reference_labels, write_reference_labels  # noqa: E402
from tools.quality_validation.scale_mapping import (  # noqa: E402
    map_linear_to_1_5,
    map_noisiness_raw_to_noise_quality_1_5,
)


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), color=(100, 100, 100)).save(buf, format="JPEG")
    return buf.getvalue()


def test_scale_mapping_preserves_inversion_for_noisiness() -> None:
    high_noise = map_noisiness_raw_to_noise_quality_1_5(90.0)
    low_noise = map_noisiness_raw_to_noise_quality_1_5(10.0)
    assert high_noise is not None and low_noise is not None
    assert low_noise > high_noise


def test_spaq_import_missing_attributes_not_fabricated() -> None:
    rows, _warnings = import_spaq(
        _FIX / "spaq_synthetic.csv",
        _FIX / "import_mapping.spaq.test.json",
        manifest_by_source_key={
            "img_c": {
                "media_id": "spaq_img_c",
                "dataset_split": "dev",
                "relative_path": "dev/photos/img_c.jpg",
                "media_type": "photo",
            }
        },
    )
    by_key = {r["source_media_key"]: r for r in rows}
    c = by_key["img_c"]
    assert c["attr_sharpness_raw"] == ""
    assert c["attr_colorfulness_raw"] == ""
    assert "sharpness" in c["missing_dimensions"] or "colorfulness" in c["missing_dimensions"]
    assert c["sharpness_blur_mapped_1_5"] == ""


def test_spaq_import_invalid_scale_warning() -> None:
    bad_csv = _FIX / "_bad_scale.csv"
    bad_csv.write_text("image_name,MOS\nx,150\n", encoding="utf-8")
    try:
        _rows, warnings = import_spaq(
            bad_csv,
            _FIX / "import_mapping.spaq.test.json",
            strict_scale=True,
        )
        assert any("outside scale" in w for w in warnings)
    finally:
        bad_csv.unlink(missing_ok=True)


def test_spaq_import_missing_column_raises() -> None:
    bad_map = _FIX / "_bad_map.json"
    bad_map.write_text(
        json.dumps(
            {
                "columns": {"source_media_key": "NOT_AN_IMAGE_COLUMN", "mos_quality_raw": "MOS"},
            }
        ),
        encoding="utf-8",
    )
    try:
        with pytest.raises(ValueError, match="Missing required source column"):
            import_spaq(_FIX / "spaq_synthetic.csv", bad_map)
    finally:
        bad_map.unlink(missing_ok=True)


def test_live_vqc_csv_import() -> None:
    rows, _ = import_live_vqc(
        _FIX / "live_vqc_synthetic.csv",
        _FIX / "import_mapping.live_vqc.test.json",
        manifest_by_source_key={
            "clip_01": {
                "media_id": "vqc_clip_01",
                "dataset_split": "held_out",
                "relative_path": "held_out/videos/clip_01.mp4",
                "media_type": "video",
            }
        },
    )
    assert len(rows) == 2
    one = next(r for r in rows if r["source_media_key"] == "clip_01")
    assert one["media_id"] == "vqc_clip_01"
    assert one["dataset_split"] == "held_out"
    assert one["mos_quality_raw"] == "72.0"
    assert one["attr_sharpness_raw"] == ""


def test_live_vqc_mat_import(tmp_path: Path) -> None:
    mat_path = tmp_path / "scores.mat"
    savemat(
        mat_path,
        {"mos": [70.0, 55.0], "names": ["v1.mp4", "v2.mp4"]},
    )
    mapping = {
        "source_dataset": "LIVE-VQC",
        "label_provenance": "human_subjective",
        "mos_scale": "0-100",
        "format": "mat",
        "mat": {"scores": "mos", "filenames": "names"},
        "media_id_template": "vqc_{source_media_key_safe}",
    }
    map_file = tmp_path / "map.json"
    map_file.write_text(json.dumps(mapping), encoding="utf-8")
    rows, _ = import_live_vqc(mat_path, map_file)
    assert len(rows) == 2
    assert rows[0]["mos_quality_raw"] in ("70.0", "70")


def test_manifest_duplicate_media_id(tmp_path: Path) -> None:
    root = tmp_path / "ds"
    (root / "dev" / "photos").mkdir(parents=True)
    (root / "dev" / "photos" / "a.jpg").write_bytes(_jpeg_bytes())
    (root / "dev" / "photos" / "b.jpg").write_bytes(_jpeg_bytes())
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "media_id,relative_path,media_type,dataset_split\n"
        "dup,dev/photos/a.jpg,photo,dev\n"
        "dup,dev/photos/b.jpg,photo,dev\n",
        encoding="utf-8",
    )
    report = validate_manifest(root, manifest)
    assert not report.ok
    assert "dup" in report.duplicate_media_ids


def test_manifest_cross_split_hash_collision(tmp_path: Path) -> None:
    root = tmp_path / "ds"
    content = _jpeg_bytes()
    (root / "dev" / "photos").mkdir(parents=True)
    (root / "held_out" / "photos").mkdir(parents=True)
    (root / "dev" / "photos" / "a.jpg").write_bytes(content)
    (root / "held_out" / "photos" / "b.jpg").write_bytes(content)
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "media_id,relative_path,media_type,dataset_split\n"
        "a,dev/photos/a.jpg,photo,dev\n"
        "b,held_out/photos/b.jpg,photo,held_out\n",
        encoding="utf-8",
    )
    report = validate_manifest(root, manifest)
    assert not report.ok
    assert report.cross_split_hash_collisions


def test_reference_roundtrip_and_analysis() -> None:
    manifest = {
        "img_a": {"media_id": "spaq_a", "dataset_split": "dev", "media_type": "photo", "relative_path": ""},
        "img_b": {"media_id": "spaq_b", "dataset_split": "dev", "media_type": "photo", "relative_path": ""},
        "img_c": {"media_id": "spaq_c", "dataset_split": "dev", "media_type": "photo", "relative_path": ""},
    }
    rows, _ = import_spaq(
        _FIX / "spaq_synthetic.csv",
        _FIX / "import_mapping.spaq.test.json",
        manifest_by_source_key=manifest,
    )
    out = Path(__file__).parent / "_tmp_ref.csv"
    try:
        write_reference_labels(rows, out)
        ref = load_reference_labels(out)
        machine = [
            {
                "media_id": r["media_id"],
                "dataset_split": "dev",
                "analysis_status": "ok",
                "engine": "opencv",
                "media_type": "photo",
                "overall_score": 4.0,
                "criterion_scores": {"Sharpness": 4.2, "Noise": 3.8, "Brightness": 3.5, "Contrast": 3.6},
            }
            for r in rows
            if r.get("media_id")
        ]
        report = analyze_reference_split(ref, machine, split="dev", engine="opencv")
        assert "overall_documentation" in report["validated_criterion_metrics"]
        assert "sharpness_blur" in report["exploratory_proxy_metrics"]
        assert report["exploratory_proxy_metrics"]["sharpness_blur"].get("validation_disclaimer")
        assert "color_balance" in report["not_comparable"]
    finally:
        out.unlink(missing_ok=True)


def test_map_linear_bounds() -> None:
    assert map_linear_to_1_5(0) == 1.0
    assert map_linear_to_1_5(100) == 5.0
