"""Quality evaluation correctness: score direction, failures, engine, orientation, preview/save."""

from __future__ import annotations

import json
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import numpy as np
from PIL import Image

from app.services.image_orientation import decode_oriented_bgr, rotate_bgr
from app.services.media_evaluator import (
    QUALITY_ENGINE_EFFICIENTNET,
    QUALITY_ENGINE_OPENCV,
    preview_quality_complete,
    resolve_quality_engine_for_bytes,
    scores_from_payload,
)
from app.services.media_pipeline import run_pipeline
from app.services.quality_score_display import (
    failed_evaluation_payload,
    quality_01_to_percent,
    quality_display_from_evaluation,
)


_PHOTO_NAMES = (
    "Sharpness",
    "Blur",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Color Balance",
    "Color Saturation",
)

_METRICS = {
    "sharpness": 0.7,
    "blur": 0.2,
    "noise": 0.1,
    "brightness": 0.5,
    "contrast": 0.4,
    "blocking_artifacts": 0.1,
    "ringing_artifacts": 0.1,
    "width": 64,
    "height": 64,
}


def _complete_payload(*, noise_score_db: float = 0.2) -> dict:
    by_name = {n: 4 for n in _PHOTO_NAMES}
    criteria = [
        {"name": n, "score": s, "label": "Good", "available": True} for n, s in by_name.items()
    ]
    overall = sum(by_name.values()) / len(by_name)
    return {
        "criteria": criteria,
        "overall_score": overall,
        "evaluation_status": "ok",
        "evaluation_available": True,
        "scoring_engine": "efficientnet-b0+ffmpeg+color-heuristics",
        "scoring_model": "efficientnet-b0",
        "legacy": {
            "sharpness_score": 0.8,
            "brightness_score": 0.8,
            "contrast_score": 0.8,
            "blur_score": 0.8,
            "noise_score": noise_score_db,
            "overall_score": round(overall / 5, 3),
        },
        "analysis": {"quality_engine": "efficientnet-b0", "opencv_fallback": False},
        "ai_detection": {"verdict": "authentic", "probability": 0.05, "detector_backend": "probe"},
    }


def test_legacy_noise_preserved_without_noise_criterion() -> None:
    payload = _complete_payload(noise_score_db=0.2)
    scores = scores_from_payload(payload)
    assert scores is not None
    assert scores["noise_score"] == 0.2
    display = quality_display_from_evaluation(
        criteria_json=json.dumps(payload),
        **scores,
    )
    names = [c["name"] for c in display["criteria"]]
    assert "Color Balance" in names
    assert "Color Saturation" in names
    assert "Noise" not in names
    assert "Ringing Artifacts" not in names
    db_only = quality_display_from_evaluation(
        criteria_json=None,
        sharpness_score=0.8,
        brightness_score=0.8,
        contrast_score=0.8,
        blur_score=0.8,
        noise_score=scores["noise_score"],
        overall_score=0.8,
    )
    db_noise = next(c for c in db_only["criteria"] if c["name"] == "Noise")
    assert db_noise["percent"] == quality_01_to_percent(1.0 - 0.2)


def test_blur_display_higher_is_better() -> None:
    payload = _complete_payload()
    display = quality_display_from_evaluation(criteria_json=json.dumps(payload))
    blur = next(c for c in display["criteria"] if c["name"] == "Blur")
    assert blur["higher_is_better"] is True
    assert blur["score"] == 4


def test_failed_evaluation_does_not_invent_scores() -> None:
    failed = failed_evaluation_payload(media_type="photo", reason="eval failed")
    assert scores_from_payload(failed) is None
    display = quality_display_from_evaluation(criteria_json=json.dumps(failed))
    assert display["available"] is False
    assert display["overall_percent"] is None
    assert display["criteria"] == []


def test_run_pipeline_failure_stores_null_scores_not_half() -> None:
    db = MagicMock()
    media = SimpleNamespace(id=11, file_name="x.jpg", file_url="/uploads/x.jpg", file_type="photo", uploaded_by=None)
    created = {}

    def _capture(session, data):
        created.update(data)
        return MagicMock()

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch("app.services.media_pipeline.evaluate_bytes", return_value=None):
            with patch("app.services.media_pipeline.eval_crud.create_evaluation", side_effect=_capture):
                with patch("app.services.media_pipeline.eval_crud.create_ai_result", return_value=MagicMock()):
                    with patch("app.services.ai_review_workflow.initial_review_status", return_value="automated_low_ai_risk"):
                        run_pipeline(db, media, b"not-an-image")

    assert created["overall_score"] is None
    assert created["noise_score"] is None
    payload = json.loads(created["criteria_json"])
    assert payload["evaluation_available"] is False
    assert 0.5 not in (
        created["sharpness_score"],
        created["brightness_score"],
        created["contrast_score"],
        created["blur_score"],
        created["noise_score"],
        created["overall_score"],
    )


def test_engine_fallback_is_explicit() -> None:
    with patch("app.services.media_evaluator.efficientnet_available", return_value=True):
        with patch("app.services.media_evaluator.ensure_weights", return_value=True):
            with patch("app.services.media_evaluator.efficientnet_analyze", return_value=None):
                with patch("app.services.media_evaluator.opencv_available", return_value=True):
                    with patch("app.services.media_evaluator.opencv_analyze", return_value=dict(_METRICS)) as opencv:
                        metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpg")
    opencv.assert_called_once()
    assert metrics is not None
    assert engine == QUALITY_ENGINE_OPENCV
    assert fallback is True


def test_efficientnet_success_does_not_silently_use_opencv() -> None:
    with patch("app.services.media_evaluator.efficientnet_available", return_value=True):
        with patch("app.services.media_evaluator.ensure_weights", return_value=True):
            with patch("app.services.media_evaluator.efficientnet_analyze", return_value=dict(_METRICS)):
                with patch("app.services.media_evaluator.opencv_analyze") as opencv:
                    metrics, engine, fallback = resolve_quality_engine_for_bytes(b"jpg")
    opencv.assert_not_called()
    assert engine == QUALITY_ENGINE_EFFICIENTNET
    assert fallback is False
    assert metrics is not None


def test_exif_orientation_applied_before_decode() -> None:
    image = Image.new("RGB", (20, 40), (200, 10, 10))
    exif = image.getexif()
    exif[274] = 6
    buf = BytesIO()
    image.save(buf, format="JPEG", exif=exif)
    oriented = decode_oriented_bgr(buf.getvalue())
    assert oriented is not None
    h, w = oriented.shape[:2]
    assert (w, h) == (40, 20)


def test_rotate_bgr_ninety_degrees() -> None:
    frame = np.zeros((10, 20, 3), dtype=np.uint8)
    rotated = rotate_bgr(frame, 90)
    assert rotated.shape[0] == 20
    assert rotated.shape[1] == 10


def test_incomplete_preview_is_rejected() -> None:
    incomplete = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "legacy": {"overall_score": 0.8},
        "scoring_engine": "efficientnet-b0+ffmpeg",
        "ai_detection": {"verdict": "authentic"},
    }
    assert preview_quality_complete(incomplete) is False
    assert preview_quality_complete(_complete_payload()) is True


def test_preview_and_saved_scores_match_when_complete() -> None:
    payload = _complete_payload(noise_score_db=0.0)
    preview_scores = scores_from_payload(payload)
    saved_display = quality_display_from_evaluation(criteria_json=json.dumps(payload), **preview_scores)
    preview_display = quality_display_from_evaluation(criteria_json=json.dumps(payload))
    assert preview_scores is not None
    assert saved_display["overall_percent"] == preview_display["overall_percent"]
    assert saved_display["criteria"] == preview_display["criteria"]


def test_historical_evaluation_not_overwritten() -> None:
    db = MagicMock()
    media = SimpleNamespace(id=77)
    existing = MagicMock()
    existing.overall_score = 0.91
    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=existing):
        with patch("app.services.media_pipeline.eval_crud.get_ai_for_media", return_value=None):
            with patch("app.services.media_pipeline.eval_crud.create_evaluation") as create_ev:
                with patch("app.services.media_pipeline.evaluate_bytes") as evaluate:
                    out = run_pipeline(db, media, b"bytes")
    create_ev.assert_not_called()
    evaluate.assert_not_called()
    assert out[0] is existing


def test_quality_payload_keeps_ai_detection_separate() -> None:
    payload = _complete_payload()
    assert "ai_detection" in payload
    assert payload["analysis"]["quality_engine"] == "efficientnet-b0"
    assert payload["ai_detection"]["detector_backend"] == "probe"
    assert payload["analysis"]["quality_engine"] != payload["ai_detection"]["detector_backend"]
