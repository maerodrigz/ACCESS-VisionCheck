"""Tests for tools/quality_validation (mocked scorers where needed)."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from PIL import Image

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.dataset import load_manifest  # noqa: E402
from tools.quality_validation.engines import ENGINE_EFFICIENTNET, ENGINE_OPENCV, analyze_image_metrics  # noqa: E402
from tools.quality_validation.evaluate import evaluate_bytes_validation  # noqa: E402
from tools.quality_validation.export import flatten_row, write_csv, write_json  # noqa: E402
from tools.quality_validation.metrics import mae_rmse, pearson_spearman, repeatability_std  # noqa: E402


def _jpeg_bytes(w: int = 64, h: int = 64) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (w, h), color=(120, 100, 80)).save(buf, format="JPEG")
    return buf.getvalue()


_STUB_METRICS = {
    "sharpness": 0.7,
    "blur": 0.2,
    "noise": 0.15,
    "brightness": 0.5,
    "contrast": 0.4,
    "blocking_artifacts": 0.1,
    "ringing_artifacts": 0.08,
    "width": 64,
    "height": 64,
}


def test_efficientnet_requested_does_not_fallback_to_opencv() -> None:
    with patch("tools.quality_validation.engines.analyze_image_bytes", create=True):
        pass
    with patch(
        "app.services.efficientnet_b0_scorer.analyze_image_bytes",
        return_value=None,
    ), patch(
        "app.services.efficientnet_b0_scorer.efficientnet_available",
        return_value=True,
    ), patch(
        "app.services.efficientnet_b0_scorer.ensure_weights",
        return_value=True,
    ), patch(
        "app.services.opencv_quality.analyze_image_bytes",
        return_value=_STUB_METRICS,
    ) as oc:
        metrics, err = analyze_image_metrics(_jpeg_bytes(), ENGINE_EFFICIENTNET)
        oc.assert_not_called()
    assert metrics is None
    assert err == "efficientnet_inference_failed"


def test_opencv_only_path() -> None:
    with patch(
        "app.services.opencv_quality.analyze_image_bytes",
        return_value=dict(_STUB_METRICS),
    ), patch(
        "app.services.opencv_quality.opencv_available",
        return_value=True,
    ):
        metrics, err = analyze_image_metrics(_jpeg_bytes(), ENGINE_OPENCV)
    assert err is None
    assert metrics is not None
    assert metrics["sharpness"] == 0.7


def test_evaluate_photo_mocked_produces_overall() -> None:
    with patch(
        "tools.quality_validation.evaluate.analyze_image_metrics",
        return_value=(dict(_STUB_METRICS), None),
    ):
        result = evaluate_bytes_validation(
            _jpeg_bytes(),
            file_name="sample.jpg",
            engine=ENGINE_OPENCV,
        )
    assert result["analysis_status"] == "ok"
    assert result["overall_score"] is not None
    assert "Sharpness" in result["criterion_scores"]


def test_export_roundtrip(tmp_path: Path) -> None:
    record = {
        "media_id": "m1",
        "media_type": "photo",
        "dataset_split": "dev",
        "engine": "opencv",
        "analysis_status": "ok",
        "criterion_scores": {"Sharpness": 4},
        "overall_score": 3.8,
        "insufficient_evidence_flags": [],
    }
    meta = {"toolkit_version": "1.0.0"}
    out = tmp_path / "out.json"
    write_json([record], out, meta)
    data = json.loads(out.read_text(encoding="utf-8"))
    assert data["results"][0]["media_id"] == "m1"
    write_csv([record], tmp_path / "out.csv")
    assert (tmp_path / "out.csv").exists()
    flat = flatten_row(record)
    assert flat["criterion_Sharpness"] == 4


def test_manifest_split_validation(tmp_path: Path) -> None:
    root = tmp_path / "ds"
    (root / "dev" / "photos").mkdir(parents=True)
    img = root / "dev" / "photos" / "a.jpg"
    img.write_bytes(_jpeg_bytes())
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "media_id,relative_path,media_type,dataset_split\n"
        "a,dev/photos/a.jpg,photo,bad_split\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="dataset_split"):
        load_manifest(manifest, root)


def test_metrics_helpers() -> None:
    assert pearson_spearman([1, 2, 3, 4], [1, 2, 3, 5])["spearman_r"] is not None
    err = mae_rmse([3.0, 4.0], [3.5, 3.5])
    assert err["mae"] == 0.5
    rep = repeatability_std([4.0, 4.1, 3.9, 4.0, 4.05])
    assert rep["std"] is not None
