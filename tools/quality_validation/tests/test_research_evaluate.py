"""KonIQ research evaluation wiring tests. Does not run production scoring on dataset images."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import patch

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.research_evaluate import run, write_per_image_csv  # noqa: E402
from tools.quality_validation.research_datasets import KONIQ_ROOT  # noqa: E402


def test_preflight_dry_run_on_imported_subset(tmp_path: Path) -> None:
    out = tmp_path / "dry_run"
    report = run(
        dataset_root=KONIQ_ROOT,
        manifest=KONIQ_ROOT / "metadata" / "subset_manifest.csv",
        published_mos=KONIQ_ROOT / "metadata" / "published_mos.csv",
        output_dir=out,
        dry_run=True,
        analyze=True,
    )
    assert report["ok"] is True
    assert report["dry_run"] is True
    assert report["n"] == 40
    payload = json.loads((out / "machine_results.json").read_text(encoding="utf-8"))
    assert payload["metadata"]["ai_detection"] is False
    assert payload["metadata"]["database"] is False
    assert payload["results"][0]["analysis_status"] == "dry_run"
    assert payload["results"][0]["overall_score"] is None
    assert payload["results"][0]["overall_mapped_1_5"] is not None


def test_per_image_csv_keeps_mos_separate_from_criteria(tmp_path: Path) -> None:
    path = tmp_path / "per_image_results.csv"
    write_per_image_csv(
        [
            {
                "media_id": "KONIQ-001",
                "source_media_key": "a.jpg",
                "relative_path": "images/a.jpg",
                "mos_quality_raw": 3.4,
                "mos_scale": "1-5",
                "overall_mapped_1_5": 3.4,
                "overall_score": 2.86,
                "analysis_status": "ok",
                "quality_engine": "efficientnet-b0",
                "opencv_fallback": False,
                "elapsed_ms": 12.5,
                "criterion_scores": {"Sharpness": 3, "Blur": 4},
            }
        ],
        path,
    )
    text = path.read_text(encoding="utf-8")
    assert "overall_mapped_1_5" in text
    assert "criterion_Sharpness" in text
    assert "3.4" in text


def test_scoring_records_engine_and_elapsed(tmp_path: Path) -> None:
    jpeg = KONIQ_ROOT / "images" / "5205048751.jpg"
    if not jpeg.is_file():
        return
    fake = {
        "analysis_status": "ok",
        "error_code": None,
        "error_detail": None,
        "overall_score": 3.14,
        "criterion_scores": {"Sharpness": 3, "Blur": 3, "Noise": 3, "Brightness": 3, "Contrast": 3, "Blocking Artifacts": 4, "Ringing Artifacts": 4},
        "quality_engine": "efficientnet-b0",
        "opencv_fallback": False,
        "efficientnet_used": True,
        "ai_detection_invoked": False,
        "gemini_invoked": False,
        "database_written": False,
    }
    out = tmp_path / "out"
    with patch("tools.quality_validation.research_evaluate.evaluate_production_quality", return_value=fake):
        report = run(
            dataset_root=KONIQ_ROOT,
            manifest=KONIQ_ROOT / "metadata" / "subset_manifest.csv",
            published_mos=KONIQ_ROOT / "metadata" / "published_mos.csv",
            output_dir=out,
            dry_run=False,
            analyze=True,
        )
    assert report["ok"] is True
    results = json.loads((out / "machine_results.json").read_text(encoding="utf-8"))["results"]
    assert results[0]["quality_engine"] == "efficientnet-b0"
    assert results[0]["elapsed_ms"] is not None
    assert results[0]["mos_quality_raw"] is not None
    analysis = json.loads((out / "analysis_report.json").read_text(encoding="utf-8"))
    assert analysis["inter_rater_fleiss_kappa_overall"] is None
    assert analysis["overall_mapped_1_5_vs_system_overall"]["n_paired"] == 40
