"""Step 7C: quality-only /media/evaluate preview (mocked ML)."""

from __future__ import annotations

import io
import json
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from app.services.media_evaluator import (
    deferred_authenticity_preview,
    evaluate_bytes,
    evaluate_photo,
    evaluate_video,
    is_deferred_authenticity_preview,
)
from app.services.media_pipeline import _payload_from_preview_metadata, run_pipeline


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (64, 64), color=(100, 120, 80)).save(buf, format="JPEG")
    return buf.getvalue()


def test_deferred_preview_marker() -> None:
    ai = deferred_authenticity_preview()
    assert ai["analysis_status"] == "deferred"
    assert ai["is_final"] is False
    assert "verdict" not in ai
    assert "probability" not in ai


def test_photo_preview_skips_authenticity_detector() -> None:
    metrics = {"sharpness": 0.5, "blur": 0.2, "noise": 0.1, "brightness": 0.5, "contrast": 0.4, "blocking_artifacts": 0.1, "ringing_artifacts": 0.1, "width": 640, "height": 480}
    with patch("app.services.media_evaluator._analyze_image", return_value=metrics):
        with patch("app.services.media_evaluator.detect_ai_generated") as detect:
            payload = evaluate_photo(_jpeg_bytes(), include_authenticity=False)

    detect.assert_not_called()
    assert payload is not None
    assert payload["ai_detection"]["analysis_status"] == "deferred"
    assert payload.get("authenticity_deferred") is True
    assert payload.get("xp_eligible") is False
    assert payload.get("xp_pending") is True
    assert payload["ai_detection"].get("verdict") is None


def test_photo_full_analysis_still_calls_detector() -> None:
    metrics = {"sharpness": 0.5, "blur": 0.2, "noise": 0.1, "brightness": 0.5, "contrast": 0.4, "blocking_artifacts": 0.1, "ringing_artifacts": 0.1, "width": 640, "height": 480}
    with patch("app.services.media_evaluator._analyze_image", return_value=metrics):
        with patch("app.services.media_evaluator.detect_ai_generated", return_value={"verdict": "authentic", "confidence": 0.8, "probability": 0.1, "detail": "ok", "signals": {}}):
            payload = evaluate_photo(_jpeg_bytes(), include_authenticity=True)

    assert payload is not None
    assert payload["ai_detection"]["verdict"] == "authentic"


def test_video_preview_skips_frame_authenticity() -> None:
    frames = [_jpeg_bytes(), _jpeg_bytes()]
    metrics = {"sharpness": 0.5, "blur": 0.2, "noise": 0.1, "brightness": 0.5, "contrast": 0.4, "blocking_artifacts": 0.1, "ringing_artifacts": 0.1, "width": 640, "height": 480}
    with patch("app.services.media_evaluator.extract_frames", return_value=frames):
        with patch("app.services.media_evaluator._analyze_image", return_value=metrics):
            with patch("app.services.media_evaluator.detect_ai_generated_from_frames") as detect_frames:
                payload = evaluate_video(b"video", ext=".mp4", include_authenticity=False)

    detect_frames.assert_not_called()
    assert payload is not None
    assert payload["ai_detection"]["analysis_status"] == "deferred"


def test_evaluate_bytes_default_include_authenticity_true() -> None:
    with patch("app.services.media_evaluator.evaluate_photo") as mock_photo:
        mock_photo.return_value = {"ok": True}
        evaluate_bytes(_jpeg_bytes(), file_name="a.jpg")
    mock_photo.assert_called_once()
    assert mock_photo.call_args.kwargs.get("include_authenticity") is True


def test_deferred_metadata_not_accepted_as_final_preview() -> None:
    preview = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "ai_detection": deferred_authenticity_preview(),
        "scoring_model": "efficientnet-b0",
        "legacy": {"overall_score": 0.8},
    }
    assert _payload_from_preview_metadata(json.dumps(preview)) is None


def test_final_metadata_still_fast_path_when_not_deferred() -> None:
    preview = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "ai_detection": {"verdict": "authentic", "confidence": 0.8, "probability": 0.1, "detail": "x"},
        "scoring_model": "efficientnet-b0",
        "legacy": {"overall_score": 0.8},
    }
    assert _payload_from_preview_metadata(json.dumps(preview)) is not None


def test_background_pipeline_runs_full_evaluate_when_metadata_deferred() -> None:
    db = MagicMock()
    media = MagicMock(id=1, file_name="p.jpg", file_url="/uploads/p.jpg", file_type="photo", uploaded_by=2)
    deferred_meta = json.dumps(
        {
            "criteria": [{"name": "Sharpness", "score": 4}],
            "overall_score": 4.0,
            "ai_detection": deferred_authenticity_preview(),
            "scoring_model": "efficientnet-b0",
            "legacy": {"overall_score": 0.8},
        }
    )

    user = MagicMock(fullname="Member", id=2)
    auth_payload = {
        "verdict": "authentic",
        "probability": 0.1,
        "confidence": 0.9,
        "detail": "d",
        "requires_review": False,
        "detector_backend": "probe",
    }
    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch(
            "app.services.media_pipeline.evaluate_authenticity_bytes",
            return_value=auth_payload,
        ) as ev_auth:
            with patch("app.services.media_pipeline.merge_client_gemini", side_effect=lambda p, _m: p):
                with patch("app.services.media_pipeline.scores_from_payload", return_value={"overall_score": 0.8, "sharpness_score": 0.8, "brightness_score": 0.8, "contrast_score": 0.8, "blur_score": 0.8, "noise_score": 0.8}):
                    with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                        with patch("app.services.media_pipeline.eval_crud.create_ai_result", return_value=MagicMock()):
                            with patch("app.services.media_pipeline.user_crud.get_by_id", return_value=user):
                                with patch("app.services.media_pipeline.user_crud.recalculate_skill_level"):
                                    with patch("app.services.media_pipeline.ranking_crud.add_points"):
                                        with patch(
                                            "app.crud.member_profile.evaluations_stats",
                                            return_value=(1, 0.8),
                                        ):
                                            with patch(
                                                "app.services.member_milestones.on_evaluation_completed"
                                            ):
                                                with patch(
                                                    "app.services.ai_review_workflow.initial_review_status",
                                                    return_value="verified_human",
                                                ):
                                                    run_pipeline(
                                                        db, media, b"bytes", evaluation_metadata=deferred_meta
                                                    )

    ev_auth.assert_called_once()


def test_gemini_quality_fields_present_on_preview() -> None:
    metrics = {"sharpness": 0.5, "blur": 0.2, "noise": 0.1, "brightness": 0.5, "contrast": 0.4, "blocking_artifacts": 0.1, "ringing_artifacts": 0.1, "width": 640, "height": 480}
    with patch("app.services.media_evaluator._analyze_image", return_value=metrics):
        payload = evaluate_photo(_jpeg_bytes(), include_authenticity=False)

    assert payload is not None
    assert isinstance(payload.get("criteria"), list) and len(payload["criteria"]) > 0
    assert payload.get("overall_score") is not None
    assert payload.get("quality_level") is not None


def test_is_deferred_helper() -> None:
    assert is_deferred_authenticity_preview(deferred_authenticity_preview())
    assert not is_deferred_authenticity_preview({"verdict": "authentic"})
