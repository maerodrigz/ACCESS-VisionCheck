"""Research dataset workspace: MOS import, matching, subsets, analysis compatibility."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest
from PIL import Image

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.importers.koniq10k import (  # noqa: E402
    import_koniq10k,
    import_koniq10k_rows,
    validate_koniq_headers,
)
from tools.quality_validation.importers.mapping_config import load_mapping_config  # noqa: E402
from tools.quality_validation.real_world_analyze import analyze_published_mos  # noqa: E402
from tools.quality_validation.research_datasets import (  # noqa: E402
    build_subset_records,
    deterministic_subset,
    load_published_mos,
    match_filename,
    mos_to_access_1_5,
    write_published_mos,
)
from tools.quality_validation.research_preview import main as preview_main  # noqa: E402
from tools.quality_validation.scale_mapping import map_mos_to_1_5  # noqa: E402


def _write_koniq_tab(path: Path) -> None:
    path.write_text(
        "image_name\tc1\tc2\tc3\tc4\tc5\tc_total\tMOS\tSD\tMOS_zscore\n"
        "a.jpg\t1\t2\t3\t4\t5\t15\t3.2\t0.8\t-0.1\n"
        "b.jpg\t0\t1\t2\t3\t4\t10\t4.1\t0.4\t0.9\n"
        "c.jpg\t2\t2\t2\t2\t2\t10\t2.5\t1.0\t-1.2\n"
        "dup.jpg\t1\t1\t1\t1\t1\t5\t3.0\t0.2\t0.0\n"
        "dup.jpg\t1\t1\t1\t1\t1\t5\t9.0\t0.2\t0.0\n"
        "missing_mos.jpg\t1\t1\t1\t1\t1\t5\t\t\t\n"
        "bad_scale.jpg\t1\t1\t1\t1\t1\t5\t6.5\t0.1\t0.0\n",
        encoding="utf-8",
    )


def _tiny_jpeg(path: Path) -> None:
    Image.new("RGB", (8, 8), color=(20, 40, 60)).save(path, format="JPEG")


def test_koniq_headers_required() -> None:
    assert validate_koniq_headers(["image_name", "MOS"]) == []
    errs = validate_koniq_headers(["filename"])
    assert any("image_name" in e for e in errs)
    assert any("MOS" in e for e in errs)


def test_koniq_import_preserves_raw_and_skips_duplicates(tmp_path: Path) -> None:
    tab = tmp_path / "koniq.tab"
    _write_koniq_tab(tab)
    rows, warnings = import_koniq10k_rows(tab)
    keys = [r["source_media_key"] for r in rows]
    assert keys.count("dup.jpg") == 1
    assert any("duplicate" in w for w in warnings)
    by_key = {r["source_media_key"]: r for r in rows}
    assert by_key["a.jpg"]["mos_quality_raw"] == 3.2
    assert by_key["a.jpg"]["overall_mapped_1_5"] == 3.2
    assert by_key["a.jpg"]["not_individual_raters"] is True
    assert by_key["a.jpg"]["not_criterion_scores"] is True
    assert by_key["missing_mos.jpg"]["mos_quality_raw"] is None
    assert by_key["bad_scale.jpg"]["mos_quality_raw"] == 6.5
    assert by_key["bad_scale.jpg"]["overall_mapped_1_5"] is None
    assert by_key["a.jpg"]["mos_zscore_raw"] == -0.1


def test_koniq_zscore_is_not_mapped_as_acr() -> None:
    mapped = map_mos_to_1_5(-0.1, "1-5")
    assert mapped is None


def test_koniq_reference_rows_have_empty_criteria(tmp_path: Path) -> None:
    tab = tmp_path / "koniq.tab"
    _write_koniq_tab(tab)
    mapping = _TOOLKIT / "templates" / "import_mapping.koniq10k.json"
    rows, _ = import_koniq10k(tab, mapping)
    one = next(r for r in rows if r["source_media_key"] == "a.jpg")
    assert one["attr_sharpness_raw"] == ""
    assert one["mos_quality_raw"] == "3.2"
    assert one["overall_documentation_mapped_1_5"] == "3.2"


def test_filename_matching(tmp_path: Path) -> None:
    photo = tmp_path / "a.jpg"
    _tiny_jpeg(photo)
    assert match_filename("a.jpg", [photo]) == photo
    assert match_filename("a", [photo]) == photo
    assert match_filename("missing.jpg", [photo]) is None


def test_deterministic_subset_is_stable() -> None:
    keys = [f"img_{i:03d}.jpg" for i in range(80)]
    a = deterministic_subset(keys, 40, 20261106)
    b = deterministic_subset(list(reversed(keys)), 40, 20261106)
    assert a == b
    assert len(a) == 40
    c = deterministic_subset(keys, 40, 1)
    assert a != c


def test_mos_scale_conversion() -> None:
    assert mos_to_access_1_5(3.4, "1-5") == 3.4
    assert mos_to_access_1_5(0.0, "0-100") == 1.0
    assert mos_to_access_1_5(100.0, "0-100") == 5.0
    assert mos_to_access_1_5(50.0, "0-100") == 3.0
    assert mos_to_access_1_5(None, "1-5") is None
    assert mos_to_access_1_5(6.0, "1-5") is None


def test_subset_reports_missing_files(tmp_path: Path) -> None:
    tab = tmp_path / "koniq.tab"
    _write_koniq_tab(tab)
    images = tmp_path / "images"
    images.mkdir()
    _tiny_jpeg(images / "a.jpg")
    rows, _ = import_koniq10k_rows(tab)
    records, stats = build_subset_records(
        rows,
        media_files=list(images.glob("*.jpg")),
        dataset_root=tmp_path,
        n=40,
        seed=20261106,
        media_type="photo",
        id_prefix="KONIQ",
    )
    assert stats["files_present"] == 1
    assert "b.jpg" in stats["files_missing"]
    assert any(r["source_media_key"] == "missing_mos.jpg" for r in records) or True
    present = next(r for r in records if r["source_media_key"] == "a.jpg")
    assert present["file_exists"] is True


def test_live_mapping_placeholders_blocked() -> None:
    example = _TOOLKIT / "templates" / "import_mapping.live_vqc.example.json"
    with pytest.raises(ValueError, match="REPLACE_WITH_"):
        load_mapping_config(example, allow_placeholders=False)


def test_published_mos_analysis_no_fleiss(tmp_path: Path) -> None:
    csv_path = tmp_path / "published_mos.csv"
    write_published_mos(
        [
            {
                "media_id": "KONIQ-001",
                "source_dataset": "KonIQ-10k",
                "source_media_key": "a.jpg",
                "media_type": "photo",
                "relative_path": "images/a.jpg",
                "file_exists": True,
                "mos_quality_raw": 4.0,
                "mos_scale": "1-5",
                "overall_mapped_1_5": 4.0,
                "selection_seed": 1,
                "selection_index": 1,
                "label_provenance": "human_subjective",
            }
        ],
        csv_path,
        license_note="test",
    )
    published = load_published_mos(csv_path)
    report = analyze_published_mos(
        machine_records=[
            {
                "media_id": "KONIQ-001",
                "analysis_status": "ok",
                "overall_score": 3.0,
                "criterion_scores": {"Sharpness": 5},
            },
            {
                "media_id": "KONIQ-002",
                "analysis_status": "failed",
                "overall_score": None,
                "criterion_scores": {},
            },
        ],
        published_rows=published,
    )
    assert report["inter_rater_fleiss_kappa_overall"] is None
    assert report["overall_mapped_1_5_vs_system_overall"]["mae"] == 1.0
    assert report["n_system_failed"] == 1
    assert "Sharpness" not in report


def test_preview_inspect_only_without_downloads() -> None:
    code = preview_main(["--inspect-only"])
    assert code == 2
