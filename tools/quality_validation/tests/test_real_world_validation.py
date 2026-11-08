"""Phase 3 real-world quality validation toolkit tests (fixtures only)."""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.real_world_analyze import aggregate_human, analyze  # noqa: E402
from tools.quality_validation.real_world_batch import run_batch  # noqa: E402
from tools.quality_validation.real_world_evaluate import (  # noqa: E402
    SafetyViolation,
    evaluate_production_quality,
)
from tools.quality_validation.real_world_schema import (  # noqa: E402
    PHOTO_CRITERIA,
    VIDEO_CRITERIA,
    higher_is_better,
    load_human_ratings_access,
    parse_score_1_5,
    scan_workspace,
    write_manifest,
)
from tools.quality_validation.metrics import mae_rmse, pearson_spearman  # noqa: E402


def test_score_direction_and_range() -> None:
    for name in PHOTO_CRITERIA + VIDEO_CRITERIA:
        assert higher_is_better(name)
    assert parse_score_1_5("5") == 5
    assert parse_score_1_5("1") == 1
    assert parse_score_1_5("N/A") is None
    assert parse_score_1_5("3") == 3
    assert parse_score_1_5("0") is None
    assert parse_score_1_5("6") is None
    assert parse_score_1_5("") is None


def test_human_csv_missing_values(tmp_path: Path) -> None:
    path = tmp_path / "ratings.csv"
    path.write_text(
        "media_id,rater_id,media_type,sharpness,blur,noise,brightness,contrast,"
        "blocking_artifacts,ringing_artifacts,flickering,motion_stability,overall_visual_quality,notes\n"
        "PHOTO-001,R1,photo,4,N/A,4,3,4,5,5,N/A,N/A,4,\n",
        encoding="utf-8",
    )
    rows = load_human_ratings_access(path)
    assert rows[0]["scores"]["Blur"] is None
    assert rows[0]["scores"]["Flickering"] is None
    assert rows[0]["scores"]["Sharpness"] == 4


def test_failed_evaluation_has_no_placeholder_score() -> None:
    with patch(
        "app.services.media_evaluator.evaluate_bytes",
        return_value=None,
    ):
        result = evaluate_production_quality(b"not-an-image", file_name="x.jpg")
    assert result["analysis_status"] == "failed"
    assert result["overall_score"] is None
    assert result["criterion_scores"] == {}
    assert result["overall_score"] != 0.5


def test_success_records_engine_metadata() -> None:
    payload = {
        "evaluation_status": "ok",
        "evaluation_available": True,
        "media_type": "photo",
        "overall_score": 4.0,
        "quality_level": "Good",
        "criteria": [{"name": name, "score": 4} for name in PHOTO_CRITERIA],
        "analysis": {
            "quality_engine": "efficientnet-b0",
            "opencv_fallback": False,
            "efficientnet_used": True,
            "ffmpeg_used": False,
            "frames_analyzed": 1,
        },
        "scoring_model": "efficientnet-b0",
        "scoring_engine": "efficientnet-b0+ffmpeg",
    }
    with patch("app.services.media_evaluator.evaluate_bytes", return_value=payload) as mocked:
        result = evaluate_production_quality(b"jpeg", file_name="a.jpg")
    mocked.assert_called_once()
    assert mocked.call_args.kwargs["include_authenticity"] is False
    assert result["analysis_status"] == "ok"
    assert result["quality_engine"] == "efficientnet-b0"
    assert result["opencv_fallback"] is False
    assert result["ai_detection_invoked"] is False


def test_ai_detection_call_is_blocked() -> None:
    def _fake_evaluate(*_a, **_k):
        from app.services.media_evaluator import detect_ai_generated

        detect_ai_generated(b"x", file_name="a.jpg")
        return {"evaluation_status": "ok"}

    with patch("app.services.media_evaluator.evaluate_bytes", side_effect=_fake_evaluate):
        with pytest.raises(SafetyViolation, match="AI content detection"):
            evaluate_production_quality(b"jpeg", file_name="a.jpg")


def test_database_write_is_blocked() -> None:
    def _fake_evaluate(*_a, **_k):
        from app.crud.evaluation import create_evaluation

        create_evaluation(MagicMock(), {})
        return {"evaluation_status": "ok"}

    with patch("app.services.media_evaluator.evaluate_bytes", side_effect=_fake_evaluate):
        with pytest.raises(SafetyViolation, match="Database"):
            evaluate_production_quality(b"jpeg", file_name="a.jpg")


def test_dry_run_does_not_score(tmp_path: Path) -> None:
    photos = tmp_path / "photos"
    photos.mkdir()
    (photos / "a.jpg").write_bytes(b"fake")
    items = scan_workspace(tmp_path)
    write_manifest(tmp_path / "manifest.csv", items)
    with patch("tools.quality_validation.real_world_batch.evaluate_production_quality") as scored:
        records = run_batch(
            dataset_root=tmp_path,
            manifest=tmp_path / "manifest.csv",
            output_dir=tmp_path / "out",
            dry_run=True,
        )
    scored.assert_not_called()
    assert records[0]["analysis_status"] == "dry_run"
    assert records[0]["overall_score"] is None
    assert not (tmp_path / "out" / "machine_results.json").exists()


def test_mae_and_correlation_skip_missing() -> None:
    machine = [
        {
            "media_id": "PHOTO-001",
            "media_type": "photo",
            "analysis_status": "ok",
            "overall_score": 4.0,
            "criterion_scores": {"Sharpness": 4, "Blur": 4},
            "quality_engine": "efficientnet-b0",
            "opencv_fallback": False,
        },
        {
            "media_id": "PHOTO-002",
            "media_type": "photo",
            "analysis_status": "failed",
            "overall_score": None,
            "criterion_scores": {},
        },
    ]
    humans = [
        {
            "media_id": "PHOTO-001",
            "rater_id": "R1",
            "media_type": "photo",
            "scores": {"Overall visual quality": 3.0, "Sharpness": 5.0, "Blur": None},
        },
        {
            "media_id": "PHOTO-001",
            "rater_id": "R2",
            "media_type": "photo",
            "scores": {"Overall visual quality": 5.0, "Sharpness": 5.0, "Blur": 4.0},
        },
    ]
    report = analyze(machine_records=machine, human_rows=humans)
    assert report["n_system_failed"] == 1
    assert report["failed_media_ids"] == ["PHOTO-002"]
    overall = report["criterion_metrics"]["Overall visual quality"]
    assert overall["n_paired"] == 1
    assert overall["mae"] == 0.0  # median(3,5)=4 vs system 4
    sharpness = report["criterion_metrics"]["Sharpness"]
    assert sharpness["n_paired"] == 1
    assert sharpness["mae"] == 1.0
    blur = report["criterion_metrics"]["Blur"]
    assert blur["n_paired"] == 1
    assert blur["mae"] == 0.0
    assert "accuracy_percent" not in report


def test_metrics_helpers_small_n() -> None:
    assert mae_rmse([], [])["mae"] is None
    corr = pearson_spearman([1], [2])
    assert corr["spearman_r"] is None
    err = mae_rmse([4.0, 2.0], [3.0, 3.0])
    assert err["mae"] == 1.0
    agg = aggregate_human(
        [
            {"media_id": "A", "rater_id": "R1", "scores": {"Overall visual quality": 2}},
            {"media_id": "A", "rater_id": "R2", "scores": {"Overall visual quality": 4}},
        ]
    )
    assert agg["A"]["independent_overall"] == 3
